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
	   crtc_rs : in std_logic;
	   crtc_rwb : in std_logic;
	   
	   qclk: in std_logic;		-- Q clock (50MHz)
		dotclk: in std_logic_vector(3 downto 0);	-- 25Mhz
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
	
	signal mode_rev: std_logic;			-- r24.6, reverse the screen
	
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

	---
	signal cblink_mode: std_logic;			-- character blink mode, R24.5
	signal cblink_active: std_logic;		-- when set, character blinking is active
	signal is_reverse : std_logic;			-- when set, invert the pixels; made from blink, underline and cursor logic
	signal is_underline : std_logic;			-- when set, underline is active in SR
	
	-- 1 bit slot counter to enable 40 column
	signal in_slot: std_logic;
	
	-- mode
	signal is_80: std_logic;
	
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now
	signal crtc_reg: std_logic_vector(7 downto 0);
	
	signal rows_per_char: std_logic_vector(3 downto 0);
	signal slots_per_line: std_logic_vector(6 downto 0);
	signal clines_per_screen: std_logic_vector(6 downto 0);

	signal vpage : std_logic_vector(7 downto 0);
	signal vpagelo : std_logic_vector(7 downto 0);

	-- count "slots", i.e. 8pixels
	-- 
	-- one slot may need none (out of screen), one (hires), or two (character display) 
	-- memory accesses. At 16MHz pixel, a slot has four potential memory accesses at 8MHz
	-- up to 127 slots/line
	signal slot_cnt : std_logic_vector (6 downto 0) := (others => '0');
	-- count raster lines
	signal rline_cnt : std_logic_vector (9 downto 0) := (others => '0');
	-- count raster lines per character lines
	signal rcline_cnt : std_logic_vector (3 downto 0) := (others => '0');
	-- count character lines
	signal cline_cnt : std_logic_vector (6 downto 0) := (others => '0');
	
	-- computed video memory address
	signal vid_addr : std_logic_vector (13 downto 0) := (others => '0');
	-- computed video memory address at start of line (to re-load chars each raster line)
	signal vid_addr_hold : std_logic_vector(13 downto 0) := (others => '0');
	
	-- replacement for csa_ultracpu IC7 when holding character data for the crom fetch
	signal char_index_buf : std_logic_vector(7 downto 0);
	signal char_buf_ld : std_logic;
	signal attr_buf : std_logic_vector(7 downto 0);
	signal attr_ld : std_logic;
	-- replacements for shift register
	signal sr : std_logic_vector(7 downto 0);
	signal nsrload : std_logic;
	signal srclk: std_logic;
	signal dena_int : std_logic;
	signal sr_attr: std_logic_vector(7 downto 0); -- the attributes for the bitmap in sr

	-- geo signals
	--
	-- pulse at end of raster line; falling slotclk
	signal last_slot_of_line : std_logic := '0'; 
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
	signal a_out : std_logic_vector (15 downto 0);
	signal chr_window : std_logic;
	signal pxl_window : std_logic;
	signal attr_window : std_logic;
	signal slotclk : std_logic;
	
	-- convenience
	signal chr40 : std_logic;
	signal chr80 : std_logic;
	signal pxl40 : std_logic;
	signal pxl80 : std_logic;
	signal attr40 : std_logic;
	signal attr80 : std_logic;

	signal chr_fetch_int : std_logic;
	signal crom_fetch_int: std_logic;
	signal pxl_fetch_int : std_logic;
	signal attr_fetch_int : std_logic;
	
	signal mem_addr : std_logic;
	
	signal next_row : std_logic;
	
	function To_Std_Logic(L: BOOLEAN) return std_ulogic is
	begin
		if L then
			return('1');
		else
			return('0');
		end if;
	end function To_Std_Logic;
	
