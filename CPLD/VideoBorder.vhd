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
			qclk: in std_logic;
			dotclk: in std_logic_vector(3 downto 0);
			x_addr: in std_logic_vector(9 downto 0);    -- x coordinate in pixels

			hsync_pos: in std_logic_vector(6 downto 0);
			slots_per_line: in std_logic_vector(6 downto 0);
			h_shift: in std_logic_vector(3 downto 0);
			h_extborder: in std_logic;
			is_80: in std_logic;
			
			is_preload: out std_logic;		-- one slot before end of border
			is_border: out std_logic;			
			
			reset : in std_logic
		);

end VBorder;

architecture Behavioral of VBorder is

	-- signal defs
	signal x_state: std_logic_vector(1 downto 0);
	
begin

	hborder_p: process(qclk, dotclk, x_addr, reset)
	begin
		if (reset = '1') then
			x_state <= "00";
			is_border <= '1';
			is_preload <= '0';
		elsif (falling_edge(qclk)) then
			if (dotclk(0) = '1') then
				if (x_addr = 0) then			-- start of line
					x_state <= "00";			
				elsif ((is_80 = '0' and x_addr = 48)
						or (is_80 = '1' and x_addr = 56)) then	-- 8 pixels before border ends
					x_state <= "01";			-- pre-fetch first char
					is_preload <= '1';
				elsif (x_addr = 64) then
--				elsif (x_addr(9 downto 3) = hsync_pos-80) then	-- left border ends
					x_state <= "10";			-- display
					is_border <= '0';
					is_preload <= '0';
				elsif (x_addr = 672) then
--				elsif (x_addr(9 downto 3) = (hsync_pos - 80) + slots_per_line) then
					x_state <= "11";			-- right border starts
					is_border <= '1';
				end if;
			end if;
							
		end if;
	end process;
	
	
end Behavioral;

