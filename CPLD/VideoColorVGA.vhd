----------------------------------------------------------------------------------
-- Company: n/a
-- Engineer: Andre Fachat
-- 
-- Create Date:    21:29:52 06/19/2020 
-- Design Name: 
-- Module Name:    Video - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Video is
    Port ( A : out  STD_LOGIC_VECTOR (15 downto 0);
	   CPU_D: in std_logic_vector(7 downto 0);
		VRAM_D: in std_logic_vector(7 downto 0);
		vd_out: out std_logic_vector(7 downto 0);
	   phi2: in std_logic;
	   
	   --dena   : out std_logic;	-- display enable
	   v_sync : out  STD_LOGIC;
      h_sync : out  STD_LOGIC;
	   pet_vsync: out std_logic;	-- for the PET screen interrupt

	   is_enable: in std_logic;
		is_80_in: in std_logic;
	   is_graph : in std_logic;	-- graphic mode (from PET I/O)
	   
	   crtc_sel : in std_logic;
	   crtc_rs : in std_logic_vector(3 downto 0);
	   crtc_rwb : in std_logic;
	   
	   qclk: in std_logic;		-- Q clock (50MHz)
		dotclk: in std_logic_vector(3 downto 0);	-- 25Mhz, 1/2, 1/4, 1/8, 1/16
      memclk : in STD_LOGIC;	-- system clock (12.5MHz)
	   
	   vid_fetch : out std_logic; -- true during video access phase (all, character, chrom, and hires pixel data)

	   vid_out: out std_logic_vector(3 downto 0);
		
		irq_out: out std_logic;
		
	   dbg_out : out std_logic;
	   
	   reset : in std_logic
	   );
		attribute maxskew: string;
		attribute maxskew of vid_out : signal is "4 ns";
		attribute maxdelay: string;
		attribute maxdelay of vid_out : signal is "5 ns";
end Video;

