----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:40:17 10/21/2023 
-- Design Name: 
-- Module Name:    Sprite - Behavioral 
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

entity Sprite is
	Port (
		phi2: in std_logic;
		sel: in std_logic;
		rwb: in std_logic;
		regsel: in std_logic_vector(1 downto 0);
		din: in std_logic_vector(7 downto 0);
		dout: out std_logic_vector(7 downto 0);
		
		fgcol: in std_logic_vector(3 downto 0);
		bgcol: in std_logic_vector(3 downto 0);
		mcol1: in std_logic_vector(3 downto 0);
		mcol2: in std_logic_vector(3 downto 0);

		fetch_offset: out std_logic_vector(5 downto 0);	-- 21x3 bytes = 63

		qclk: in std_logic;
		dotclk: in std_logic_vector(3 downto 0);
		h_zero: in std_logic;
		v_zero: in std_logic;
		x_addr: in std_logic_vector(9 downto 0);
		y_addr: in std_logic_vector(9 downto 0);
		next_row: in std_logic;
		is80: in std_logic;
		
		enabled: out std_logic;		-- if sprite data should be read in rasterline
		active: out std_logic;		-- if sprite pixel out is active (in x/y area)
		ison: out std_logic;			-- if sprite pixel is not background (for collision / prio)
		overraster: out std_logic;		-- if sprite should appear over the raster
		overborder: out std_logic;		-- if sprite should appear over the border
		outbits: out std_logic_vector(3 downto 0); 	-- double bit output
		
		reset: in std_logic
	);

end Sprite;

architecture Behavioral of Sprite is

	signal s_enabled: std_logic;
	signal s_multi: std_logic;
	signal s_overborder: std_logic;
	signal s_overraster: std_logic;
	signal x_expand: std_logic;
	signal y_expand: std_logic;

	signal x_pos: std_logic_vector(9 downto 0);
	signal y_pos: std_logic_vector(9 downto 0);
	
	signal x_cnt: std_logic_vector(5 downto 0);
	signal y_cnt: std_logic_vector(5 downto 0);
	
	signal shiftreg: std_logic_vector(23 downto 0) := "111100101000001010101111";
	
	signal enabled_int: std_logic;
	signal active_int: std_logic;
	signal ison_int: std_logic;
	
begin

	xcnt_p: process(qclk, h_zero)
	begin
		if (h_zero = '1') then
			x_cnt <= (others => '0');
		elsif (falling_edge(qclk) and dotclk(0) = '1' and (is80 = '1' or dotclk(1) = '1')) then
			if (active_int = '1') then
				x_cnt <= x_cnt + 1;
			end if;
		end if;
	end process;

	ycnt_p: process(qclk, v_zero, h_zero)
	begin
		if (v_zero = '1') then
			y_cnt <= (others => '0');
		elsif (falling_edge(h_zero) and next_row = '1') then
			if (enabled_int = '1') then
				y_cnt <= y_cnt + 1;
			end if;
		end if;
	end process;
	
	enable_p: process (h_zero)
	begin
		if (rising_edge(h_zero)) then
			if (y_addr = y_pos and s_enabled = '1') then
				enabled_int <= '1';
			elsif (y_expand = '0' and y_cnt = "010101") then	-- 21
				enabled_int <= '0';
			elsif (y_expand = '1' and y_cnt = "101010") then	-- 42
				enabled_int <= '0';
			elsif (v_zero = '1') then
				enabled_int <= '0';
			end if;
		end if;
	end process;
	
	active_p: process (qclk)
	begin
		if (falling_edge(qclk)) then
			if (x_addr = x_pos and enabled_int = '1') then
				active_int <= '1';
			elsif (x_expand = '0' and x_cnt = "011000") then	-- 24
				active_int <= '0';
			elsif (x_expand = '1' and x_cnt = "110000") then	-- 48
				active_int <= '0';
			end if;
		end if;
	end process;
	
	-- TODO
	out_p: process(qclk)
	begin
		if (falling_edge(qclk) and dotclk(0) = '1' and (is80 = '1' or dotclk(1) = '1')) then
			if (active_int = '1') then
				-- TODO multicol
				ison_int <= shiftreg(0) or (s_multi and shiftreg(1));
				shiftreg(23 downto 1) <= shiftreg(22 downto 0);
				-- debug endless loop
				shiftreg(0) <= shiftreg(23);
				
				if (shiftreg(0) = '1') then
					outbits <= fgcol;
				else
					outbits <= bgcol;
				end if;
			else
				ison_int <= '0';
			end if;
		end if;
	end process;
	
	regw_p: process(reset, phi2, sel, regsel,rwb)
	begin
		if (reset = '1') then
			x_expand <= '0';
			y_expand <= '0';
			s_enabled <= '1';
			s_overraster <= '0';
			s_overborder <= '0';
			s_multi <= '0';
			x_pos <= "0010000000";	-- (others => '0');
			y_pos <= "0010000000";	-- (others => '0');
		elsif (falling_edge(phi2)
			and sel = '1' and rwb = '0'
			) then
			
			case (regsel) is
			when "00" =>	-- R0
				x_pos(7 downto 0) <= din;
			when "01" => 	-- R1
				y_pos(7 downto 0) <= din;
			when "10" =>	-- R2
				x_pos(9 downto 8) <= din(1 downto 0);
				y_pos(9 downto 8) <= din(5 downto 4);
			when "11" =>	-- R3
				s_enabled <= din(0);
				x_expand <= din(1);
				y_expand <= din(2);
				s_multi <= din(3);
				s_overraster <= din(4);
				s_overborder <= din(5);
			when others =>
				null;
			end case;
		end if;
	end process;
	
	reqr_p: process(phi2, sel, rwb, regsel, x_pos, y_pos, s_enabled, x_expand, y_expand, s_multi, s_overraster, s_overborder)
	begin
		dout <= (others => '0');
		
		if (sel = '1' and rwb = '1') then
		
			case regsel is
			when "00" =>	-- R0
				dout <= x_pos(7 downto 0);
			when "01" =>	-- R1
				dout <= y_pos(7 downto 0);
			when "10" =>
				dout(1 downto 0) <= x_pos(9 downto 8);
				dout(5 downto 4) <= y_pos(9 downto 8);
			when "11" =>
				dout(0) <= s_enabled;
				dout(1) <= x_expand;
				dout(2) <= y_expand;
				dout(3) <= s_multi;
				dout(4) <= s_overraster;
				dout(5) <= s_overborder;
			when others =>
				null;
			end case;
		end if;
	end process;
	
	overborder <= s_overborder;
	overraster <= s_overraster;
	enabled <= enabled_int;
	active <= active_int;
	ison <= ison_int;
	
end Behavioral;

