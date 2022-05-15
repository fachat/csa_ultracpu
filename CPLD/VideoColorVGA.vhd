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
	   phi2: in std_logic;
	   
	   dena   : out std_logic;	-- display enable
           v_sync : out  STD_LOGIC;
           h_sync : out  STD_LOGIC;
	   pet_vsync: out std_logic;	-- for the PET screen interrupt

	   is_enable: in std_logic;
           is_80_in : in std_logic;	-- is 80 column mode?
	   is_hires : in std_logic;	-- is hires mode?
	   is_graph : in std_logic;	-- graphic mode (from PET I/O)
	   is_double: in std_logic;
	   interlace: in std_logic;
	   movesync:  in std_logic;
	   
	   crtc_sel : in std_logic;
	   crtc_rs : in std_logic;
	   crtc_rwb : in std_logic;
	   
	   qclk: in std_logic;		-- Q clock
           memclk : in STD_LOGIC;	-- system clock 8MHz
	   slotclk : in std_logic;
	   slot2clk : in std_logic;
	   chr_window : in std_logic;
	   pxl_window : in std_logic;
	   col_window : in std_logic;
	   
	   chr_fetch : out std_logic;
	   crom_fetch: out std_logic;
	   pxl_fetch : out std_logic;
	   col_fetch : out std_logic;

	   sr_load : in std_logic;
	   
           is_vid : out STD_LOGIC;	-- true during video access phase (all, character, chrom, and hires pixel data)
	   
	   dbg_out : out std_logic;
	   
	   reset : in std_logic
	   );
end Video;

architecture Behavioral of Video is

	type T_REGNO is (RNONE, R9, R12);
	
	-- 1 bit slot counter to enable 40 column
	signal in_slot: std_logic;
	
	-- mode
	signal is_80: std_logic;
	signal is_hires_int: std_logic;
	
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now
	signal crtc_reg: T_REGNO;
	
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
	
	-- convenience
	signal chr40 : std_logic;
	signal chr80 : std_logic;
	signal pxl40 : std_logic;
	signal pxl80 : std_logic;
	signal col40 : std_logic;
	signal col80 : std_logic;

	signal chr_fetch_int : std_logic;
	signal crom_fetch_int: std_logic;
	signal pxl_fetch_int : std_logic;
	signal col_fetch_int : std_logic;
	
	signal sr_load_d : std_logic;
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

	in_slot_cnt_p: process(in_slot, slotclk, reset)
	begin
		if (reset = '1') then
			in_slot <= '0';
		elsif (falling_edge(slotclk)) then
			in_slot <= slot_cnt(0);
		end if;
	end process;