architecture Behavioral of Video is

	type AOA is array(natural range<>) of std_logic_vector(3 downto 0);
		
	--- modes
	signal mode_attrib: std_logic;			-- r25.6, enable attribute use
	signal mode_extended: std_logic;		-- r33.2, enables full and multicolor modes
	signal mode_bitmap: std_logic;
	signal mode_upet: std_logic;			-- when Micro-PET compat, r1 and others behave differently
	signal mode_rev: std_logic;			-- r24.6, reverse the screen
	signal dispen: std_logic;
	signal mode_double: std_logic;
	signal mode_interlace: std_logic;
	signal mode_80: std_logic;
	
	signal mode_altreg: std_logic;		-- enable access to alternate vid_base and attr_base
	signal mode_bitmap_alt: std_logic;	
	signal mode_extended_alt: std_logic;	
	signal mode_attrib_alt: std_logic;	
	signal mode_bitmap_reg: std_logic;	
	signal mode_extended_reg: std_logic;	
	signal mode_attrib_reg: std_logic;	
	signal alt_match_modes : std_logic;
	signal alt_match_vaddr : std_logic;
	signal alt_match_attr : std_logic;
	signal alt_rc_cnt: std_logic_vector(3 downto 0);
	signal alt_set_rc: std_logic;
	signal alt_do_set_rc: std_logic;
	signal mode_set_flag: std_logic;
	
	--- colours
	signal col_fg: std_logic_vector(3 downto 0);
	signal col_bg0: std_logic_vector(3 downto 0);
	signal col_bg1: std_logic_vector(3 downto 0);
	signal col_bg2: std_logic_vector(3 downto 0);
	signal col_border: std_logic_vector(3 downto 0);
	
	--- blink
	signal blink_cnt: std_logic_vector(5 downto 0);
	signal blink_16: std_logic;			-- blink with 1/16 frame rate
	signal blink_32: std_logic;			-- blink with 1/32 frame rate
	
	--- cursor
	signal crsr_start_scan: std_logic_vector(4 downto 0);
	signal crsr_end_scan: std_logic_vector(4 downto 0);
	signal crsr_address: std_logic_vector(15 downto 0);
	signal crsr_mode: std_logic_vector(1 downto 0);
	signal crsr_active: std_logic;			-- set when cursor is active in scanline
	signal crsr_addr_match: std_logic;		-- set when cursor is in current display cell

	--- underline
	signal uline_scan : std_logic_vector(4 downto 0);
	signal uline_active: std_logic;			-- set when underline is active in scanline (but still needs attribute to be set)

	--- new geo
	signal x_border: std_logic;
	signal x_start: std_logic;
	signal y_border: std_logic;
	signal rline_cnt0: std_logic;

	---
	signal cblink_mode: std_logic;			-- character blink mode, R24.5
	signal cblink_active: std_logic;		-- when set, character blinking is active
	signal sr_reverse : std_logic;			-- when set, invert the pixels; made from blink, underline and cursor logic
	signal sr_reverse_p : std_logic;
	signal sr_underline : std_logic;			-- when set, underline is active in SR
	signal sr_underline_p: std_logic;
	signal is_outbit: std_logic_vector(1 downto 0);
	signal raster_out: AOA(0 to 6);
	signal raster_outbit: std_logic_vector(3 downto 0);
	signal sr_buf: std_logic_vector(7 downto 0);
	
	-- 1 bit slot counter to enable 40 column
	signal in_slot: std_logic;
	
	-- mode
	signal is_80: std_logic;
	
	-- crtc register emulation
	signal crtc_reg: std_logic_vector(7 downto 0);
	
	signal rows_per_char: std_logic_vector(3 downto 0);
	signal slots_per_line: std_logic_vector(6 downto 0);
	signal clines_per_screen: std_logic_vector(7 downto 0);
	signal hsync_pos: std_logic_vector(6 downto 0);
	signal vsync_pos: std_logic_vector(7 downto 0);
	
	signal vid_base : std_logic_vector(15 downto 0);
	signal attr_base : std_logic_vector(15 downto 0);
	signal crom_base : std_logic_vector(7 downto 0);
	
	signal vid_base_alt : std_logic_vector(15 downto 0);
	signal attr_base_alt : std_logic_vector(15 downto 0);

	-- count "slots", i.e. 8pixels
	-- 
	-- one slot may need none (out of screen), one (hires), or two (character display) 
	-- memory accesses. At 16MHz pixel, a slot has four potential memory accesses at 8MHz
	-- up to 127 slots/line
	--
	-- now see ClockBorder.vhd
	
	-- count raster lines per character lines
	signal rcline_cnt : std_logic_vector (3 downto 0) := (others => '0');

	-- vdc r27
	signal va_offset: std_logic_vector(7 downto 0);
	
	-- computed video memory address
	signal vid_addr : std_logic_vector (15 downto 0) := (others => '0');
	-- computed video memory address at start of line (to re-load chars each raster line)
	signal vid_addr_hold : std_logic_vector(15 downto 0) := (others => '0');

	-- computed attribute memory address
	signal attr_addr : std_logic_vector (15 downto 0) := (others => '0');
	-- computed attribute memory address at start of line (to re-load chars each raster line)
	signal attr_addr_hold : std_logic_vector(15 downto 0) := (others => '0');
	
	-- replacement for csa_ultracpu IC7 when holding character data for the crom fetch
	signal char_index_buf : std_logic_vector(7 downto 0);
	signal attr_buf : std_logic_vector(7 downto 0);
	signal attr_buf2 : std_logic_vector(7 downto 0);
	signal pxl_buf : std_logic_vector(7 downto 0);
	-- replacements for shift register
	signal sr : std_logic_vector(7 downto 0);
	signal nsrload : std_logic;
	signal dena_int : std_logic;
	signal sr_attr: std_logic_vector(7 downto 0); -- the attributes for the bitmap in sr
	signal sr_crsr: std_logic;
	signal sr_blink: std_logic;
	signal sr_odd: std_logic;

	-- geo signals
	--
   signal x_addr: std_logic_vector(9 downto 0);    -- x coordinate in pixels
   signal y_addr: std_logic_vector(9 downto 0);    -- y coordinate in rasterlines
	signal y_addr_latch: std_logic_vector(9 downto 8); 	-- latch upper two bits when reading lower bits from r38
	
	-- border
	signal h_shift: std_logic_vector(3 downto 0);
	signal h_extborder: std_logic;
	signal v_extborder: std_logic;
	signal v_shift: std_logic_vector(3 downto 0);
	
	-- pulse for last visible character/slot; falling slotclk
	signal last_vis_slot_of_line : std_logic := '0';
	-- pulse at end of character line; falling slotclk
	signal last_line_of_char : std_logic := '0';
	-- pulse at end of screen
	signal last_line_of_screen : std_logic := '0';
	
	-- enable
	signal h_enable : std_logic := '0';	
	signal v_enable : std_logic := '0';
	signal enable : std_logic;
	
	-- sync
	signal h_sync_int : std_logic := '0';	
	signal v_sync_int : std_logic := '0';
	
	-- raster interrupt
	signal raster_match: std_logic_vector(9 downto 0);
	signal is_raster_match: std_logic;
	
	signal irq_raster_ack: std_logic;
	signal irq_raster: std_logic;
	signal irq_raster_en: std_logic;
	signal irq_out_int: std_logic;
	
	-- intermediate
	signal h_zero: std_logic;
	signal v_zero: std_logic;
	signal a_out : std_logic_vector (15 downto 0);
	signal chr_window : std_logic;
	signal pxl_window : std_logic;
	signal attr_window : std_logic;
	signal sr_window : std_logic;
	signal slotclk : std_logic;
	
	-- clock phases (16 half-pixels in one slot)
	signal pxl0_ce: std_logic;
	signal pxl1_ce: std_logic;
	signal pxl2_ce: std_logic;
	signal pxl3_ce: std_logic;
	signal pxl4_ce: std_logic;
	signal pxl5_ce: std_logic;
	signal pxl6_ce: std_logic;
	signal pxl7_ce: std_logic;
	signal pxl8_ce: std_logic;
	signal pxl9_ce: std_logic;
	signal pxla_ce: std_logic;
	signal pxlb_ce: std_logic;
	signal pxlc_ce: std_logic;
	signal pxld_ce: std_logic;
	signal pxle_ce: std_logic;
	signal pxlf_ce: std_logic;
	
	signal fetch_int: std_logic;
	
	signal chr_fetch_int : std_logic;
	signal crom_fetch_int: std_logic;
	signal pxl_fetch_int : std_logic;
	signal attr_fetch_int : std_logic;
	signal sr_fetch_int : std_logic;
	
	-- temporary
	signal is_double_int: std_logic;
	signal interlace_int: std_logic;
	
	function To_Std_Logic(L: BOOLEAN) return std_ulogic is
	begin
		if L then
			return('1');
		else
			return('0');
		end if;
	end function To_Std_Logic;

	-- VGA canvas (fixed timing, ?_addr start with 0/0 on upper left edge, outside visible area)
	component Canvas is
    	Port (
           qclk: in std_logic;          -- Q clock (50MHz)
           dotclk: in std_logic_vector(3 downto 0);     -- 25Mhz, 1/2, 1/4, 1/8, 1/16

           h_sync : out  STD_LOGIC;
           v_sync : out  STD_LOGIC;

			  h_zero : out std_logic;
			  v_zero : out std_logic;
			  
           h_enable : out std_logic;
           v_enable : out std_logic;

           x_addr: out std_logic_vector(9 downto 0);    -- x coordinate in pixels
           y_addr: out std_logic_vector(9 downto 0);    -- y coordinate in rasterlines

           reset : in std_logic
        );
	end component;

	component HBorder is
		Port (
			qclk: in std_logic;
			dotclk: in std_logic_vector(3 downto 0);			
			
			h_zero: in std_logic;
			hsync_pos: in std_logic_vector(6 downto 0);
			slots_per_line: in std_logic_vector(6 downto 0);
			h_extborder: in std_logic;
			is_80: in std_logic;
			
			is_preload: out std_logic;		-- one slot before end of border
			is_border: out std_logic;			
			is_last_vis: out std_logic;
			in_slot: out std_logic;
			
			reset : in std_logic
		);
	end component;

	component VBorder is
		Port (
			h_sync: in std_logic;
			
			v_zero: in std_logic;
			vsync_pos: in std_logic_vector(7 downto 0);
			rows_per_char: in std_logic_vector(3 downto 0);
			clines_per_screen: in std_logic_vector(7 downto 0);
			v_extborder: in std_logic;			
			is_double: in std_logic;
			v_shift: in std_logic_vector(3 downto 0);
			alt_rc_cnt: in std_logic_vector(3 downto 0);
			alt_set_rc: in std_logic;
			
			is_border: out std_logic;			
			is_last_row_of_char: out std_logic;
			is_last_row_of_screen: out std_logic;
			rcline_cnt: out std_logic_vector(3 downto 0);
			rline_cnt0: out std_logic;
			
			reset : in std_logic
		);
	end component;
	
