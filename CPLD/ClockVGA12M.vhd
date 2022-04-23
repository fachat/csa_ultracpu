----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12/30/2020 
-- Design Name: 
-- Module Name:    Clock - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- 	This implements the clock management for 
--		- 50 MHz input clock
--		- 25 MHz pixel clock output (VGA)
--		- 8 MHz memory access (slightly above due to clock shaping)
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


entity Clock is
	  Port (
	   qclk 	: in std_logic;		-- input clock
	   reset	: in std_logic;
	   
	   memclk 	: out std_logic;	-- memory access clock signal
	   
	   clk1m 	: out std_logic;	-- trigger CPU access @ 1MHz
	   clk2m	: out std_logic;	-- trigger CPU access @ 2MHz
	   clk4m	: out std_logic;	-- trigger CPU access @ 4MHz
	   
	   -- CS/A out bus timing
	   c8phi2	: out std_logic;
	   c2phi2	: out std_logic;
	   cphi2	: out std_logic;
	   chold	: out std_logic;	-- high for duration of Addr hold time
	   csetup	: out std_logic;
	   
	   dotclk	: out std_logic;	-- pixel clock for video
	   dot2clk	: out std_logic;	-- half the pixel clock
	   slotclk	: out std_logic;	-- 1 slot = 8 pixel; 
	   slot2clk	: out std_logic;	-- 1 slot = 16 pixel; 
	   cpu_window	: out std_logic;	-- 1 during CPU window on VRAM
	   chr_window	: out std_logic;	-- 1 during character fetch window
	   pxl_window	: out std_logic;	-- 1 during pixel fetch window
	   col_window	: out std_logic;	-- 1 during color load (end of slot)
	   sr_load	: out std_logic		-- load pixel SR on falling edge of dotclk, when this is set
	 );
end Clock;

architecture Behavioral of Clock is

	signal clk_cnt : std_logic_vector(5 downto 0);
	signal cpu_cnt1 : std_logic_vector(3 downto 0);
	signal memclk_int : std_logic;
	
	signal clk_cnt4 : std_logic_vector(0 downto 0);
	
	function To_Std_Logic(L: BOOLEAN) return std_ulogic is
	begin
		if L then
			return('1');
		else
			return('0');
		end if;
	end function To_Std_Logic;

