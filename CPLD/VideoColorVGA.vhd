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
      is_80_in : in std_logic;	-- is 80 column mode?
	   is_graph : in std_logic;	-- graphic mode (from PET I/O)
	   is_double: in std_logic;
	   interlace: in std_logic;
	   movesync:  in std_logic;
	   
	   crtc_sel : in std_logic;
	   crtc_rs : in std_logic_vector(3 downto 0);
	   crtc_rwb : in std_logic;
	   
	   qclk: in std_logic;		-- Q clock (50MHz)
		dotclk: in std_logic_vector(3 downto 0);	-- 25Mhz, 1/2, 1/4, 1/8, 1/16
      memclk : in STD_LOGIC;	-- system clock (12.5MHz)
	   
	   vid_fetch : out std_logic; -- true during video access phase (all, character, chrom, and hires pixel data)

	   vid_out: out std_logic_vector(3 downto 0);
		
	   dbg_out : out std_logic;
	   
	   reset : in std_logic
	   );
end Video;

architecture Behavioral of Video is

	--- modes
	signal mode_attrib: std_logic;			-- r25.6, enable attribute use
	signal mode_extended: std_logic;		-- r33.2, enables full and multicolor modes
	signal mode_bitmap: std_logic;
	signal mode_upet: std_logic;			-- when Micro-PET compat, r1 and others behave differently
	signal mode_rev: std_logic;			-- r24.6, reverse the screen
	signal dispen: std_logic;
	
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
	signal is_outbit: std_logic;
	
	-- 1 bit slot counter to enable 40 column
	signal in_slot: std_logic;
	
	-- mode
	signal is_80: std_logic;
	
	-- crtc register emulation
	signal crtc_reg: std_logic_vector(7 downto 0);
	
	signal rows_per_char: std_logic_vector(3 downto 0);
	signal slots_per_line: std_logic_vector(6 downto 0);
	signal clines_per_screen: std_logic_vector(6 downto 0);
	signal hsync_pos: std_logic_vector(6 downto 0);
	signal vsync_pos: std_logic_vector(7 downto 0);
	
	signal vid_base : std_logic_vector(15 downto 0);
	signal attr_base : std_logic_vector(15 downto 0);
	signal crom_base : std_logic_vector(7 downto 0);

	-- count "slots", i.e. 8pixels
	-- 
	-- one slot may need none (out of screen), one (hires), or two (character display) 
	-- memory accesses. At 16MHz pixel, a slot has four potential memory accesses at 8MHz
	-- up to 127 slots/line
	--
	-- now see ClockBorder.vhd
	
	-- count raster lines
	signal rline_cnt : std_logic_vector (9 downto 0) := (others => '0');
	-- count raster lines per character lines
	signal rcline_cnt : std_logic_vector (3 downto 0) := (others => '0');
	-- count character lines
	signal cline_cnt : std_logic_vector (6 downto 0) := (others => '0');
	
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
	signal pxl_buf : std_logic_vector(7 downto 0);
	-- replacements for shift register
	signal sr : std_logic_vector(7 downto 0);
	signal nsrload : std_logic;
	signal dena_int : std_logic;
	signal sr_attr: std_logic_vector(7 downto 0); -- the attributes for the bitmap in sr
	signal sr_crsr: std_logic;
	

	-- geo signals
	--
   signal x_addr: std_logic_vector(9 downto 0);    -- x coordinate in pixels
   signal y_addr: std_logic_vector(9 downto 0);    -- y coordinate in rasterlines

	-- border
	signal h_shift: std_logic_vector(3 downto 0);
	signal h_extborder: std_logic;
	signal is_preload: std_logic;
	signal v_extborder: std_logic;
	
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
	
	-- convenience
	signal chr40 : std_logic;
	signal chr80 : std_logic;
	signal pxl40 : std_logic;
	signal pxl80 : std_logic;
	signal attr40 : std_logic;
	signal attr80 : std_logic;
	signal sr40 : std_logic;
	signal sr80 : std_logic;

	signal chr_fetch_int : std_logic;
	signal crom_fetch_int: std_logic;
	signal pxl_fetch_int : std_logic;
	signal attr_fetch_int : std_logic;
	signal sr_fetch_int : std_logic;
	
	signal next_row : std_logic;
	
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
			h_shift: in std_logic_vector(3 downto 0);
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
			clines_per_screen: in std_logic_vector(6 downto 0);
			v_extborder: in std_logic;			
			is_double: in std_logic;
			
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
	

	fetch_int <= is_enable and (not(in_slot) or is_80) and (interlace or not(rline_cnt0));
	
	-- access indicators
	--
	-- pxl40/chr40 are used in both 40 and 80 col mode
	chr40 <= chr_window  and in_slot 	and not(mode_bitmap)		and is_80;
	pxl40 <= pxl_window  and in_slot										and is_80;
	attr40 <= attr_window and in_slot									and is_80;
	sr40 <= sr_window and in_slot											and is_80;
	chr80 <= chr_window  and not(in_slot) 	and not(mode_bitmap);
	pxl80 <= pxl_window  and not(in_slot);
	attr80 <= attr_window and not(in_slot);
	sr80 <= sr_window and not(in_slot);

	-- do we fetch character index?
	-- not hires, and first cycle in streak
	chr_fetch_int <= is_enable and (chr40 or chr80) and (interlace or not(rline_cnt0)) ;

	-- col fetch
	attr_fetch_int <= is_enable and (attr40 or attr80) and (interlace or not(rline_cnt0));
	
	-- hires fetch
	pxl_fetch_int <= is_enable and mode_bitmap and (pxl40 or pxl80) and (interlace or not(rline_cnt0));
	
	-- character rom fetch
	crom_fetch_int <= is_enable and not(mode_bitmap) and (pxl40 or pxl80) and (interlace or not(rline_cnt0));

	-- sr load
	sr_fetch_int <= is_enable and (sr40 or sr80) and (interlace or not(rline_cnt0));
	
	-- video access?
	vid_fetch <= chr_fetch_int or pxl_fetch_int or attr_fetch_int or crom_fetch_int;

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
			h_shift,
			h_extborder,			
			is_80,
			is_preload,
			x_border,
			last_vis_slot_of_line,
			in_slot,
			reset
	);

	x_start <= is_preload;

	v_border: VBorder
	port map (
			h_sync_int,	
			v_zero,
			vsync_pos,
			rows_per_char,
			clines_per_screen,
			v_extborder,
			is_double,
			y_border,
			last_line_of_char,
			last_line_of_screen,
			rcline_cnt,
			rline_cnt0,
			reset
	);
	
