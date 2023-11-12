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

entity Sprites is
    Port ( 
	   CPU_D: in std_logic_vector(7 downto 0);
	   VRAM_D: in std_logic_vector(7 downto 0);
	   phi2: in std_logic;
	   
	   is_enable: in std_logic;
	   is_80: in std_logic;
	   interlace_int: in std_logic;
		is_double_int: in std_logic;
		rline_cnt0: in std_logic;
		col_bg0: in std_logic_vector(3 downto 0);
		
	   crtc_sel : in std_logic;
	   crtc_regsel : in std_logic_vector(7 downto 0);
	   crtc_is_data : in std_logic;
	   crtc_rwb : in std_logic;
		vd_out: out std_logic_vector(7 downto 0);
		
	   qclk: in std_logic;		-- Q clock (50MHz)
 	   dotclk: in std_logic_vector(3 downto 0);	-- 25Mhz, 1/2, 1/4, 1/8, 1/16
	   h_zero: in std_logic;
		v_zero: in std_logic;
		x_addr: in std_logic_vector(9 downto 0);
		y_addr: in std_logic_vector(9 downto 0);
		sprite_ptr_window: in std_logic;
		sprite_data_window: in std_logic;
		fetch_ce: in std_logic;
		
		sprite_base: out std_logic_vector(7 downto 0);
		sprite_fetch_ptr: out std_logic_vector(15 downto 0);
		sprite_ptr_fetch: out std_logic;
		sprite_data_fetch: out std_logic;
		sprite_fetch_idx_v: out std_logic_vector(2 downto 0);
		sprite_ison: out std_logic_vector(7 downto 0);
		
		-- sprites output to mixer
		sprite_on: out std_logic;
		sprite_outcol: out std_logic_vector(3 downto 0);
		sprite_onborder: out std_logic;
		sprite_onraster: out std_logic;
		sprite_no: out integer range 0 to 7;
		
	   reset : in std_logic
	   );

		attribute maxskew: string;
		--attribute maxskew of vid_out : signal is "4 ns";
		attribute maxdelay: string;
		--attribute maxdelay of vid_out : signal is "5 ns";
end Sprites;

architecture Behavioral of Sprites is

	type AOA2 is array(natural range<>) of std_logic_vector(1 downto 0);
	type AOA4 is array(natural range<>) of std_logic_vector(3 downto 0);
	type AOA6 is array(natural range<>) of std_logic_vector(5 downto 0);
	type AOA8 is array(natural range<>) of std_logic_vector(7 downto 0);
			
	signal fetch_sprite_en: std_logic;
	
	signal sprite_ptr_fetch_int: std_logic;
	signal sprite_data_fetch_int: std_logic;

	-- sprite
	signal sprite_sel: std_logic_vector(7 downto 0);
	signal sprite_dout: AOA8(0 to 7);
	signal sprite_d: std_logic_vector(7 downto 0);
	signal sprite_fetch_offset: AOA6(0 to 7);
	signal sprite_enabled: std_logic_vector(7 downto 0);
	signal sprite_active: std_logic_vector(7 downto 0);
	signal sprite_ison_int: std_logic_vector(7 downto 0);
	signal sprite_overraster: std_logic_vector(7 downto 0);
	signal sprite_overborder: std_logic_vector(7 downto 0);
	signal sprite_outbits: AOA4(0 to 7);
	signal sprite_fgcol: AOA4(0 to 7);
	signal sprite_mcol1: std_logic_vector(3 downto 0);
	signal sprite_mcol2: std_logic_vector(3 downto 0);
	signal sprite_base_int: std_logic_vector(7 downto 0);
	
	signal sprite_fetch_idx: integer range 0 to 7;
	signal sprite_fetch_win: std_logic;	-- sprites can fetch
	signal sprite_fetch_done: std_logic;	-- sprites can fetch
	signal sprite_fetch_active: std_logic;		-- sprite is active for fetch
	signal sprite_data_ptr: std_logic_vector(7 downto 0);
	signal sprite_fetch_ce: std_logic_vector(7 downto 0);
	
	component Sprite is
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
		fetch_ce: in std_logic;

		qclk: in std_logic;
		dotclk: in std_logic_vector(3 downto 0);
		vdin: in std_logic_vector(7 downto 0);
		h_zero: in std_logic;
		v_zero: in std_logic;
		x_addr: in std_logic_vector(9 downto 0);
		y_addr: in std_logic_vector(9 downto 0);
		is_double: in std_logic;
		is_interlace: in std_logic;
		is80: in std_logic;

		enabled: out std_logic;		-- if sprite data should be read in rasterline
		active: out std_logic;		-- if sprite pixel out is active (in x/y area)
		ison: out std_logic;			-- if sprite pixel is not background (for collision / prio)
		overraster: out std_logic;		-- if sprite should appear over the raster
		overborder: out std_logic;		-- if sprite should appear over the border
		outbits: out std_logic_vector(3 downto 0); 	-- double bit output
		
		reset: in std_logic
	);
	end component;
	
