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
-- This module creates the VGA timing, as background for the video output
-- This timing is completely determined by the VGA mode used
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

entity Canvas is
    Port ( 
	   qclk: in std_logic;		-- Q clock (50MHz)
	   dotclk: in std_logic_vector(3 downto 0);	-- 25Mhz, 1/2, 1/4, 1/8, 1/16

	   v_sync : out  STD_LOGIC;
      h_sync : out  STD_LOGIC;

		h_zero : out std_logic;
    	h_enable : out std_logic;
    	v_enable : out std_logic;

	   x_addr: out std_logic_vector(9 downto 0);	-- x coordinate in pixels
      y_addr: out std_logic_vector(9 downto 0);	-- y coordinate in rasterlines

	   reset : in std_logic
	   );
end Canvas;

architecture Behavioral of Canvas is


	-- 640x480@60 Hz

	-- all values in pixels
	-- note: cummulative, starting with back porch
	-- reason: can be used as sprite coordinate, with full pixel being inside left/upper border at 0/0
	constant h_back_porch: std_logic_vector(9 downto 0) 	:= std_logic_vector(to_unsigned((48  						-8)/8	-1, 10));
	constant h_width: std_logic_vector(9 downto 0)			:= std_logic_vector(to_unsigned((48 + 640	 				-8)/8	-1, 10));
	constant h_front_porch: std_logic_vector(9 downto 0)	:= std_logic_vector(to_unsigned((48 + 640 + 16 			)/8		-1, 10));
	constant h_sync_width: std_logic_vector(9 downto 0)	:= std_logic_vector(to_unsigned((48 + 640 + 16 + 96 	)/8		-1, 10));
	-- zero for pixel coordinates is 80 pixels left of default borders
	constant h_zero_pos: std_logic_vector(9 downto 0)		:= std_logic_vector(to_unsigned((48 + 640 + 16 + 96 - (80-48))	-2, 10));

	-- all values in rasterlines
	constant v_back_porch: std_logic_vector(9 downto 0)	:=std_logic_vector(to_unsigned(33							-1, 10));
	constant v_width: std_logic_vector(9 downto 0)			:=std_logic_vector(to_unsigned(33 + 480					-1, 10));
	constant v_front_porch: std_logic_vector(9 downto 0)	:=std_logic_vector(to_unsigned(33 + 480 + 10				-1, 10));
	constant v_sync_width: std_logic_vector(9 downto 0)	:=std_logic_vector(to_unsigned(33 + 480 + 10 + 2		-1, 10));

	-- runtime counters

	-- states: 00 = back p, 01 = data, 02 = front p, 03 = sync
	signal h_state: std_logic_vector(1 downto 0);	
	signal v_state: std_logic_vector(1 downto 0);

	-- limit reached
	signal h_limit: std_logic;
	signal v_limit: std_logic;

	-- adresses counters
	signal h_cnt: std_logic_vector(9 downto 0);
	signal v_cnt: std_logic_vector(9 downto 0);

	signal h_enable_int: std_logic;
	signal h_zero_int: std_logic;

	signal x_addr_int: std_logic_vector(9 downto 0);

begin

	-----------------------------------------------------------------------------
	-- horizontal geometry calculation

	h_cnt(2 downto 0) <= dotclk(2 downto 0);
	
	pxl: process(qclk, dotclk, h_cnt, h_limit, reset)
	begin 
		if (reset = '1') then
			h_cnt(9 downto 4) <= (others => '0');
			h_state <= "00";
			h_sync <= '0';
			h_enable_int <= '0';
		elsif (falling_edge(qclk) and dotclk(3 downto 0) = "1111") then

			if (h_limit = '1' and h_state = "11") then
				-- sync with slotcnt / memclk by setting to zero on dotclk="1110"
				h_cnt(9 downto 3) <= (others => '0');
			else
				h_cnt(9 downto 3) <= h_cnt(9 downto 3) + 1;
			end if;

			if (h_limit = '1') then
				h_state <= h_state + 1;
			end if;

			h_enable_int <= '0';
			if (h_state = "01") then
				h_enable_int <= '1';
			end if;

			h_sync <= '0';
			if (h_state = "11") then
				h_sync <= '1';
			end if;
		end if;
	end process;

	h_limit_p: process(qclk, dotclk, h_cnt, reset)
	begin 
		if (reset = '1') then
			h_limit <= '0';
		elsif (falling_edge(qclk) and dotclk(3 downto 0) = "0111") then

			h_limit <= '0';

			case h_state is
				when "00" =>	-- back porch
					if (h_cnt(9 downto 3) = h_back_porch) then
						h_limit <= '1';
					end if;
				when "01" =>	-- data
					if (h_cnt(9 downto 3) = h_width) then
						h_limit <= '1';
					end if;
				when "10" =>	-- front porch
					if (h_cnt(9 downto 3) = h_front_porch) then
						h_limit <= '1';
					end if;
				when "11" =>	-- sync
					if (h_cnt(9 downto 3) = h_sync_width) then
						h_limit <= '1';
					end if;
				when others =>
			end case;
		end if;
	end process;

	hz: process(qclk, dotclk, h_cnt, reset)
	begin 
		if (reset = '1') then
			h_zero_int <= '0';
		elsif (falling_edge(qclk) and dotclk(2 downto 0) = "110") then
			if (h_cnt(9 downto 0) = h_zero_pos) then
				h_zero_int <= '1';
			else 
				h_zero_int <= '0';
			end if;
		end if;
	end process;

	h_enable <= h_enable_int;
	h_zero <= h_zero_int;
	
	xa: process(qclk, dotclk, h_zero_int, x_addr_int)
	begin
		if (falling_edge(qclk) and dotclk(0) = '1') then
			if (h_zero_int = '1') then
				x_addr_int <= (others => '0');
			else
				x_addr_int <= x_addr_int + 1;
			end if;
		end if;
	end process;
	
	x_addr <= x_addr_int;
	--x_addr <= h_cnt;

	-----------------------------------------------------------------------------
	-- vertical geometry calculation

	rline: process(h_enable_int, dotclk, v_cnt, v_limit, reset)
	begin 
		if (reset = '1') then
			v_cnt <= (others => '0');
			v_state <= "00";
			v_sync <= '0';
			v_enable <= '0';
		elsif (falling_edge(h_enable_int)) then

			if (v_limit = '1' and v_state = "11") then
				v_cnt <= (others => '0');
			else
				v_cnt <= v_cnt + 1;
			end if;

			if (v_limit = '1') then
				v_state <= v_state + 1;
			end if;

			v_enable <= '0';
			if (v_state = "01") then
				v_enable <= '1';
			end if;

			v_sync <= '0';
			if (v_state = "11") then
				v_sync <= '1';
			end if;

			if (v_limit = '1') then
				v_state <= v_state + 1;
			end if;
		end if;
	end process;


	v_limit_p: process(h_enable_int, v_cnt, reset)
	begin 
		if (reset = '1') then
			v_limit <= '0';
		elsif (rising_edge(h_enable_int)) then

			v_limit <= '0';

			case v_state is
				when "00" =>	-- back porch
					if (v_cnt = v_back_porch) then
						v_limit <= '1';
					end if;
				when "01" =>	-- data
					if (v_cnt = v_width) then
						v_limit <= '1';
					end if;
				when "10" =>	-- front porch
					if (v_cnt = v_front_porch) then
						v_limit <= '1';
					end if;
				when "11" =>	-- sync
					if (v_cnt = v_sync_width) then
						v_limit <= '1';
					end if;
				when others =>
			end case;
		end if;
	end process;

	y_addr <= v_cnt;
	
end Behavioral;