--	rline_cnt0 <= rline_cnt(0);
	
	h_sync <= not(h_sync_int); -- and not(v_sync_int));
	
	is_80 <= is_80_in;
	
	-----------------------------------------------------------------------------
	-- vertical geometry calculation
	
--	next_row <= rline_cnt0 or is_double;
--
--	LineCnt: process(h_sync_int, last_line_of_screen, rline_cnt, rcline_cnt, reset)
--	begin
--		if (reset = '1') then
--			rline_cnt <= (others => '0');
--			rcline_cnt <= (others => '0');
--			cline_cnt <= (others => '0');
--		elsif (rising_edge(h_sync_int)) then
--			if (v_zero = '1') then
--				rline_cnt <= (others => '0');
--				rcline_cnt <= (others => '0');
--				cline_cnt <= (others => '0');
--			else
--				rline_cnt <= rline_cnt + 1;
--				
--				if (last_line_of_char = '1') then
--					rcline_cnt <= (others => '0');
--					cline_cnt <= cline_cnt + 1;
--				elsif (next_row = '1') then
--					-- display each char line twice
--					rcline_cnt <= rcline_cnt + 1;
--				end if;
--			end if;
--			
--		end if;
--	end process;
--
--	LineProx: process(h_sync_int)
--	begin
--		if (falling_edge(h_sync_int)) then
--			
--		  if (rows_per_char(3) = '1') then
--		  
--			-- timing for 9 or more pixel rows per character
--			-- end of character line
--			if ((mode_bitmap = '1' or rcline_cnt = 8) and next_row = '1') then
--				-- if hires, everyone
--				last_line_of_char <= '1';
--			else
--				last_line_of_char <= '0';
--			end if;
--
--			
--		  else	-- rows_per_char(3) = '0'
--		  
--			-- timing for 8 pixel rows per character
--			-- end of character line
--			if ((mode_bitmap = '1' or rcline_cnt = rows_per_char) and next_row = '1') then
--				-- if hires, everyone
--				last_line_of_char <= '1';
--			else
--				last_line_of_char <= '0';
--			end if;
--
--		  end if; -- crtc_is_9rows
--
--		    -- common for 8/9 pixel rows per char
--		    
--			-- end of screen
--			if (rline_cnt = 524) then
--				last_line_of_screen <= '1';
--			else
--				last_line_of_screen <= '0';
--			end if;
--	
--		
--		end if; -- rising edge...
--	end process;

	v_sync <= not(v_sync_int);
	pet_vsync <= v_sync_int;
	
	-----------------------------------------------------------------------------
	-- address calculations
	
	AddrHold: process(slotclk, last_line_of_screen, vid_addr, reset) 
	begin
		if (reset ='1') then
			vid_addr_hold <= (others => '0');
		elsif (rising_edge(slotclk)) then
			if (last_vis_slot_of_line = '1') then
				if (last_line_of_screen = '1') then
					vid_addr_hold <= vid_base;
					attr_addr_hold <= attr_base;
				else
					if (last_line_of_char = '1') then
						vid_addr_hold <= vid_addr;
						attr_addr_hold <= attr_addr;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	AddrCnt: process(x_start, last_line_of_screen, vid_addr, vid_addr_hold, is_80, in_slot, slotclk, reset)
	begin
		if (reset = '1') then
			vid_addr <= (others => '0');
			attr_addr <= (others => '0');
		elsif (falling_edge(slotclk)) then
