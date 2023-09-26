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

entity VBorder is
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

end VBorder;

architecture Behavioral of VBorder is

	-- signal defs
	signal v_state: std_logic;
	signal v_next: std_logic;
		
	signal is_border_int: std_logic;
	signal is_last_row_of_char_int: std_logic;
	signal is_last_row_of_screen_int: std_logic;
	signal is_first_row_of_screen_int: std_logic;
	
	signal vh_cnt : std_logic_vector (6 downto 0) := (others => '0');
	signal rcline_cnt_int: std_logic_vector(3 downto 0);
	signal rline_cnt0_int: std_logic;

	signal next_row: std_logic;
	
begin

	next_row <= rline_cnt0_int or is_double;
	
	RowCnt: process(h_sync, vh_cnt, reset)
	begin
		if (reset = '1') then
			v_state <= '0';
			rcline_cnt_int <= (others => '0');
			vh_cnt <= (others => '0');
		elsif (rising_edge(h_sync)) then
		
			if (v_zero = '1') then
				vh_cnt <= (others => '0');
				rcline_cnt_int <= (others => '0');
				v_state <= '0';
				
			else 
			
				rline_cnt0_int <= not(rline_cnt0_int);
				
				if (v_state = '0') then
				
					if (v_next = '0') then
						vh_cnt <= vh_cnt + 1;
					else -- v_next = '1'
						vh_cnt <= std_logic_vector(to_unsigned(1,10)); --(others => '0');
						is_border_int <= '0';
						rline_cnt0_int <= '0';
						rcline_cnt_int <= (others => '0');
						v_state <= '1';
					end if;
					
				else -- v_state = '1'
					if (is_last_row_of_char_int = '1') then
					
						if (is_last_row_of_screen_int = '1') then
							is_border_int <= '1';
						end if;
						
						rcline_cnt_int <= (others => '0');
						vh_cnt <= vh_cnt + 1;
						
					elsif (next_row = '1') then
						-- display each char line twice
						rcline_cnt_int <= rcline_cnt_int + 1;
					end if;
				end if;
			end if;			
		end if;
	end process;

	State: process (vh_cnt, v_state, vsync_pos, h_sync)
	begin		
		if (falling_edge(h_sync)) then
			v_next <= '0';

			is_last_row_of_char_int <= '0';
			is_last_row_of_screen_int <= '0';
			is_first_row_of_screen_int <= '0';
			
			if (v_state = '0' and vh_cnt = vsync_pos) then -- vsync_pos) then
				v_next <= '1';
				is_first_row_of_screen_int <= '1';
			end if;
			
			if (v_state = '1') then
				if (rcline_cnt_int = rows_per_char and next_row = '1') then -- rows_per_char
				
					is_last_row_of_char_int <= '1';
					if (vh_cnt = clines_per_screen) then -- clines_per_screen) then
						is_last_row_of_screen_int <= '1';
					end if;
				end if;
			end if;
					
		end if;
	end process;

	rcline_cnt <= rcline_cnt_int;
	rline_cnt0 <= rline_cnt0_int;
	
	is_last_row_of_char <= is_last_row_of_char_int;
	is_last_row_of_screen <= is_first_row_of_screen_int;
	
	is_border <= is_border_int;
	

end Behavioral;
