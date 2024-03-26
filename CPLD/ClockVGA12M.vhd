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
	   
	   memclk: out std_logic;	-- memory access clock signal
		cp00: out std_logic;		-- clk enable on qclk falling when memclk is in the middle of low
		cp01: out std_logic;		-- clk enable on qclk falling when memclk is going low to high
		cp10: out std_logic;		-- clk enable on qclk falling when memclk is going high to low
		cp11: out std_logic;		-- clk enable on qclk falling when memclk is in the middle of high
		
	   clk1m : out std_logic;	-- trigger CPU access @ 1MHz
	   clk2m	: out std_logic;	-- trigger CPU access @ 2MHz
	   clk4m	: out std_logic;	-- trigger CPU access @ 4MHz
	   
	   -- CS/A out bus timing
	   c8phi2: out std_logic;
	   c2phi2: out std_logic;
	   cphi2	: out std_logic;
	   chold	: out std_logic;	-- high for duration of Addr hold time
	   csetup: out std_logic;
	   
	   dotclk: out std_logic_vector(3 downto 0) -- 1x, 1/2, 1/4, 1/8 pixel clock for video
	 );
	 attribute maxskew: string;
	 attribute maxdelay: string;
	 attribute maxskew of dotclk : signal is "4 ns";
	 attribute maxdelay of dotclk : signal is "4 ns";
	 attribute maxskew of memclk : signal is "4 ns";
	 attribute maxdelay of memclk : signal is "4 ns";
end Clock;

architecture Behavioral of Clock is

	signal clk_cnt : std_logic_vector(5 downto 0);
	signal dotclk_int: std_logic_vector(3 downto 0);
	
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
		elsif rising_edge(qclk) then
			if (clk_cnt = "101111") then
				clk_cnt <= (others => '0');
			else
				clk_cnt <= clk_cnt + 1;
			end if;
			
			cp00 <= '0';
			cp01 <= '0';
			cp10 <= '0';
			cp11 <= '0';
			-- clock enable phases for memclk [dotclk(1)] low to high (cp01) 
			-- and high to low (cp10) transition or in the middle of memclk phases
			-- (cp00 when memclk is low, cp11 when memclk is high)
			-- when qclk is falling
			if (dotclk_int(1 downto 0) = "00") then
				cp00 <= '1';
			end if;
			if (dotclk_int(1 downto 0) = "01") then
				cp01 <= '1';
			end if;
			if (dotclk_int(1 downto 0) = "11") then
				cp10 <= '1';
			end if;
			if (dotclk_int(1 downto 0) = "10") then
				cp11 <= '1';
			end if;
			
		end if;
	end process;
	
	-- We have 16 pixels with 40ns each (at 80 cols). 
	-- We run the CPU with 80ns clock cycle, i.e. 12.5 MHz
	out_p: process(qclk, reset, clk_cnt, dotclk_int)
	begin
		if (reset = '1') then
--			memclk <= '0';

--			c8phi2 <= '0';
--			c2phi2 <= '0';
--			cphi2 <= '0';
--			chold <= '0';
--			csetup <= '0';
		elsif (falling_edge(qclk)) then

			-- memory clock (12.5MHz)
			--memclk <= clk_cnt(1);
						
			-- CS/A bus clocks (phi2, 2phi2, 8phi2)
			-- which are 1.04MHz, 2.1MHz and 8MHz 
			-- in a phase locked setup
			-- clk_cnt(1) = memclk, clk1/2/4m sampled at falling edge of memclk, for one memclk
			case (clk_cnt) is
			when "000000" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0'; 
			when "000001" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000010" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000011" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000100" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000101" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000110" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "000111" =>  cphi2 <= '0';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '1';
			when "001000" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '1';
			when "001001" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001010" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001011" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001100" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001101" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001110" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "001111" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';

			when "010000" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "010001" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "010010" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "010011" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '1'; clk4m <= '1';
			when "010100" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '1'; clk4m <= '1';
			when "010101" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "010110" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "010111" =>  cphi2 <= '0';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011000" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011001" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011010" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011011" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011100" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011101" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011110" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "011111" =>  cphi2 <= '1';	c2phi2 <= '1';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '1';

			when "100000" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '1';
			when "100001" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100010" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100011" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100100" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100101" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100110" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "100111" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101000" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101001" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101010" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101011" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '1'; clk2m <= '1'; clk4m <= '1';
			when "101100" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '0'; clk1m <= '1'; clk2m <= '1'; clk4m <= '1';
			when "101101" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101110" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';
			when "101111" =>  cphi2 <= '1';	c2phi2 <= '0';	c8phi2 <= '1'; clk1m <= '0'; clk2m <= '0'; clk4m <= '0';

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
				or 
				(clk_cnt(5 downto 0) = "000000")
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
			dotclk_int <= clk_cnt (3 downto 0);
		end if;
		memclk <= dotclk_int(1);
		dotclk <= dotclk_int;
	end process;
	
end Behavioral;