--			if (last_line_of_screen = '1' and x_start = '1') then
--				vid_addr <= (others => '0');
--				attr_addr <= (others => '0');
--				is_80 <= is_80_in;
--			else
				if (x_start = '0') then
					if (is_80 = '1' or in_slot = '1') then
						vid_addr <= vid_addr + 1;
						attr_addr <= attr_addr + 1;
					end if;
				else
					vid_addr <= vid_addr_hold;
					attr_addr <= attr_addr_hold;
				end if;
--			end if;
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


	
	char_buf_p: process(qclk, memclk, chr_fetch_int, attr_fetch_int, pxl_fetch_int, VRAM_D, qclk, dena_int)
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
			if (pxl0_ce = '1' and fetch_int = '1') then
				sr_reverse_p <= '0';
				sr_underline_p <= '0';
			elsif (pxl9_ce = '1' and fetch_int = '1') then
				
				sr_reverse_p <= mode_rev;
				sr_underline_p <= '0';
				-- independent from extended and bitmap
				if (sr_crsr = '1') then
					sr_reverse_p <= not(sr_reverse_p);
				end if;	
				if (mode_attrib = '0') then
				elsif (mode_extended = '0') then
					if (attr_buf(6) = '1' 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1')) then
						sr_reverse_p <= not(sr_reverse_p);
					end if;
					if (attr_buf(5) = '1' and uline_active = '1') then
						sr_underline_p <= '1';
					end if;
				else -- extended == 1			
					if (attr_buf(5) = '0' and ((attr_buf(6) = '1') 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1'))) then
						sr_reverse_p <= not(sr_reverse_p);
					end if;
				end if;
			end if;
		end if;
		
		if (falling_edge(qclk)) then
			if (pxlf_ce = '1' and (is_80 = '1' or in_slot = '0')) then
				sr_attr <= attr_buf;
				sr <= pxl_buf;
				sr_reverse <= sr_reverse_p;
				sr_underline <= sr_underline_p;
			elsif (dotclk(0) = '1' and (is_80 = '1' or dotclk(1) = '1')) then
					sr(7 downto 1) <= sr(6 downto 0);
					sr(0) <= '1';
			end if;
		end if;		
	end process;

	is_outbit <= '1' when sr_underline = '1' else
					sr(7) when sr_reverse = '0' else
					not(sr(7));
					
	vid_out_p: process (qclk, dena_int)
	begin
		if (dena_int = '0') then
			vid_out <= (others => '0');
		elsif (falling_edge(qclk) and dotclk(0) = '1' and (is_80 = '1' or dotclk(1) = '1')) then

			if (x_border = '1' or y_border = '1' or dispen = '0') then
				vid_out <= col_border;
			elsif (mode_extended = '0' and mode_attrib = '0') then
				if is_outbit = '0' then
					vid_out <= col_bg0;
				else
					vid_out <= col_fg;
				end if;
			elsif (mode_extended = '0' and mode_attrib = '1') then
				if (is_outbit = '0') then
					vid_out <= col_bg0;
				else
					vid_out <= sr_attr(3 downto 0);
				end if;
			elsif (mode_extended = '1' and mode_attrib = '0') then
				if is_outbit = '0' then
					vid_out <= sr_attr(7 downto 4);
				else
					vid_out <= sr_attr(3 downto 0);
				end if;
			else
				if (is_outbit = '0') then
					vid_out <= attr_buf(7 downto 4);
				else 
					vid_out <= attr_buf(3 downto 0);
				end if;
			end if;
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
				and (interlace or not(rline_cnt0));
		end if;
	end process;

	dena_int <= enable;
	
	--------------------------------------------
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now

	dbg_out <= '0';

	regfile: process(phi2, CPU_D, crtc_sel, crtc_rs, crtc_rwb, reset) 
	begin
		if (reset = '1') then
			crtc_reg <= (others => '0');
		elsif (falling_edge(phi2) and crtc_sel = '1' ) then
		
			if (crtc_rs=x"3") then
				crtc_reg(5 downto 0) <= crtc_reg(5 downto 0) + 1;
			elsif (crtc_rs=x"0" and crtc_rwb = '0' ) then
				crtc_reg(5 downto 0) <= CPU_D(5 downto 0);
			end if;
		end if;
	end process;
	
	reg9: process(phi2, CPU_D, crtc_sel, crtc_rs, crtc_rwb, crtc_reg, reset) 
	begin
		if (reset = '1') then
			mode_rev <= '0';
			cblink_mode <= '0';
			mode_attrib <= '0';
			mode_extended <= '0';
			mode_bitmap <= '0';
			mode_upet <= '1';
			dispen <= '1';
			crsr_mode <= (others => '0');
			crsr_address <= (others => '0');
			rows_per_char <= X"7";
			slots_per_line <= "1010000";	-- 80
			hsync_pos <= "0001000";	-- 8
			vsync_pos <= "01001110"; -- 78
			clines_per_screen <= "0011001";	-- 25
			attr_base <= x"d000";
			vid_base <= x"9000";
			crom_base <= x"00";
			col_fg <= "1111";
			col_bg0 <= "0000";
			col_bg1 <= "0000";
			col_bg2 <= "0000";
			col_border <= "0111";
			uline_scan <= (others => '0');
			h_extborder <= '0';
			v_extborder <= '0';
			h_shift <= (others => '0');
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
				clines_per_screen <= CPU_D(6 downto 0);
			when x"09" =>
				rows_per_char <= CPU_D(3 downto 0);
				if (mode_upet = '1') then
					if (rows_per_char(3) = '1') then
						vsync_pos <= std_logic_vector(to_unsigned(53,10));
					else
						vsync_pos <= std_logic_vector(to_unsigned(78,10));
					end if;
				end if;
			when x"0a" =>
				crsr_start_scan <= CPU_D(4 downto 0);
				crsr_mode <= CPU_D(6 downto 5);
			when x"0b" => 
				crsr_end_scan <= CPU_D(4 downto 0);
			when x"0c" =>
				vid_base(14 downto 8) <= CPU_D(6 downto 0);
				vid_base(15) <= not(CPU_D(7));
			when x"0d" =>
				vid_base(7 downto 0) <= CPU_D;
			when x"0e" =>
				crsr_address(15 downto 8) <= CPU_D;
			when x"0f" =>	-- R15
				crsr_address(7 downto 0) <= CPU_D;
			when x"14" =>	-- R20
				attr_base(15 downto 8) <= CPU_D;
			when x"15" =>	-- R21
				attr_base(7 downto 0) <= CPU_D;
			when x"18" =>	-- R24
				v_extborder <= CPU_D(4);
				cblink_mode <= CPU_D(5);
				mode_rev <= CPU_D(6);
			when x"19" =>	-- R25
				h_shift <= CPU_D(3 downto 0);
				h_extborder <= CPU_D(4);
				mode_attrib <= CPU_D(6);
				mode_bitmap <= CPU_D(7);
			when x"1a" => 	-- R26
				col_fg <= CPU_D(7 downto 4);
				col_bg0 <= CPU_D(3 downto 0);
			when x"1c" => 	-- R28
				crom_base <= CPU_D;
			when x"1d" => 	-- R29
				uline_scan <= CPU_D(4 downto 0);
				
			when x"27" =>	-- R39
				mode_extended <= CPU_D(2);
				dispen <= CPU_D(4);
				mode_upet <= CPU_D(7);
			when x"28" => 	-- R40
				col_bg1 <= CPU_D(3 downto 0);
				col_bg2 <= CPU_D(7 downto 4);
			when x"29" =>	-- R41
				col_border <= CPU_D(3 downto 0);
			when x"2c" =>	-- R44
				-- horizontal sync
				hsync_pos(6 downto 0) <= CPU_D(6 downto 0);
			when others =>
				null;
			end case;
		end if;
	end process;

	readreg: process(crtc_rwb, crtc_sel, crtc_rs, crtc_reg, reset) 
	begin
		if (reset = '1') then
			vd_out <= (others => '0');
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
						vd_out(6 downto 0) <= clines_per_screen;
					when x"09" =>
						vd_out(3) <= rows_per_char(3);
						--rows_per_char <= CPU_D(3 downto 0);
					when x"0a" =>
						vd_out(4 downto 0) <= crsr_start_scan;
						vd_out(6 downto 5) <= crsr_mode;
					when x"0b" =>
						vd_out(4 downto 0) <= crsr_end_scan;
					when x"0c" =>
						vd_out(6 downto 0) <= vid_base(14 downto 8);
						vd_out(7) <= not(vid_base(15));
					when x"0d" =>
						vd_out <= vid_base(7 downto 0);
					when x"0e" =>
						vd_out <= crsr_address(15 downto 8);
					when x"0f" =>	-- R15
						vd_out <= crsr_address(7 downto 0);
					when x"14" =>	-- R20
						vd_out <= attr_base(15 downto 8);
					when x"15" =>	-- R21
						vd_out <= attr_base(7 downto 0);
					when x"18" =>	-- R24
						vd_out(5) <= cblink_mode;
						vd_out(6) <= mode_rev;
					when x"19" =>	-- R25
						vd_out(6) <= mode_attrib;
						vd_out(7) <= mode_bitmap;
					when x"1a" => 	-- R26
						vd_out(7 downto 4) <= col_fg;
						vd_out(3 downto 0) <= col_bg0;
					when x"1c" => 	-- R28
						vd_out <= crom_base;
					when x"1d" => 	-- R29
						vd_out(4 downto 0) <= uline_scan;
						
					when x"27" =>	-- R39
						vd_out(2) <= mode_extended;
						vd_out(4) <= dispen;
						vd_out(7) <= mode_upet;
					when x"28" => 	-- R40
						vd_out(3 downto 0) <= col_bg1;
						vd_out(7 downto 4) <= col_bg2;
					when x"29" =>	-- R41
						vd_out(3 downto 0) <= col_border;
					when x"2c" =>	-- R44
						vd_out(5 downto 0) <= hsync_pos(6 downto 1);
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

