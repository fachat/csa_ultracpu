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
						vh_cnt <= (others => '0');
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
			
			if (v_state = '0' and vh_cnt = 78) then -- vsync_pos) then
				v_next <= '1';
			end if;
			
			if (v_state = '1') then
				if (rcline_cnt_int = 7 and next_row = '1') then -- rows_per_char) then
				
					is_last_row_of_char_int <= '1';
					if (vh_cnt = 25) then -- clines_per_screen) then
						is_last_row_of_screen_int <= '1';
					end if;
				end if;
			end if;
					
		end if;
	end process;

	rcline_cnt <= rcline_cnt_int;
	rline_cnt0 <= rline_cnt0_int;
	
	is_last_row_of_char <= is_last_row_of_char_int;
	is_last_row_of_screen <= is_last_row_of_screen_int;
	
	is_border <= is_border_int;
	
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

end Behavioral;