begin

	slotclk <= dotclk(3);
	
	windows_p: process(dotclk)
	begin
			chr_window <= '0';
			pxl_window <= '0';
			attr_window <= '0';
			sr_window <= '0';

			-- access windows for pixel data, character data, or chr ROM
			if (dotclk(3 downto 2) = "00") then
				chr_window <= '1';
			end if;
			
			-- note: attributes must be loaded before character set, as attributes contain alternate character bit
			if (dotclk(3 downto 2) = "01") then
				attr_window <= '1';
			end if;

			if (dotclk(3 downto 2) = "10") then
				pxl_window <= '1';
			end if;			
			
			if (dotclk(3 downto 2) = "11") then
				sr_window <= '1';
			end if;
			
	end process;

	ce_p: process(dotclk)
	begin
			pxl0_ce <= '0';
			pxl1_ce <= '0';
			pxl2_ce <= '0';
			pxl3_ce <= '0';
			pxl4_ce <= '0';
			pxl5_ce <= '0';
			pxl6_ce <= '0';
			pxl7_ce <= '0';
			pxl8_ce <= '0';
			pxl9_ce <= '0';
			pxla_ce <= '0';
			pxlb_ce <= '0';
			pxlc_ce <= '0';
			pxld_ce <= '0';
			pxle_ce <= '0';
			pxlf_ce <= '0';

			if (dotclk(3 downto 0) = "0000") then
				pxl0_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0001") then
				pxl1_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0010") then
				pxl2_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0011") then
				pxl3_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0100") then
				pxl4_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0101") then
				pxl5_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0110") then
				pxl6_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "0111") then
				pxl7_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1000") then
				pxl8_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1001") then
				pxl9_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1010") then
				pxla_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1011") then
				pxlb_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1100") then
				pxlc_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1101") then
				pxld_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1110") then
				pxle_ce <= '1';
			end if;
			if (dotclk(3 downto 0) = "1111") then
				pxlf_ce <= '1';
			end if;
	end process;
	

	fetch_int <= is_enable and (not(in_slot) or is_80) and (interlace_int or not(rline_cnt0));
	
	-- do we fetch character index?
	-- not hires, and first cycle in streak
	chr_fetch_int <= chr_window and fetch_int and not(mode_bitmap);

	-- col fetch
	attr_fetch_int <= attr_window and fetch_int and (mode_attrib or mode_extended);
	
	-- hires fetch
	pxl_fetch_int <= pxl_window and fetch_int and mode_bitmap;
	
	-- character rom fetch
	crom_fetch_int <= pxl_window and fetch_int and not(mode_bitmap);

	-- sr load
	--sr_fetch_int <= is_enable and (sr40 or sr80) and (interlace_int or not(rline_cnt0));
	sr_fetch_int <= sr_window and fetch_int;
	
	
	fetch_p: process(chr_fetch_int, pxl_fetch_int, attr_fetch_int, crom_fetch_int, qclk)
	begin
		-- video access?
--		if (falling_edge(qclk) and dotclk(1 downto 0) = "11") then
			vid_fetch <= chr_fetch_int or pxl_fetch_int or attr_fetch_int or crom_fetch_int;