begin
	
	-----------------------------------------------------------------------------
	-- sprite handling

	-- enables sprite fetch on the first 8 slots (8x4 accesses), when the correct sprite is enabled (sprite_active)
	fetch_sprite_en <= '1' when is_enable = '1' 
								-- and first_row = '1'
								and (interlace_int = '1' or rline_cnt0 = '0')
								and sprite_fetch_active = '1'
								and sprite_fetch_win = '1'
							else '0';

	sprite_ptr_fetch_int <= sprite_ptr_window and fetch_sprite_en;
	sprite_data_fetch_int <= sprite_data_window and fetch_sprite_en;	
	
	sprite_ptr_fetch <= sprite_ptr_fetch_int;
	sprite_data_fetch <= sprite_data_fetch_int;
	
	sprite_ison <= sprite_ison_int;
	
	sprite_outcol_p: process(qclk, dotclk)
	begin
		
		if (falling_edge(qclk)) then -- and dotclk(0) = '0') then
			if (sprite_ison_int(0) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(0);
				sprite_onborder <= sprite_overborder(0);
				sprite_onraster <= sprite_overraster(0);
				sprite_no <= 0;
			elsif (sprite_ison_int(1) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(1);
				sprite_onborder <= sprite_overborder(1);
				sprite_onraster <= sprite_overraster(1);
				sprite_no <= 1;
			elsif (sprite_ison_int(2) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(2);
				sprite_onborder <= sprite_overborder(2);
				sprite_onraster <= sprite_overraster(2);
				sprite_no <= 2;
			elsif (sprite_ison_int(3) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(3);
				sprite_onborder <= sprite_overborder(3);
				sprite_onraster <= sprite_overraster(3);
				sprite_no <= 3;
			elsif (sprite_ison_int(4) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(4);
				sprite_onborder <= sprite_overborder(4);
				sprite_onraster <= sprite_overraster(4);
				sprite_no <= 4;
			elsif (sprite_ison_int(5) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(5);
				sprite_onborder <= sprite_overborder(5);
				sprite_onraster <= sprite_overraster(5);
				sprite_no <= 5;
			elsif (sprite_ison_int(6) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(6);
				sprite_onborder <= sprite_overborder(6);
				sprite_onraster <= sprite_overraster(6);
				sprite_no <= 6;
			elsif (sprite_ison_int(7) = '1') then
				sprite_on <= '1';
				sprite_outcol <= sprite_outbits(7);
				sprite_onborder <= sprite_overborder(7);
				sprite_onraster <= sprite_overraster(7);
				sprite_no <= 7;
			else
				sprite_on <= '0';
				sprite_outcol <= "0000";
				sprite_onborder <= '0';
				sprite_onraster <= '0';
				sprite_no <= 0;
			end if;
		end if;
	end process;


--	spritesprite_p: process(qclk, dena_int, collision_trigger_sprite_sprite, collision_accum_sprite_sprite)
--	begin
--
--		collision_sprite_sprite_none <= '0';
--		if (collision_accum_sprite_sprite = "00000000") then
--			collision_sprite_sprite_none <= '1';
--		end if;
--		
--		if (falling_edge(qclk)) then -- and dotclk(0) = '0') then
--
--			irq_sprite_sprite_trigger <= '0';
--			
--			outer_l: for i in 0 to 7 loop
--			
--				collision_trigger_sprite_sprite(i) <= '0';
--				
--				inner_l: for j in 0 to 7 loop
--				
--					if (i /= j) then
--					
--						if (sprite_ison_int(i) = '1' and sprite_ison_int(j) = '1') then
--						
--							collision_trigger_sprite_sprite(i) <= '1';
--							
--							if (collision_sprite_sprite_none = '1') then 
--								irq_sprite_sprite_trigger <= '1';
--							end if;
--						end if;
--					end if;
--				end loop;
--			end loop;
--		end if;
--	end process;
--	
	sdo_p: process(crtc_regsel, crtc_sel, crtc_is_data, sprite_dout)
	begin
	
		sprite_sel <= (others => '0');
		sprite_d <= (others => '0');
		
		if (crtc_sel = '1' and crtc_is_data = '1') then
			case crtc_regsel(6 downto 2) is
			when "01100" =>	-- sprite 0
				sprite_sel(0) <= '1';
				sprite_d <= sprite_dout(0);
			when "01101" =>	-- sprite 1
				sprite_sel(1) <= '1';
				sprite_d <= sprite_dout(1);
			when "01110" =>	-- sprite 2
				sprite_sel(2) <= '1';
				sprite_d <= sprite_dout(2);
			when "01111" =>	-- sprite 3
				sprite_sel(3) <= '1';
				sprite_d <= sprite_dout(3);
			when "10000" =>	-- sprite 4
				sprite_sel(4) <= '1';
				sprite_d <= sprite_dout(4);
			when "10001" =>	-- sprite 5
				sprite_sel(5) <= '1';
				sprite_d <= sprite_dout(5);
			when "10010" =>	-- sprite 6
				sprite_sel(6) <= '1';
				sprite_d <= sprite_dout(6);
			when "10011" =>	-- sprite 7
				sprite_sel(7) <= '1';
				sprite_d <= sprite_dout(7);
			when others =>
			end case;
		end if;
	end process;

	fetch_idx_p: process(qclk, dotclk, h_zero, sprite_fetch_idx)
	begin
		if (h_zero = '1') then
			sprite_fetch_idx <= 0;
			sprite_fetch_win <= '0';
			sprite_fetch_done <= '0';
		elsif (falling_edge(qclk) and dotclk = "1111") then
			if (sprite_fetch_done = '0') then
				if (sprite_fetch_win = '0') then
					sprite_fetch_win <= '1';
				elsif(sprite_fetch_idx = 7) then
					sprite_fetch_win <= '0';
					sprite_fetch_done <= '1';
				else
					sprite_fetch_idx <= sprite_fetch_idx + 1;
				end if;
			end if;
		end if;
		
		sprite_fetch_idx_v <= std_logic_vector(to_unsigned(sprite_fetch_idx, sprite_fetch_idx_v'length));
	end process;
	
	fetchactive_p: process(qclk, x_addr, sprite_fetch_idx, sprite_ptr_fetch_int, sprite_data_fetch_int, fetch_ce, sprite_data_ptr, sprite_base_int)
	begin
		sprite_fetch_active <= sprite_enabled(sprite_fetch_idx);
		sprite_fetch_ptr(5 downto 0) <= sprite_fetch_offset(sprite_fetch_idx);
		sprite_fetch_ptr(13 downto 6) <= sprite_data_ptr;
		sprite_fetch_ptr(15 downto 14) <= sprite_base_int(7 downto 6);
		
		if (falling_edge(qclk)) then
			if (fetch_ce = '1' and sprite_ptr_fetch_int = '1') then
				sprite_data_ptr <= VRAM_D;
			end if;
		end if;
		
		sprite_fetch_ce <= "00000000";
		case (sprite_fetch_idx) is
		when 0 =>	sprite_fetch_ce(0) <= sprite_data_fetch_int and fetch_ce;
		when 1 =>	sprite_fetch_ce(1) <= sprite_data_fetch_int and fetch_ce;
		when 2 =>	sprite_fetch_ce(2) <= sprite_data_fetch_int and fetch_ce;
		when 3 =>	sprite_fetch_ce(3) <= sprite_data_fetch_int and fetch_ce;
		when 4 =>	sprite_fetch_ce(4) <= sprite_data_fetch_int and fetch_ce;
		when 5 =>	sprite_fetch_ce(5) <= sprite_data_fetch_int and fetch_ce;
		when 6 =>	sprite_fetch_ce(6) <= sprite_data_fetch_int and fetch_ce;
		when 7 =>	sprite_fetch_ce(7) <= sprite_data_fetch_int and fetch_ce;
		when others =>
		end case;
		
	end process;

	sprite0: Sprite
	port map (
		phi2,
		sprite_sel(0),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(0),
		sprite_fgcol(0),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(0),
		sprite_fetch_ce(0),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(0),
		sprite_active(0),
		sprite_ison_int(0),
		sprite_overraster(0),
		sprite_overborder(0),
		sprite_outbits(0),
		reset
	);

	sprite1: Sprite
	port map (
		phi2,
		sprite_sel(1),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(1),
		sprite_fgcol(1),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(1),
		sprite_fetch_ce(1),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(1),
		sprite_active(1),
		sprite_ison_int(1),
		sprite_overraster(1),
		sprite_overborder(1),
		sprite_outbits(1),
		reset
	);

	sprite2: Sprite
	port map (
		phi2,
		sprite_sel(2),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(2),
		sprite_fgcol(2),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(2),
		sprite_fetch_ce(2),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(2),
		sprite_active(2),
		sprite_ison_int(2),
		sprite_overraster(2),
		sprite_overborder(2),
		sprite_outbits(2),
		reset
	);

	sprite3: Sprite
	port map (
		phi2,
		sprite_sel(3),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(3),
		sprite_fgcol(3),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(3),
		sprite_fetch_ce(3),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(3),
		sprite_active(3),
		sprite_ison_int(3),
		sprite_overraster(3),
		sprite_overborder(3),
		sprite_outbits(3),
		reset
	);

	sprite4: Sprite
	port map (
		phi2,
		sprite_sel(4),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(4),
		sprite_fgcol(4),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(4),
		sprite_fetch_ce(4),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(4),
		sprite_active(4),
		sprite_ison_int(4),
		sprite_overraster(4),
		sprite_overborder(4),
		sprite_outbits(4),
		reset
	);

	sprite5: Sprite
	port map (
		phi2,
		sprite_sel(5),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(5),
		sprite_fgcol(5),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(5),
		sprite_fetch_ce(5),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(5),
		sprite_active(5),
		sprite_ison_int(5),
		sprite_overraster(5),
		sprite_overborder(5),
		sprite_outbits(5),
		reset
	);

	sprite6: Sprite
	port map (
		phi2,
		sprite_sel(6),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(6),
		sprite_fgcol(6),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(6),
		sprite_fetch_ce(6),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(6),
		sprite_active(6),
		sprite_ison_int(6),
		sprite_overraster(6),
		sprite_overborder(6),
		sprite_outbits(6),
		reset
	);

	sprite7: Sprite
	port map (
		phi2,
		sprite_sel(7),
		crtc_rwb,
		crtc_regsel(1 downto 0),
		CPU_D,
		sprite_dout(7),
		sprite_fgcol(7),
		col_bg0,
		sprite_mcol1,
		sprite_mcol2,
		sprite_fetch_offset(7),
		sprite_fetch_ce(7),
		qclk,
		dotclk,
		VRAM_D,
		h_zero,
		v_zero,
		x_addr,
		y_addr,
		is_double_int,
		interlace_int,
		is_80,
		sprite_enabled(7),
		sprite_active(7),
		sprite_ison_int(7),
		sprite_overraster(7),
		sprite_overborder(7),
		sprite_outbits(7),
		reset
	);

	sprite_base <= sprite_base_int;
	
	reg9: process(phi2, CPU_D, crtc_sel, crtc_is_data, crtc_rwb, crtc_regsel, reset) 
	begin
		if (reset = '1') then
			sprite_mcol1 <= "0000";
			sprite_mcol1 <= "0000";
			sprite_base_int <= "10010111";
		elsif (falling_edge(phi2) 
				and crtc_sel = '1'
				and crtc_is_data = '1' 
				and crtc_rwb = '0'
				) then
			case (crtc_regsel) is
			when x"50" =>	-- R80
				sprite_fgcol(0) <= CPU_D(3 downto 0);
			when x"51" =>	-- R81
				sprite_fgcol(1) <= CPU_D(3 downto 0);
			when x"52" =>	-- R82
				sprite_fgcol(2) <= CPU_D(3 downto 0);
			when x"53" =>	-- R83
				sprite_fgcol(3) <= CPU_D(3 downto 0);
			when x"54" =>	-- R84
				sprite_fgcol(4) <= CPU_D(3 downto 0);
			when x"55" =>	-- R85
				sprite_fgcol(5) <= CPU_D(3 downto 0);
			when x"56" =>	-- R86
				sprite_fgcol(6) <= CPU_D(3 downto 0);
			when x"57" =>	-- R87
				sprite_fgcol(7) <= CPU_D(3 downto 0);
			when x"58" =>	-- R88
				sprite_base_int <= CPU_D;
			when x"5c" =>	-- R92
				sprite_mcol1 <= CPU_D(3 downto 0);
			when x"5d" =>	-- R93
				sprite_mcol2 <= CPU_D(3 downto 0);
			when others =>
				null;
			end case;
		end if;
	end process;

	readreg: process(crtc_rwb, crtc_sel, crtc_is_data, crtc_regsel, reset) 
	begin
		if (reset = '1') then
			vd_out <= (others => '0');
		else 
			vd_out <= (others => '0');
			
			if	(crtc_sel = '1'
				and crtc_rwb = '1'
				and crtc_is_data = '1'
				) then
									
					case (crtc_regsel) is
					when x"50" =>	-- R80
						vd_out(3 downto 0) <= sprite_fgcol(0);
					when x"51" =>	-- R81
						vd_out(3 downto 0) <= sprite_fgcol(1);
					when x"52" =>	-- R82
						vd_out(3 downto 0) <= sprite_fgcol(2);
					when x"53" =>	-- R83
						vd_out(3 downto 0) <= sprite_fgcol(3);
					when x"54" =>	-- R84
						vd_out(3 downto 0) <= sprite_fgcol(4);
					when x"55" =>	-- R85
						vd_out(3 downto 0) <= sprite_fgcol(5);
					when x"56" =>	-- R86
						vd_out(3 downto 0) <= sprite_fgcol(6);
					when x"57" =>	-- R87
						vd_out(3 downto 0) <= sprite_fgcol(7);
					when x"58" =>	-- R88
						vd_out <= sprite_base_int;
					when x"5c" =>	-- R92
						vd_out(3 downto 0) <= sprite_mcol1;
					when x"5d" =>	-- R93
						vd_out(3 downto 0) <= sprite_mcol2;
					when others =>
						vd_out <= sprite_d;
					end case;
				end if;
			end if;
	end process;

end Behavioral;