begin

	slotclk <= dotclk(3);
	
	windows_p: process(dotclk)
	begin
			chr_window <= '0';
			pxl_window <= '0';
			attr_window <= '0';

			-- access windows for pixel data, character data, or chr ROM
			if (dotclk(3 downto 2) = "01") then
				chr_window <= '1';
			end if;
			
			-- note: attributes must be loaded before character set, as attributes contain alternate character bit
			if (dotclk(3 downto 2) = "11") then
				attr_window <= '1';
			end if;

			if (dotclk(3 downto 2) = "10") then
				pxl_window <= '1';
			end if;			
	end process;
	
	in_slot_cnt_p: process(in_slot, slotclk, reset)
	begin
		if (reset = '1') then
			in_slot <= '0';
		elsif (falling_edge(slotclk)) then
			in_slot <= slot_cnt(0);
		end if;
	end process;
	
	-- access indicators
	--
	-- pxl40/chr40 are used in both 40 and 80 col mode
	chr40 <= chr_window  and in_slot 	and not(mode_bitmap)		and is_80;
	pxl40 <= pxl_window  and in_slot										and is_80;
	attr40 <= attr_window and in_slot									and is_80;
	chr80 <= chr_window  and not(in_slot) 	and not(mode_bitmap);
	pxl80 <= pxl_window  and not(in_slot);
	attr80 <= attr_window and not(in_slot);

	-- do we fetch character index?
	-- not hires, and first cycle in streak
	chr_fetch_int <= is_enable and (chr40 or chr80) and (interlace or not(rline_cnt(0))) ;

	-- col fetch
	attr_fetch_int <= is_enable and (attr40 or attr80) and (interlace or not(rline_cnt(0)));
	
	-- dot fetch
	pxl_fetch_int <= is_enable and (pxl40 or pxl80) and (interlace or not(rline_cnt(0)));
	crom_fetch_int <= pxl_fetch_int and not(mode_bitmap);

	-- video access?
	vid_fetch <= chr_fetch_int or pxl_fetch_int or attr_fetch_int or crom_fetch_int;

	-- when do we use plain vid_addr to fetch?
	mem_addr <= mode_bitmap or chr_fetch_int or attr_fetch_int;
	
	-----------------------------------------------------------------------------
	-- horizontal geometry calculation

	-- note: needs to be synchronized, as otherwise bouncing would appear from 
	-- different signal path lengths in different bits, resulting in line counter running
	-- twice the speed it should.
	CharCnt: process(slotclk, last_slot_of_line, slot_cnt, reset)
	begin
		if (reset = '1') then
			slot_cnt <= (others => '0');
		elsif (rising_edge(slotclk)) then
			if (last_slot_of_line = '1') then
				slot_cnt <= (others => '0');
			else
				slot_cnt <= slot_cnt + 1;
			end if;
		end if;
	end process;

	SlotProx: process(slot_cnt, slotclk) 
	begin
		if (falling_edge(slotclk)) then
			-- end of line
			if(slot_cnt = 99) then
				last_slot_of_line <= '1';
			else
				last_slot_of_line <= '0';
			end if;
			
			-- sync
			if (slot_cnt >= 84 and slot_cnt < 96) then
				h_sync_int <= '1';
			else
				h_sync_int <= '0';
			end if;
			
			-- last visible slot (visible from 0 to 80,
			-- but during slot 0 SR is empty, and only fetches take place)
			if (slot_cnt = slots_per_line) then
				h_enable <= '0';
				last_vis_slot_of_line <= '1';
			elsif (slot_cnt = 0) then
				h_enable <= '1';
			else 
				last_vis_slot_of_line <= '0';
			end if;
			
		end if;
		
	end process;

	h_sync <= not(h_sync_int); -- and not(v_sync_int));
	
	-----------------------------------------------------------------------------
	-- vertical geometry calculation

	next_row <= rline_cnt(0) or is_double;

	LineCnt: process(h_sync_int, last_line_of_screen, rline_cnt, rcline_cnt, reset)
	begin
		if (reset = '1') then
			rline_cnt <= (others => '0');
			rcline_cnt <= (others => '0');
			cline_cnt <= (others => '0');
		elsif (rising_edge(h_sync_int)) then
			if (last_line_of_screen = '1') then
				rline_cnt <= (others => '0');
				rcline_cnt <= (others => '0');
				cline_cnt <= (others => '0');
			else
				rline_cnt <= rline_cnt + 1;
				
				if (last_line_of_char = '1') then
					rcline_cnt <= (others => '0');
					cline_cnt <= cline_cnt + 1;
				elsif (next_row = '1') then
					-- display each char line twice
					rcline_cnt <= rcline_cnt + 1;
				end if;
			end if;
			
			if (rows_per_char(3) = '1' or movesync = '1') then
				-- 9 pixel rows per char, i.e. 450 pixel rows used
				-- moves first displayed PET row into VGA pixel row 24
				-- last displayed PET row is VGA pixel row 473
				if (rline_cnt >= 475 and rline_cnt < 477) then
					v_sync_int <= '1';
				else
					v_sync_int <= '0';
				end if;
			else
				if (rline_cnt >= 450 and rline_cnt < 452) then
					v_sync_int <= '1';
				else
					v_sync_int <= '0';
				end if;
			end if;
		end if;
	end process;

	LineProx: process(h_sync_int)
	begin
		if (falling_edge(h_sync_int)) then
			
		    if (rows_per_char(3) = '1') then
			-- timing for 9 or more pixel rows per character
			-- end of character line
			if ((mode_bitmap = '1' or rcline_cnt = 8) and next_row = '1') then
				-- if hires, everyone
				last_line_of_char <= '1';
			else
				last_line_of_char <= '0';
			end if;

			-- venable
			v_enable <= '0';
			if (rline_cnt < 450) then	--468) then
				v_enable <= '1';
			end if;
