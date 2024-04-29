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
-- Horizontal border timing.
-- creates "is_border" so that border is displayed
-- creates "is_preload" to start char/attrib fetch one char slot before border starts
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

entity HBorder is
		Port (
			qclk: in std_logic;
			dotclk: in std_logic_vector(3 downto 0);
			
			-- one on last pxl before pxl addr should be zeroed
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

end HBorder;

architecture Behavioral of HBorder is

	-- signal defs
	signal h_state: std_logic;
	
	signal is_preload_int: std_logic;
	signal is_preload_int_d: std_logic;
	signal is_preload_int_dd: std_logic;

	signal is_border_int: std_logic;
	
	-- up to 127 slots/line
	signal vh_cnt : std_logic_vector (6 downto 0) := (others => '0');

begin

	CharCnt: process(qclk, dotclk, h_zero, is_preload_int, vh_cnt, reset)
	begin
		if (reset = '1') then
			vh_cnt <= (others => '0');
			h_state <= '0';
		elsif (falling_edge(qclk) and dotclk = "1111") then
			if (h_zero = '1') then
				vh_cnt <= (others => '0');
				h_state <= '0';
			elsif (is_preload_int = '1') then
				vh_cnt <= "0000001";
				h_state <= '1';
			else
				vh_cnt <= vh_cnt + 1;
			end if;
		end if;
	end process;

	Preload: process (qclk, vh_cnt, h_state, hsync_pos, dotclk)
	begin		
		if (falling_edge(qclk) and dotclk = "0000") then
			if (h_state = '0' and vh_cnt = hsync_pos) then
				is_preload_int <= '1';
			else
				is_preload_int <= '0';
			end if;
		end if;
		
		if (falling_edge(qclk) and dotclk = "1111") then
			is_preload_int_d <= is_preload_int;
			is_preload_int_dd <= is_preload_int_d;
		end if;
	end process;

	is_preload <= is_preload_int;
	
	Enable: process (qclk, dotclk, vh_cnt, is_preload_int_d, is_preload_int_dd, h_extborder, h_zero)
	begin
		
		if (h_zero = '1') then
			is_border_int <= '1';
			is_border <= '1';
		elsif (falling_edge(qclk) and dotclk = "1111") then
			is_last_vis <= '0';
			is_border <= is_border_int;
			if ((h_extborder = '0' and is_preload_int = '1') 
					or (is_preload_int_d = '1') 
--					or (is_80 = '1' and is_preload_int_d = '1') 
--					or (is_80 = '0' and is_preload_int_d = '1')
					) then
					is_border_int <= '0';
			elsif (h_state = '1') then
					if (vh_cnt = slots_per_line) then
							is_last_vis <= '1';
							is_border_int <= '1';
							if (h_extborder = '1') then
									is_border <= '1';
							end if;
					end if;
					if (is_80 = '0' and h_extborder = '1' and vh_cnt = slots_per_line -1) then
							is_border <= '1';
					end if;
			end if;
			
		end if;
	end process;
	
	
	in_slot_cnt_p: process(qclk, vh_cnt, reset)
	begin
		if (reset = '1') then
			in_slot <= '0';
		elsif (falling_edge(qclk)) then
			in_slot <= not(vh_cnt(0));
		end if;
	end process;


end Behavioral;