--	in_slot <= slot2clk;
	
	is_hires_int <= is_hires;
	
	-- access indicators
	--
	-- pxl40/chr40 are used in both 40 and 80 col mode
	-- col40/80 must be active at last cycle before loading the pixel shift register
	-- 	as the pixel SR is directly loaded from the data bus
	chr40 <= chr_window and in_slot 	and not(is_hires_int)	and is_80;
	pxl40 <= pxl_window and in_slot					and is_80;
	col40 <= col_window and in_slot					and is_80;
	chr80 <= chr_window and not(in_slot) 	and not(is_hires_int);
	pxl80 <= pxl_window and not(in_slot);
	col80 <= col_window and not(in_slot);


	-- do we fetch character index?
	-- not hires, and first cycle in streak
	chr_fetch_int <= is_enable and (chr40 or chr80) and (interlace or not(rline_cnt(0))) ;

	-- dot fetch
	col_fetch_int <= is_enable and (col40 or col80) and (interlace or not(rline_cnt(0)));
	
	-- dot fetch
	pxl_fetch_int <= is_enable and (pxl40 or pxl80) and (interlace or not(rline_cnt(0)));
	crom_fetch_int <= pxl_fetch_int and not(is_hires);

		
	chr_fetch <= chr_fetch_int;
	pxl_fetch <= pxl_fetch_int;
	col_fetch <= col_fetch_int;

	-- pull that in front, so address output enable on IC7 is early enough
	crom_fetch<= crom_fetch_int;
	
	-- video access?
	is_vid <= chr_fetch_int or pxl_fetch_int or col_fetch_int;

	-- when do we use plain vid_addr to fetch?
	mem_addr <= is_hires_int or chr_fetch_int or col_fetch_int;
	
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
			if (slot_cnt >= 83 and slot_cnt < 95) then
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
			if ((is_hires_int = '1' or rcline_cnt = 8) and next_row = '1') then
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
			if ((is_hires_int = '1' or rcline_cnt = rows_per_char) and next_row = '1') then
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

	-----------------------------------------------------------------------------
	-- address output
	
	-- mem_addr = hires fetch or chr fetch (i.e. NOT charrom pxl fetch)
	
	a_out(3 downto 0) <= vid_addr(3 downto 0) when mem_addr ='1' else 
				rcline_cnt;
	a_out(11 downto 4) <= vid_addr(11 downto 4) when mem_addr = '1' else 
				"ZZZZZZZZ";
	a_out(12) 	<= vid_addr(12) 	when mem_addr ='1' else
				is_graph;
	a_out(13) 	<= vid_addr(13) 	when mem_addr ='1' else
				vpage(6);	-- charrom
        a_out(14)       <= vpage(6) when is_hires_int = '1' else        -- hires
                                vpage(7) when crom_fetch_int = '1' else -- charrom
                                '0'	 when chr_fetch_int = '1' else  -- character data
				'1';					-- color data
        a_out(15)       <= vpage(7) when is_hires_int = '1' else        -- hires
                                '0' when crom_fetch_int = '1' else           -- charrom
                                '1';            -- $8000 for PET character data

	A <= a_out;
	
	-----------------------------------------------------------------------------
	-- output sr control

	en_p: process(sr_load_d)
	begin
		-- sr_load changes on falling edge of qclk
		-- sr_load_d changes on rising edge of qclk
		-- in_slot changes at falling edge of slotclk, which itself changes on falling edge of qclk
		if (rising_edge(sr_load_d)
			and (in_slot = '1')) then
			enable <= h_enable and v_enable
				and (interlace or not(rline_cnt(0)));
		end if;
	end process;

	-- without this delay the char behind a line may slightly bleed through
	-- for just a couple of ns, but this still irritated my monitor's auto-sync
	-- so it would not correctly detect 640x480
	en_p2: process(qclk, reset)
	begin
		if (reset = '1') then
			dena <= '0';
		elsif (rising_edge(qclk)) then
			dena <= enable;
		end if;
	end process;

	en_p3: process(qclk, reset)
	begin
		if (reset = '1') then
			sr_load_d <= '0';
		elsif (rising_edge(qclk)) then
			sr_load_d <= sr_load;
		end if;
	end process;

	--------------------------------------------
	-- crtc register emulation
	-- only 8/9 rows per char are emulated right now

	dbg_out <= '0';
	
	regfile: process(memclk, CPU_D, crtc_sel, crtc_rs, reset) 
	begin
		if (reset = '1') then
			crtc_reg <= RNONE;
		elsif (falling_edge(memclk) 
				and crtc_sel = '1' 
				and crtc_rs='0'
				and crtc_rwb = '0'
				) then
			
			case (CPU_D(3 downto 0)) is
--			when x"8" =>
--				crtc_reg <= R8;
			when x"9" =>
				crtc_reg <= R9;
			when x"c" =>
				crtc_reg <= R12;
--			when x"d" =>
--				crtc_reg <= R13;
			when others =>
				crtc_reg <= RNONE;
			end case;
		end if;
	end process;
	
	reg9: process(phi2, CPU_D, crtc_sel, crtc_rs, crtc_rwb, crtc_reg, reset) 
	begin
		if (reset = '1') then
			rows_per_char <= X"7";
			slots_per_line <= "1010000";	-- 80
			clines_per_screen <= "0011001";	-- 25
			vpage <= x"10"; -- inverted for PET
			vpagelo <= (others => '0');
		elsif (falling_edge(phi2) 
				and crtc_sel = '1' 
				and crtc_rs='1' 
				and crtc_rwb = '0'
				) then
			case (crtc_reg) is
--			when R1 =>
--				-- we only allow to write up to 63, to save one CPLD register
--				-- (bit 7 is constant)
--				slots_per_line(6 downto 1) <= CPU_D(5 downto 0);
--			when R6 => 
--				clines_per_screen <= CPU_D(6 downto 0);
			when R9 =>
				rows_per_char(3) <= CPU_D(3);
				--rows_per_char <= CPU_D(3 downto 0);
			when R12 =>
				vpage(1 downto 0) <= (others => '0');
				vpage(7 downto 2) <= CPU_D(7 downto 2);
--			when R13 =>
--				vpagelo <= CPU_D;
			when others =>
				null;
			end case;
		end if;
	end process;
	

end Behavioral;