--			if (rline_cnt >= 450) then
--				v_enable <= '1';
--			end if;
		    else
			-- timing for 8 pixel rows per character
			-- end of character line
			if ((mode_bitmap = '1' or rcline_cnt = rows_per_char) and next_row = '1') then
				-- if hires, everyone
				last_line_of_char <= '1';
			else
				last_line_of_char <= '0';
			end if;

			-- venable
			v_enable <= '0';
			if (rline_cnt < 400) then	--416) then
				v_enable <= '1';
			end if;
		end if; -- crtc_is_9rows

		    -- common for 8/9 pixel rows per char
		    
			-- end of screen
			if (rline_cnt = 524) then
				last_line_of_screen <= '1';
			else
				last_line_of_screen <= '0';
			end if;
	
		
		end if; -- rising edge...
	end process;

	v_sync <= not(v_sync_int);
	pet_vsync <= v_sync_int;
	
	-----------------------------------------------------------------------------
	-- address calculations
	
	AddrHold: process(slotclk, last_slot_of_line, last_line_of_screen, vid_addr, reset) 
	begin
		if (reset ='1') then
			vid_addr_hold <= (others => '0');
		elsif (rising_edge(slotclk)) then
			if (last_vis_slot_of_line = '1') then
				if (last_line_of_screen = '1') then
                                        vid_addr_hold(13) <= vpage(5);
                                        vid_addr_hold(12) <= vpage(4);
                                        vid_addr_hold(11 downto 8) <= vpage(3 downto 0);
                                        vid_addr_hold(7 downto 0) <= vpagelo;
				else
					if (last_line_of_char = '1') then
						vid_addr_hold <= vid_addr;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	AddrCnt: process(last_slot_of_line, last_line_of_screen, vid_addr, vid_addr_hold, is_80, in_slot, slotclk, reset)
	begin
		if (reset = '1') then
			vid_addr <= (others => '0');
		elsif (falling_edge(slotclk)) then
			if (last_line_of_screen = '1' and last_slot_of_line = '1') then
				vid_addr <= (others => '0');
				is_80 <= is_80_in;
			else
				if (last_slot_of_line = '0') then
					if (is_80 = '1' or in_slot = '1') then
						vid_addr <= vid_addr + 1;
					end if;
				else
					vid_addr <= vid_addr_hold;
				end if;
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
	
	char_buf_p: process(memclk, chr_fetch_int, VRAM_D, qclk, char_buf_ld, attr_ld, srclk, dena_int)
	begin
		if (rising_edge(qclk)) then
			-- note: char_index_buf is re-used to first load the character index, then the character pixel data
			char_buf_ld <= not(memclk) or not(chr_fetch_int or pxl_fetch_int);
			attr_ld	<= not(memclk) or not (attr_fetch_int);
		end if;
		
		if (rising_edge(char_buf_ld)) then
			char_index_buf <= VRAM_D;
		end if;

		if (rising_edge(attr_ld)) then
			attr_buf <= VRAM_D;
		end if;
		
		-- when do I really need to load the pixel SR?
		if (falling_edge(qclk)) then
			nsrload	<= not(memclk) or not (attr_fetch_int);
		end if;

		if (rising_edge(srclk)) then
			if (nsrload = '0') then
				is_reverse <= '0';
				is_underline <= '0';
				if (mode_attrib = '0') then
					-- independent from extended and bitmap
					if (crsr_addr_match = '1' and crsr_active = '1') then
						is_reverse <= not(is_reverse);
					end if;	
				elsif (mode_extended = '0') then
					if (attr_buf(6) = '1' 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1')) then
						is_reverse <= not(is_reverse);
					end if;
					if (attr_buf(5) = '1' and uline_active = '1') then
						is_underline <= '1';
					end if;
				else -- extended == 1			
					if (attr_buf(5) = '0' and ((attr_buf(6) = '1') 			-- reverse attribute
						xor (attr_buf(4) = '1' and			-- blink
							cblink_active = '1'))) then
						is_reverse <= not(is_reverse);
					end if;
				end if;
				
				if (is_underline = '1') then
						sr <= x"ff";
				else 						
						sr <= char_index_buf;
				end if;
				
				if (is_reverse = '1') then
					sr <= not(char_index_buf);
				end if;
			else
				sr(7 downto 1) <= sr(6 downto 0);
				sr(0) <= '1';
			end if;
		end if;		
	end process;

	attr_p: process(srclk)
	begin
		if (falling_edge(srclk)) then
			sr_attr <= attr_buf;
		end if;
	end process;

	srclk <= not(dotclk(0)) when is_80_in = '1' else not(dotclk(1));

	vid_out_p: process (dotclk(0))
	begin
		if (dena_int = '0') then
			vid_out <= (others => '0');
		elsif (falling_edge(dotclk(0))) then
			if (mode_extended = '0' and mode_attrib = '0') then
				if sr(7) = '0' then
					vid_out <= col_bg0;
				else
					vid_out <= col_fg;
				end if;
			elsif (mode_extended = '0' and mode_attrib = '1') then
				if sr(7) = '0' then
					vid_out <= col_bg0;
				else
					vid_out <= attr_buf(3 downto 0);
				end if;
			elsif (mode_extended = '1' and mode_attrib = '0') then
				if sr(7) = '0' then
					vid_out <= attr_buf(7 downto 4);
				else
					vid_out <= attr_buf(3 downto 0);
				end if;
			else
				if (sr(7) = '0') then
					vid_out <= attr_buf(7 downto 4);
				else 
					vid_out <= attr_buf(3 downto 0);
				end if;
			end if;
		end if;
	end process;
	
	-----------------------------------------------------------------------------
	-- mem_addr = hires fetch or chr fetch (i.e. NOT charrom pxl fetch)
	
	a_out(3 downto 0) <= vid_addr(3 downto 0) when mem_addr ='1' else 
				rcline_cnt;
	a_out(11 downto 4) <= vid_addr(11 downto 4) when mem_addr = '1' else 
				char_index_buf(7 downto 0);
	a_out(12) <= vid_addr(12) 	when mem_addr ='1' else
				is_graph;
	a_out(13) 	<= vid_addr(13) 	when mem_addr ='1' else
		  vpage(6);	-- charrom
        a_out(14)       <= vpage(6) when mode_bitmap = '1' else        -- hires
                                vpage(7) when crom_fetch_int = '1' else -- charrom
                                '0'	 when chr_fetch_int = '1' else  -- character data
				'1';					-- color data
        a_out(15)       <= vpage(7) when mode_bitmap = '1' else        -- hires
                                '0' when crom_fetch_int = '1' else           -- charrom
                                '1';            -- $8000 for PET character data

	A <= a_out;
	
	-----------------------------------------------------------------------------
	-- output sr control

	en_p: process(nsrload)
	begin
		-- sr_load changes on falling edge of qclk
		-- sr_load_d changes on rising edge of qclk
		-- in_slot changes at falling edge of slotclk, which itself changes on falling edge of qclk
		if (rising_edge(nsrload)
			and (in_slot = '1')) then
			enable <= h_enable and v_enable
				and (interlace or not(rline_cnt(0)));
		end if;
	end process;

	-- without this delay the char behind a line may slightly bleed through
	-- for just a couple of ns, but this still irritated my monitor's auto-sync
	-- so it would not correctly detect 640x480
--	en_p2: process(qclk, reset)
--	begin
--		if (reset = '1') then
--			dena_int <= '0';
--		elsif (rising_edge(qclk)) then
--			dena_int <= enable;
--		end if;
--	end process;

	dena_int <= enable;
	
	--------------------------------------------
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now

	dbg_out <= '0';
	
	regfile: process(memclk, CPU_D, crtc_sel, crtc_rs, reset) 
	begin
		if (reset = '1') then
			crtc_reg <= (others => '0');
		elsif (falling_edge(memclk) 
				and crtc_sel = '1' 
				and crtc_rs='0'
				and crtc_rwb = '0'
				) then
			
			crtc_reg(5 downto 0) <= CPU_D(5 downto 0);
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
			crsr_mode <= (others => '0');
			crsr_address <= (others => '0');
			rows_per_char <= X"7";
			slots_per_line <= "1010000";	-- 80
			clines_per_screen <= "0011001";	-- 25
			vpage <= x"10"; -- inverted for PET
			vpagelo <= (others => '0');
			col_fg <= "1111";
			col_bg0 <= "0000";
			col_bg1 <= "0000";
			col_bg2 <= "0000";
			col_border <= "0111";
			uline_scan <= (others => '0');
		elsif (falling_edge(phi2) 
				and crtc_sel = '1' 
				and crtc_rs='1' 
				and crtc_rwb = '0'
				) then
			case (crtc_reg) is
			when x"01" =>
				-- note: value written is doubled (as in the PET for 80 columns)
				slots_per_line(6 downto 1) <= CPU_D(5 downto 0);
			when x"06" => 
				clines_per_screen <= CPU_D(6 downto 0);
			when x"09" =>
				rows_per_char(3) <= CPU_D(3);
				--rows_per_char <= CPU_D(3 downto 0);
			when x"0a" =>
				crsr_start_scan <= CPU_D(4 downto 0);
				crsr_mode <= CPU_D(6 downto 5);
			when x"0b" => 
				crsr_end_scan <= CPU_D(4 downto 0);
			when x"0c" =>
				vpage <= CPU_D;
			when x"0d" =>
				vpagelo <= CPU_D;
			when x"0e" =>
				crsr_address(15 downto 8) <= CPU_D;
			when x"0f" =>	-- R15
				crsr_address(7 downto 0) <= CPU_D;
			when x"18" =>	-- R24
				cblink_mode <= CPU_D(5);
				mode_rev <= CPU_D(6);
			when x"19" =>	-- R25
				mode_attrib <= CPU_D(6);
				mode_bitmap <= CPU_D(7);
			when x"1a" => 	-- R26
				col_fg <= CPU_D(7 downto 4);
				col_bg0 <= CPU_D(3 downto 0);
			when x"1d" => 	-- R29
				uline_scan <= CPU_D(4 downto 0);
			when x"21" =>	-- R33
				mode_extended <= CPU_D(2);
			when x"22" => 	-- R34
				col_bg1 <= CPU_D(3 downto 0);
				col_bg2 <= CPU_D(7 downto 4);
			when x"23" =>	-- R35
				col_border <= CPU_D(3 downto 0);
			when others =>
				null;
			end case;
		end if;
	end process;
	
	--- blinker

	blink_p: process(v_sync_int)
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