begin

	-- count 48 cycles in clk_cnt
	clk_p: process(qclk, reset, clk_cnt)
	begin
		if (reset = '1') then 
			clk_cnt <= (others => '0');
			clk_cnt4 <= (others => '0');
		elsif rising_edge(qclk) then
			if (clk_cnt = "101111") then
				clk_cnt <= (others => '0');
			else
				clk_cnt <= clk_cnt + 1;
			end if;
			if (clk_cnt(3 downto 0) = "1111") then
				clk_cnt4 <= clk_cnt4 + 1;
			end if;
		end if;
	end process;
	
	-- We have 16 pixels with 40ns each (at 80 cols). 
	-- We run the CPU with 80ns clock cycle, i.e. 12.5 MHz
	out_p: process(qclk, reset, clk_cnt, memclk_int)
	begin
		if (reset = '1') then
			memclk_int <= '0';
			pxl_window <= '0';
			chr_window <= '0';
			col_window <= '0';
			sr_load <= '0';

			c8phi2 <= '0';
			c2phi2 <= '0';
			cphi2 <= '0';
			chold <= '0';
			csetup <= '0';
		elsif (falling_edge(qclk)) then
			cpu_window <= '0';
			pxl_window <= '0';
			chr_window <= '0';
			col_window <= '0';
			sr_load <= '0';

			-- memory clock (12.5MHz)
			memclk_int <= clk_cnt(1);

			if (clk_cnt(3 downto 2) = "00") then
				cpu_window <= '1';
			end if;
			
			-- access windows for pixel data, character data, or chr ROM
			if (clk_cnt(3 downto 2) = "01") then
				chr_window <= '1';
			end if;
			
			if (clk_cnt(3 downto 2) = "10") then
				pxl_window <= '1';
			end if;
			
			if (clk_cnt(3 downto 2) = "11") then
				col_window <= '1';
			end if;
			
			-- load the video shift register
			-- note: the 74HCT166 needs more than the 20ns for a 25MHz half-clock...
			-- TODO: real phase?
			if (clk_cnt(3 downto 1) = "111") then
				sr_load <= '1';
			end if;
			
			-- CS/A bus clocks (phi2, 2phi2, 8phi2)
			-- which are 1.04MHz, 2.1MHz and 8MHz 
			-- in a phase locked setup
			case (clk_cnt) is
			when "000000" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0';
			when "000001" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0';
			when "000010" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0';
			when "000011" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1';
			when "000100" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1';
			when "000101" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1';
			when "000110" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0';
			when "000111" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0';
			when "001000" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "001001" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "001010" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "001011" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "001100" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "001101" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "001110" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "001111" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';

			when "010000" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "010001" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "010010" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "010011" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "010100" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			when "010101" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "010110" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "010111" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1';
			when "011000" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0';
			when "011001" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0';
			when "011010" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0';
			when "011011" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1';
			when "011100" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1';
			when "011101" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1';
			when "011110" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0';
			when "011111" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0';

			when "100000" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "100001" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "100010" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "100011" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "100100" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "100101" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "100110" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "100111" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "101000" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "101001" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "101010" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "101011" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "101100" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0';
			when "101101" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "101110" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';
			when "101111" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1';

			when others =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0';
			end case;
			
			-- only when a CS/A bus transfer is allowed
			-- to prevent access, this signal is OR'd with phi2,
			-- so it allows falling edge only at the end of cphi2
			--
			-- memclk = clk_cnt(1), memclk_d reg'd rising qclk
			-- chold must be zero before rising edge of memclk_d before
			-- next phi2 end
			chold <= '1';
			if (	(clk_cnt(5 downto 0) = "101111")
				--(clk_cnt(5 downto 3) = "101")
				or 
				(clk_cnt(5 downto 0) = "000000")
				--(clk_cnt(5 downto 2) = "0000"
				--	and not( clk_cnt(1 downto 0) = "11" ) )
				) then
				chold <= '0';
			end if;
			
			-- only if csetup is '1', then the setup time of the CS/A bus
			-- is being kept. If csetup is zero when an access is attempted,
			-- it has to wait for the following CS/A bus cycle
			if (clk_cnt(5 downto 4) = "00") then
				csetup <= '1';
			else
				csetup <= '0';
			end if;
			
			----------------- 
			dotclk <= clk_cnt (0);
			dot2clk <= clk_cnt (1);
			slotclk <= clk_cnt (3);
			slot2clk <= clk_cnt4 (0);
		end if;
	end process;
	
	memclk <= memclk_int;

	-- count 12 qclk cycles @12 MHz, then transform into clk1m/2m/4m
	cpu_cnt1_p: process(reset, cpu_cnt1, memclk_int)
	begin
		if (reset = '1') then
			cpu_cnt1 <= "0000";
		elsif (rising_edge(memclk_int)) then	
			if (cpu_cnt1 = "1011") then
				cpu_cnt1 <= "0000";
			else
				cpu_cnt1 <= cpu_cnt1 + 1;
			end if;
		end if;
	end process;

	-- generate clk1m/2m/4m
	-- note: those are sampled at rising edge of memclk
	-- also note: these clocks are not symmetrical. 
	-- it's just 4M cycles of 12.5M length
	cpu_cnt2_p: process(qclk, reset, cpu_cnt1)
	begin
		if (reset = '1') then
			clk4m <= '0';
			clk2m <= '0';
			clk1m <= '0';
		elsif (rising_edge(qclk)) then	
			clk4m <= '0';
			clk2m <= '0';
			clk1m <= '0';
			case (cpu_cnt1) is
			when "0000" =>
				clk1m <= '1';
				clk2m <= '1';
				clk4m <= '1';
			when "0011" =>
				clk4m <= '1';
			when "0110" => 
				clk2m <= '1';
				clk4m <= '1';
			when "1001" => 
				clk4m <= '1';
			when others =>
				null;
			end case;
			
		end if;
	end process;
			
end Behavioral;