--		end if;
	end process;
	
	-----------------------------------------------------------------------------
	-- geometry calculation

	-------------------------------------------
	-- VGA canvas, incl. fixed enable output
	vgacanvas: Canvas
	port map (
		qclk,
		dotclk,
		h_sync_int,
		v_sync_int,
		h_zero,
		v_zero,
		h_enable,
		v_enable,
		x_addr,
		y_addr,
		reset
	);

	-------------------------------------------
	-- border calculations and display state

	h_border: HBorder
	port map (
			qclk,
			dotclk,
			h_zero,
			hsync_pos,
			slots_per_line,
			h_extborder,			
			is_80,
			x_start,
			x_border,
			last_vis_slot_of_line,
			in_slot,
			reset
	);

	v_border: VBorder
	port map (
			h_zero,	--h_sync_int,	
			v_zero,
			vsync_pos,
			rows_per_char,
			clines_per_screen,
			v_extborder,
			is_double_int,
			v_shift,
			alt_rc_cnt,
			alt_do_set_rc,
			y_border,
			last_line_of_char,
			last_line_of_screen,
			rcline_cnt,
			rline_cnt0,
			reset
	);
	
	alt_do_set_rc <= is_raster_match and alt_set_rc;
	
	h_sync <= not(h_sync_int); -- and not(v_sync_int));
	
	is_80 <= mode_80 or is_80_in;
	
	v_sync <= not(v_sync_int);
	pet_vsync <= v_sync_int;
	
	-----------------------------------------------------------------------------
	-- address calculations
	
	AddrHold: process(qclk, last_line_of_screen, vid_addr, reset) 
	begin
		if (reset ='1') then
			vid_addr_hold <= (others => '0');
		elsif (falling_edge(qclk) and dotclk = "0111") then
			if (last_vis_slot_of_line = '1') then
				if (last_line_of_screen = '1') then
					vid_addr_hold <= vid_base;
					attr_addr_hold <= attr_base;
				else
					if (last_line_of_char = '1') then
						attr_addr_hold <= attr_addr + va_offset;
					end if;
					if (mode_bitmap = '0') then
						if (last_line_of_char = '1') then
							vid_addr_hold <= vid_addr + va_offset;
						end if;
					else
						-- bitmap
						if (rline_cnt0 = '1' or is_double_int = '1') then
							vid_addr_hold <= vid_addr + va_offset;
						end if;
					end if;
					-- alternate values on raster match
					if (is_raster_match = '1' and alt_match_vaddr = '1') then
						vid_addr_hold <= vid_base_alt;
					end if;
					if (is_raster_match = '1' and alt_match_attr = '1') then
						attr_addr_hold <= attr_base_alt;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	AddrCnt: process(x_start, vid_addr, vid_addr_hold, is_80, in_slot, qclk, reset)
	begin
		if (reset = '1') then
			vid_addr <= (others => '0');
			attr_addr <= (others => '0');
		elsif (falling_edge(qclk) and dotclk = "1111") then
				if (x_start = '0') then
					if (is_80 = '1' or in_slot = '1') then
						vid_addr <= vid_addr + 1;
						attr_addr <= attr_addr + 1;
					end if;
				else
					vid_addr <= vid_addr_hold;
					attr_addr <= attr_addr_hold;
				end if;
		end if;
	end process;

	cam_p: process(crsr_address,vid_addr)
	begin
			if (vid_addr = crsr_address) then
				crsr_addr_match <= '1'; 
			else
				crsr_addr_match <= '0';
			end if;
	end process;
	
	-----------------------------------------------------------------------------
	-- replace discrete color circuitry of ultracpu 1.2b


	
	char_buf_p: process(qclk, memclk, chr_fetch_int, attr_fetch_int, pxl_fetch_int, VRAM_D, qclk, dena_int,
		mode_rev, sr_crsr, sr_blink, mode_attrib, mode_extended, attr_buf, cblink_active, uline_active)
	begin
		
		if (falling_edge(qclk)) then
			if (pxl3_ce = '1' and fetch_int = '1') then
				char_index_buf <= VRAM_D;
				sr_crsr <= crsr_addr_match and crsr_active;
			end if;
		end if;
		
		if (falling_edge(qclk)) then
			if (pxl7_ce = '1' and fetch_int = '1') then
				attr_buf <= VRAM_D;
			end if;
		end if;

		if (falling_edge(qclk)) then
			if (pxlb_ce = '1' and fetch_int = '1') then
				pxl_buf <= VRAM_D;
			end if;
		end if;

		-- when do I really need to load the pixel SR?
		if (falling_edge(qclk)) then
			nsrload	<= not (memclk and sr_fetch_int );
		end if;

		if (falling_edge(qclk)) then
			if (pxlb_ce = '1' and fetch_int = '1') then
			
				sr_underline_p <= '0';
				sr_blink <= '0';
				if (mode_attrib = '0') then
				elsif (mode_extended = '0') then
					if (attr_buf(6) = '1' 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1')) then
						sr_blink <= '1';
					end if;
					if (attr_buf(5) = '1' and uline_active = '1') then
						sr_underline_p <= '1';
					end if;
				else -- extended == 1			
					if (attr_buf(5) = '0' and ((attr_buf(6) = '1') 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1'))) then
						sr_blink <= '1';
					end if;
				end if;
				
				sr_reverse_p <= mode_rev 
								xor sr_crsr
								xor sr_blink;
			end if;
		end if;

		if (falling_edge(qclk)) then
			if (pxld_ce = '1' and fetch_int = '1') then
				--attr_buf2 <= attr_buf;
				if (sr_underline_p = '1') then
					sr_buf <= "11111111";
				elsif (sr_reverse_p = '1') then
					sr_buf <= not(pxl_buf);
				else
					sr_buf <= pxl_buf;
				end if;
			end if;
		end if;
		
		if (falling_edge(qclk)) then
			if (pxle_ce = '1' and (is_80 = '1' or in_slot = '0')) then
				sr_attr <= attr_buf;
				sr(7 downto 0) <= sr_buf;
				sr_odd <= '0';
				
				if (mode_attrib = '1' and mode_extended = '1') then
					-- multicolour (2-bit colour mode)
					is_outbit(1) <= sr_buf(7);
					is_outbit(0) <= sr_buf(6);
				else
					-- normal 1-bit colour modes
					is_outbit(1) <= '0';
					is_outbit(0) <= sr_buf(7);
				end if;
			elsif (dotclk(0) = '0' and (is_80 = '1' or dotclk(1) = '1')) then
				sr(7 downto 1) <= sr(6 downto 0);
				sr(0) <= '1';
				sr_odd <= not(sr_odd);
				
				if (mode_attrib = '1' and mode_extended = '1') then
					if (sr_odd = '1') then
						-- multicolour (2-bit colour mode)
						is_outbit(1) <= sr(6);
						is_outbit(0) <= sr(5);
					end if;
				else
					is_outbit(1) <= '0';
					is_outbit(0) <= sr(6);
				end if;

			end if;
		end if;
	end process;
					
	rasterout_p: process(qclk, sr, x_border, y_border, dispen, mode_extended, mode_attrib, sr_attr, col_border, is_outbit, 
		col_bg0, col_fg, col_bg1, col_bg2)
	begin
		if (falling_edge(qclk) and dotclk(0) = '1') then -- and (is_80 = '1' or dotclk(1) = '1')) then
			if (mode_extended = '0' and mode_attrib = '0') then
				-- 2 COL MODE
				if is_outbit(0) = '0' then
					raster_outbit <= col_bg0;
				else
					raster_outbit <= col_fg;
				end if;
			elsif (mode_extended = '0' and mode_attrib = '1') then
				-- ATTRIBUTE MODE (VDC)
				if (is_outbit(0) = '0') then
					raster_outbit <= col_bg0;
				else
					raster_outbit <= sr_attr(3 downto 0);
				end if;
			elsif (mode_extended = '1' and mode_attrib = '0') then
				-- EXTENDED MODE (COLOUR PET)
				if is_outbit(0) = '0' then
					raster_outbit <= sr_attr(7 downto 4);
				else
					raster_outbit <= sr_attr(3 downto 0);
				end if;
			else
				-- MULTICOLOUR MODE
				case (is_outbit) is
				when "00" =>
--					raster_outbit <= "0001"; -- d.grey
					raster_outbit <= sr_attr(7 downto 4);
				when "01" =>
--					raster_outbit <= "0100"; -- green
					raster_outbit <= col_bg1;
				when "10" =>
--					raster_outbit <= "0010"; -- blue
					raster_outbit <= col_bg2;
				when "11" =>
--					raster_outbit <= "1000"; -- red
					raster_outbit <= sr_attr(3 downto 0);
				when others =>
					raster_outbit <= col_border;
				end case;
			end if;
		end if;
	end process;
	
	vid_out_p: process (qclk, dena_int)
	begin
		if (dena_int = '0') then
			vid_out <= (others => '0');
		elsif (falling_edge(qclk) and dotclk(0) = '1') then -- and (is_80 = '1' or dotclk(1) = '1')) then

			if (x_border = '1' or y_border = '1' or dispen = '0') then
				-- BORDER
				vid_out <= col_border;
			elsif (is_80 = '1' or dotclk(1) = '1') then
			case (h_shift(2 downto 0)) is
			when "000" =>
				vid_out <= raster_outbit;
			when "001" =>
				vid_out <= raster_out(0);
			when "010" =>
				vid_out <= raster_out(1);
			when "011" =>
				vid_out <= raster_out(2);
			when "100" =>
				vid_out <= raster_out(3);
			when "101" =>
				vid_out <= raster_out(4);
			when "110" =>
				vid_out <= raster_out(5);
			when "111" =>
				vid_out <= raster_out(6);
			when others =>
				vid_out <= col_border;
			end case;
			end if;
			
			raster_out(6) <= raster_out(5);
			raster_out(5) <= raster_out(4);
			raster_out(4) <= raster_out(3);
			raster_out(3) <= raster_out(2);
			raster_out(2) <= raster_out(1);
			raster_out(1) <= raster_out(0);
			raster_out(0) <= raster_outbit;			
		end if;
	end process;
	
	-----------------------------------------------------------------------------
	-- mem_addr = hires fetch or chr fetch (i.e. NOT charrom pxl fetch)
	
	a_out(3 downto 0) <= 
							attr_addr(3 downto 0) 	when attr_fetch_int = '1' else
							rcline_cnt 				 	when crom_fetch_int = '1' else
							vid_addr(3 downto 0);

	a_out(11 downto 4) <= 
							attr_addr(11 downto 4)	when attr_fetch_int = '1' else
							char_index_buf				when crom_fetch_int = '1' else
							vid_addr(11 downto 4);

	a_out(12) 		<= 
							attr_addr(12)				when attr_fetch_int = '1' else
							is_graph						when crom_fetch_int = '1' else
							vid_addr(12);

	a_out(15 downto 13) <= 
							attr_addr(15 downto 13)	when attr_fetch_int = '1' else
							crom_base(7 downto 5) 	when crom_fetch_int = '1' else
							vid_addr(15 downto 13);
							
	A <= a_out;
	
	-----------------------------------------------------------------------------
	-- output sr control

	en_p: process(nsrload)
	begin
		-- sr_load changes on falling edge of qclk
		-- sr_load_d changes on rising edge of qclk
		-- in_slot changes at falling edge of slotclk, which itself changes on falling edge of qclk
		if (rising_edge(nsrload)
			--and (in_slot = '1')
			) then
			enable <= h_enable and v_enable
				and (interlace_int or not(rline_cnt0));
		end if;
	end process;

	dena_int <= enable;

	--------------------------------------------
	-- raster interrupt handling
	
	RasterMatch: process(h_zero, raster_match, y_addr)
	begin
		
		if (rising_edge(h_zero)) then
			if (raster_match = y_addr) then
				is_raster_match <= '1';
			else
				is_raster_match <= '0';
			end if;
		end if;
		
	end process;
	
	RasterIrq: process(phi2, crtc_reg, crtc_sel, crtc_rs, reset)
	begin
		if (falling_edge(phi2)) then
			
			if (is_raster_match = '0') then
				irq_raster_ack <= '0';
			end if;
			
			if (crtc_sel = '1' and crtc_rs(0) = '1' and crtc_reg = x"2b"
					--and crtc_rwb = '0'	-- note this seems to break display...???
					) then
				--if (CPU_D(0) = '1') then
					irq_raster_ack <= '1';
				--end if;
			end if;
			
		end if;

		if (reset = '1') then
			irq_raster <= '0';
		elsif (falling_edge(phi2)) then
			if (irq_raster_ack = '1') then
				irq_raster <= '0';
			elsif (is_raster_match = '1') then
				irq_raster <= '1';
			end if;
		end if;
		
	end process;
	
	irq_out_int <= (irq_raster and irq_raster_en); 
				-- or (irq_sprite_bg and irq_sprite_bg_en) 
				-- or (irq_sprite_sprite and irq_sprite_sprite_en)
				-- or ...
	
	irq_out <= irq_out_int;
	
	--------------------------------------------
	-- alt modes
	altmodes_p: process(qclk)
	begin
	
		if (falling_edge(qclk)) then
			
			if (v_zero = '1' or mode_set_flag = '1') then
				mode_attrib <= mode_attrib_reg;
				mode_extended <= mode_extended_reg;
				mode_bitmap <= mode_bitmap_reg;
			elsif (is_raster_match = '1' and alt_match_modes = '1') then
				mode_attrib <= mode_attrib_alt;
				mode_extended <= mode_extended_alt;
				mode_bitmap <= mode_bitmap_alt;
			end if;
		end if;
	end process;

	Writemode_p: process(phi2, h_zero, crtc_reg, crtc_sel, crtc_rs, reset)
	begin
		if (h_zero = '1') then
			mode_set_flag <= '0';
		elsif (falling_edge(phi2)) then
			if (crtc_sel = '1' and crtc_rs(0) = '1' and (crtc_reg = x"19" or crtc_reg = x"27")
					and crtc_rwb = '0'	-- note this seems to break display...???
					) then
				mode_set_flag <= '1';
			end if;
		end if;
	end process;
	
	--------------------------------------------
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now

	dbg_out <= '0';

	is_double_int <= mode_double;
	interlace_int <= mode_interlace;
	
	regfile: process(phi2, CPU_D, crtc_sel, crtc_rs, crtc_rwb, reset) 
	begin
		if (reset = '1') then
			crtc_reg <= (others => '0');
		elsif (falling_edge(phi2) and crtc_sel = '1' ) then
		
			if (crtc_rs=x"3") then
				crtc_reg(6 downto 0) <= crtc_reg(6 downto 0) + 1;
			elsif (crtc_rs=x"0" and crtc_rwb = '0' ) then
				crtc_reg(6 downto 0) <= CPU_D(6 downto 0);
			end if;
		end if;
	end process;
	
	reg9: process(phi2, CPU_D, crtc_sel, crtc_rs, crtc_rwb, crtc_reg, reset) 
	begin
		if (reset = '1') then
			mode_rev <= '0';
			cblink_mode <= '0';
			mode_attrib_reg <= '0';
			mode_extended_reg <= '0';
			mode_bitmap_reg <= '0';
			mode_attrib_alt <= '0';
			mode_extended_alt <= '0';
			mode_bitmap_alt <= '0';
			mode_upet <= '1';
			mode_double <= '0';
			mode_interlace <= '0';
			mode_80 <= '0';
			mode_altreg <= '0';
			alt_match_modes <= '0';
			alt_match_vaddr <= '0';
			alt_match_attr <= '0';
			alt_rc_cnt <= "0000";
			alt_set_rc <= '0';
			dispen <= '1';
			crsr_mode <= (others => '0');
			crsr_address <= (others => '0');
			rows_per_char <= "0111"; -- 7
			slots_per_line <= "1010000";	-- 80
			hsync_pos <= "0001000";	-- 8
			vsync_pos <= std_logic_vector(to_unsigned(84,10));
			clines_per_screen <= "00011001";	-- 25
			attr_base <= x"d000";
			attr_base_alt <= x"d000";
			vid_base <= x"9000";
			vid_base_alt <= x"9000";
			crom_base <= x"00";
			col_fg <= "1111";
			col_bg0 <= "0000";
			col_bg1 <= "0000";
			col_bg2 <= "0000";
			col_border <= "0000";
			uline_scan <= (others => '0');
			h_extborder <= '0';
			v_extborder <= '0';
			h_shift <= (others => '0');
			v_shift <= (others => '0');
			va_offset <= (others => '0');
			raster_match <= (others => '0');
			irq_raster_en <= '0';
		elsif (falling_edge(phi2) 
				and crtc_sel = '1' 
				and (crtc_rs=x"1" or crtc_rs=x"3") 
				and crtc_rwb = '0'
				) then
			case (crtc_reg) is
			when x"01" =>
				-- note: if upet compat, value written is doubled (as in the PET for 80 columns)
				if (mode_upet = '1' or is_80 = '0') then
					slots_per_line(6 downto 1) <= CPU_D(5 downto 0);
					slots_per_line(0) <= '0';
				else
					slots_per_line(6 downto 0) <= CPU_D(6 downto 0);
				end if;
			when x"02" => 
			when x"06" => 
				clines_per_screen <= CPU_D;
			when x"08" =>
				-- b1: interlace, b0: double (if b1=1)
				mode_interlace <= CPU_D(1);
				mode_double <= CPU_D(0) and CPU_D(1);
				mode_80 <= CPU_D(7);
			when x"09" =>
				rows_per_char <= CPU_D(3 downto 0);
				if (mode_upet = '1') then
					if (CPU_D(3) = '1') then
						vsync_pos <= std_logic_vector(to_unsigned(59,10));
						rows_per_char <= "1000";	-- limit to 8
					else
						vsync_pos <= std_logic_vector(to_unsigned(84,10));
					end if;
				end if;
			when x"0a" =>
				crsr_start_scan <= CPU_D(4 downto 0);
				crsr_mode <= CPU_D(6 downto 5);
			when x"0b" => 
				crsr_end_scan <= CPU_D(4 downto 0);
			when x"0c" =>
				if (mode_altreg = '1') then
					vid_base_alt(14 downto 8) <= CPU_D(6 downto 0);
					if (mode_upet = '1') then
						vid_base_alt(15) <= not(CPU_D(7));
					else
						vid_base_alt(15) <= CPU_D(7);
					end if;
				else
					vid_base(14 downto 8) <= CPU_D(6 downto 0);
					if (mode_upet = '1') then
						vid_base(15) <= not(CPU_D(7));
					else
						vid_base(15) <= CPU_D(7);
					end if;
				end if;
			when x"0d" =>
				if (mode_altreg = '1') then
					vid_base_alt(7 downto 0) <= CPU_D;
				else
					vid_base(7 downto 0) <= CPU_D;
				end if;
			when x"0e" =>
				crsr_address(14 downto 8) <= CPU_D(6 downto 0);
				if (mode_upet = '1') then
					crsr_address(15) <= not(CPU_D(7));
				else
					crsr_address(15) <= CPU_D(7);
				end if;
			when x"0f" =>	-- R15
				crsr_address(7 downto 0) <= CPU_D;
			when x"14" =>	-- R20
				if (mode_altreg = '1') then
					attr_base_alt(15 downto 8) <= CPU_D;
				else
					attr_base(15 downto 8) <= CPU_D;
				end if;
			when x"15" =>	-- R21
				if (mode_altreg = '1') then
					attr_base_alt(7 downto 0) <= CPU_D;
				else
					attr_base(7 downto 0) <= CPU_D;
				end if;
			when x"18" =>	-- R24
				v_shift <= CPU_D(3 downto 0);
				v_extborder <= CPU_D(4);
				cblink_mode <= CPU_D(5);
				mode_rev <= CPU_D(6);
			when x"19" =>	-- R25
				h_shift <= CPU_D(3 downto 0);
				h_extborder <= CPU_D(4);
				mode_attrib_reg <= CPU_D(6);
				mode_bitmap_reg <= CPU_D(7);
			when x"1a" => 	-- R26
				col_fg <= CPU_D(7 downto 4);
				col_bg0 <= CPU_D(3 downto 0);
			when x"1b" => -- R27
				va_offset <= CPU_D;
			when x"1c" => 	-- R28
				crom_base <= CPU_D;
			when x"1d" => 	-- R29
				uline_scan <= CPU_D(4 downto 0);
			when x"1e" =>	-- R30
				raster_match(7 downto 0) <= CPU_D;
			when x"1f" =>	-- R31
				raster_match(9 downto 8) <= CPU_D(1 downto 0);
			when x"27" =>	-- R39
				mode_extended_reg <= CPU_D(2);
				dispen <= CPU_D(4);
				mode_upet <= CPU_D(7);
			when x"28" => 	-- R40
				col_bg1 <= CPU_D(3 downto 0);
				col_bg2 <= CPU_D(7 downto 4);
			when x"29" =>	-- R41
				col_border <= CPU_D(3 downto 0);
			when x"2a" =>	-- R42
				irq_raster_en <= CPU_D(0);
			when x"2c" =>	-- R44
				-- horizontal sync
				hsync_pos <= CPU_D(6 downto 0);
			when x"2d" =>	-- R45
				vsync_pos <= CPU_D;
			when x"2e" =>	-- R46 (alternate control I)
				mode_altreg <= CPU_D(0);
				mode_bitmap_alt <= CPU_D(1);
				mode_attrib_alt <= CPU_D(2);
				mode_extended_alt <= CPU_D(3);
				alt_match_modes <= CPU_D(5);
				alt_match_attr <= CPU_D(6);
				alt_match_vaddr <= CPU_D(7);				
			when x"2f" =>	-- R47 (alternate control II)
				alt_rc_cnt <= CPU_D(3 downto 0);
				alt_set_rc <= CPU_D(7);
			when others =>
				null;
			end case;
		end if;
	end process;

	readreg: process(crtc_rwb, crtc_sel, crtc_rs, crtc_reg, reset) 
	begin
		if (reset = '1') then
			vd_out <= (others => '0');
			y_addr_latch <= (others => '0');
		else 
			vd_out <= (others => '0');
			
			if	(crtc_sel = '1'
				and crtc_rwb = '1'
				) then
				
				if (crtc_rs = x"2") then
					vd_out <= crtc_reg;
				elsif (crtc_rs = x"0") then
					-- TODO: status register at address 0
				elsif (crtc_rs = x"1" or crtc_rs = x"3") then

					case (crtc_reg) is
					when x"01" =>
						-- note: if upet compat, value written is doubled (as in the PET for 80 columns)
						if (mode_upet = '1' or is_80 = '0') then
							vd_out(5 downto 0) <= slots_per_line(6 downto 1);
						else
							vd_out(6 downto 0) <= slots_per_line(6 downto 0);
						end if;
					when x"02" =>
					when x"06" => 
						vd_out <= clines_per_screen;
					when x"08" =>
						vd_out(0) <= mode_double;
						vd_out(1) <= mode_interlace;
						vd_out(7) <= mode_80;
					when x"09" =>
						vd_out(3 downto 0) <= rows_per_char;
					when x"0a" =>
						vd_out(4 downto 0) <= crsr_start_scan;
						vd_out(6 downto 5) <= crsr_mode;
					when x"0b" =>
						vd_out(4 downto 0) <= crsr_end_scan;
					when x"0c" =>
						if (mode_altreg = '1') then
							vd_out(6 downto 0) <= vid_base_alt(14 downto 8);
							if (mode_upet = '1') then
								vd_out(7) <= not(vid_base_alt(15));
							else
								vd_out(7) <= vid_base_alt(15);
							end if;
						else
							vd_out(6 downto 0) <= vid_base(14 downto 8);
							if (mode_upet = '1') then
								vd_out(7) <= not(vid_base(15));
							else
								vd_out(7) <= vid_base(15);
							end if;
						end if;
					when x"0d" =>
						if (mode_altreg = '1') then
							vd_out <= vid_base_alt(7 downto 0);
						else
							vd_out <= vid_base(7 downto 0);
						end if;
					when x"0e" =>
						vd_out(6 downto 0) <= crsr_address(14 downto 8);
						if (mode_upet = '1') then
							vd_out(7) <= not(crsr_address(15));
						else
							vd_out(7) <= crsr_address(15);
						end if;
					when x"0f" =>	-- R15
						vd_out <= crsr_address(7 downto 0);
					when x"14" =>	-- R20
						if (mode_altreg = '1') then
							vd_out <= attr_base_alt(15 downto 8);
						else 
							vd_out <= attr_base(15 downto 8);
						end if;
					when x"15" =>	-- R21
						if (mode_altreg = '1') then
							vd_out <= attr_base_alt(7 downto 0);
						else
							vd_out <= attr_base(7 downto 0);
						end if;
					when x"18" =>	-- R24
						vd_out(3 downto 0) <= v_shift;
						vd_out(4) <= v_extborder;
						vd_out(5) <= cblink_mode;
						vd_out(6) <= mode_rev;
					when x"19" =>	-- R25
						vd_out(3 downto 0) <= h_shift;
						vd_out(4) <= h_extborder;
						vd_out(6) <= mode_attrib;
						vd_out(7) <= mode_bitmap;
					when x"1a" => 	-- R26
						vd_out(7 downto 4) <= col_fg;
						vd_out(3 downto 0) <= col_bg0;
					when x"1b" => 	-- R27
						vd_out <= va_offset;
					when x"1c" => 	-- R28
						vd_out <= crom_base;
					when x"1d" => 	-- R29
						vd_out(4 downto 0) <= uline_scan;
					when x"1e" => 	-- R30
						vd_out <= y_addr(7 downto 0);
						y_addr_latch(9 downto 8) <= y_addr(9 downto 8);
					when x"1f" =>	-- R31
						vd_out(1 downto 0) <= y_addr_latch(9 downto 8);
					when x"25" => 	-- R37
						vd_out(6) <= h_sync_int;
						vd_out(5) <= v_sync_int;
					when x"27" =>	-- R39
						vd_out(2) <= mode_extended;
						vd_out(4) <= dispen;
						vd_out(7) <= mode_upet;
					when x"28" => 	-- R40
						vd_out(3 downto 0) <= col_bg1;
						vd_out(7 downto 4) <= col_bg2;
					when x"29" =>	-- R41
						vd_out(3 downto 0) <= col_border;
					when x"2a" =>	-- R44
						vd_out(0) <= irq_raster_en;
					when x"2b" =>	-- R44
						vd_out(0) <= irq_raster;
						vd_out(7) <= irq_out_int;
					when x"2c" =>	-- R44
						vd_out(6 downto 0) <= hsync_pos;
					when x"2d" =>	-- R45
						vd_out(7 downto 0) <= vsync_pos;
					when x"2e" =>	-- R46 (alternate control I)
						vd_out(0) <= mode_altreg;
						vd_out(1) <= mode_bitmap_alt;
						vd_out(2) <= mode_attrib_alt;
						vd_out(3) <= mode_extended_alt;
						vd_out(5) <= alt_match_modes;
						vd_out(6) <= alt_match_attr;
						vd_out(7) <= alt_match_vaddr;
					when x"2f" =>	-- R47 (alternate control II)
						vd_out(3 downto 0) <= alt_rc_cnt;
						vd_out(7) <= alt_set_rc;
					when others =>
						null;
					end case;
				end if;
			end if;
		end if;
	end process;

	--- blinker

	blink_p: process(v_sync_int, reset, blink_cnt)
	begin
		if (reset = '1') then
			blink_cnt <= (others => '0');
		elsif (falling_edge(v_sync_int)) then
			blink_cnt <= blink_cnt + 1;
		end if;
		
		blink_16 <= blink_cnt(4);
		blink_32 <= blink_cnt(5);
	end process;
	
	--- cursor
	crsr_p: process(h_sync_int)
	begin
		if (falling_edge(h_sync_int)) then
			if rcline_cnt = crsr_start_scan then
				case crsr_mode is
				when "00" =>
					crsr_active <= '1';
				when "01" =>
					crsr_active <= '0';
				when "10" =>
					crsr_active <= blink_16;
				when "11" => 
					crsr_active <= blink_32;
				when others =>
					null;
				end case;
			elsif rcline_cnt = crsr_end_scan then
				crsr_active <= '0';
			end if;
		end if;
	end process;

	--- underline
	uline_p: process(h_sync_int)
	begin
		if (falling_edge(h_sync_int)) then
			if rcline_cnt = uline_scan then
				uline_active <= '1';
			else
				uline_active <= '0';
			end if;
		end if;
	end process;
	
	cblink_p: process(h_sync_int) 
	begin
		if (falling_edge(h_sync_int)) then
			if ((cblink_mode = '0' and blink_16='1') or (cblink_mode = '1' and blink_32 = '1')) then
				cblink_active <= '1';
			else 
				cblink_active <= '0';
			end if;
		end if;
	end process;
	
end Behavioral;

