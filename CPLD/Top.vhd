----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:38:52 06/21/2020 
-- Design Name: 
-- Module Name:    Top - Behavioral 
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

entity Top is
    Port ( 
	-- clock
	   q50m : in std_logic;
	   nres : in std_logic;
	
	   -- CS/A out bus timing
	   c8phi2	: out std_logic;
	   c2phi2	: out std_logic;
	   cphi2	: out std_logic;

	-- config
	   graphic: in std_logic;	-- from I/O, select charset
	   
	-- CPU interface
	   A : in  STD_LOGIC_VECTOR (15 downto 0);
           D : inout  STD_LOGIC_VECTOR (7 downto 0);
           vda : in  STD_LOGIC;
           vpa : in  STD_LOGIC;
	   rwb : in std_logic;
           phi2 : inout  STD_LOGIC;	-- with pull-up to go to 5V
	   rdy_in : in std_logic;	-- is input only (bi-dir on '816, but hardware only allows in)
	   vpb : in std_logic;
	   e : in std_logic;
	   mlb: in std_logic;
	   mx : in std_logic;

	-- bus
	-- ROM, I/O (on CPU bus)	   
	   sync : out std_logic;
	   nmemsel: out std_logic;
	   niosel: out std_logic;
	   extio: in std_logic;
	   ioinh: in std_logic;
	   nbe_out : out std_logic;
	   nbe_dout : out std_logic;
	   be_in: in std_logic;
	   
	-- I/O interface
	   phi2_io: inout std_logic;

	-- V/RAM interface
	   VA : out std_logic_vector (18 downto 0);	-- 512k
	   FA : out std_logic_vector (19 downto 15);	-- 512k, mappable in 32k blocks
	   VD : inout std_logic_vector (7 downto 0);
	   
	   nvramsel : out STD_LOGIC;
	   nframsel : out STD_LOGIC;
	   ramrwb : out std_logic;

	-- video out
           pxlld 	: out std_logic;
	   colorld	: out std_logic;
	   nchromaddr	: out std_logic;
	   nsrload	: out std_logic;
	   
           vsync : out  STD_LOGIC;
           hsync : out  STD_LOGIC;
	   dclk : out std_logic;
	   dena : out std_logic;
	   pet_vsync: out std_logic;
	   
	-- SPI
	   spi_out : out std_logic;
	   spi_clk : out std_logic;
	   -- MISO
	   spi_in1  : in std_logic;
	   spi_in3  : in std_logic;
	   -- selects
	   nflash : out std_logic;	-- in1
	   spi_nsel2 : out std_logic;	-- in1
	   spi_nsel3 : out std_logic;	-- sd card, in3
	   spi_nsel4 : out std_logic;	-- in1
	   spi_nsel5 : out std_logic;	-- in1
	   
	-- Debug
	   dbg_out: out std_logic;
	   test: out std_logic
	 );
end Top;

architecture Behavioral of Top is

	type T_VADDR_SRC is (VRA_IPL, VRA_CPU, VRA_VIDEO, VRA_CHRROM);
		
	attribute NOREDUCE : string;
	
	-- Initial program load
	signal ipl: std_logic;		-- Initial program load from SPI flash
	signal ipl_d: std_logic;		-- Initial program load from SPI flash
	constant ipl_addr: std_logic_vector(18 downto 8) := "00011111111";	-- top most RAM page in bank 0
	signal ipl_state: std_logic;	-- 00 = send addr, 01=read block
	signal ipl_state_d: std_logic;	-- 00 = send addr, 01=read block
	signal ipl_cnt: std_logic_vector(11 downto 0); -- 11-4: block address count, 3-0: SPI state count
	signal ipl_out: std_logic;	-- SPI output from IPL to flash
	signal ipl_next: std_logic;	-- start next phase
	
	-- clock
	signal dotclk: std_logic;
	signal dot2clk: std_logic;
	signal slotclk: std_logic;
	signal slot2clk: std_logic;
	signal pxl_window: std_logic;
	signal chr_window: std_logic;
	signal col_window: std_logic;
	signal cpu_window: std_logic;
	signal pxl_fetch: std_logic;
	signal chr_fetch: std_logic;
	signal crom_fetch: std_logic;
	signal col_fetch: std_logic;
	signal sr_load: std_logic;
	signal VA_select: T_VADDR_SRC;
	
	signal memclk: std_logic;
	signal clk1m: std_logic;
	signal clk2m: std_logic;
	signal clk4m: std_logic;
	
	signal phi2_int: std_logic;
	signal phi2_out: std_logic;
	signal phi2_io_out: std_logic;
	signal is_cpu: std_logic;
	signal is_cpu_trigger: std_logic;
	signal rdy_out: std_logic;
		
	-- CPU memory mapper
	signal cfgld_in: std_logic;
	signal ma_out: std_logic_vector(19 downto 8);
	--signal ma_vout: std_logic_vector(13 downto 12);
	signal m_framsel_out: std_logic;
	signal m_vramsel_out: std_logic;
	signal m_ffsel_out: std_logic;
	signal nvramsel_int: std_logic;
	signal nframsel_int: std_logic;
	signal m_iosel: std_logic;
	signal m_memsel: std_logic;

	signal sel0 : std_logic;
	signal sel8 : std_logic;

	signal mode : std_logic_vector(1 downto 0);
	signal boot : std_logic;
	signal wp_rom9 : std_logic;
	signal wp_romA : std_logic;
	signal wp_romB : std_logic;
	signal wp_romPET : std_logic;
	signal is8296 : std_logic;
	signal lowbank : std_logic_vector(3 downto 0);
	signal vidblock : std_logic_vector(2 downto 0);
	signal lockb0 : std_logic;
	signal forceb0 : std_logic;
	signal movesync : std_logic;
	
	-- video
	signal va_out: std_logic_vector(15 downto 0);
	signal vis_enable: std_logic;
	signal vis_80_in: std_logic;
	signal vis_hires_in: std_logic;
	signal vis_double_in: std_logic;
	signal is_vid_out: std_logic;
	signal vgraphic: std_logic;
	signal screenb0: std_logic;
	signal interlace : std_logic;
	signal v_dena: std_logic;
	signal v_ldsync: std_logic;
	signal v_ldsync_d: std_logic;
	
	-- cpu
	signal ca_in: std_logic_vector(15 downto 0);
	signal cd_in: std_logic_vector(7 downto 0);
	signal reset: std_logic;
	signal wait_ram: std_logic;
	signal wait_bus: std_logic;	-- when CPU waits for end of CS/A bus cycle
	signal wait_setup: std_logic;	-- when CPU needs to wait for setup time
	signal is_bus: std_logic;
	signal wait_int: std_logic;
	signal ramrwb_int: std_logic;
	signal do_cpu : std_logic;
	signal memclk_d : std_logic;
	signal memclk_dd : std_logic;
	signal memclk_ddd : std_logic;
	
	-- SPI
	signal spi_dout : std_logic_vector(7 downto 0);
	signal spi_cs : std_logic;
	signal spi_in : std_logic;
	signal spi_sel : std_logic_vector(2 downto 0);
	signal spi_outx : std_logic;
	signal spi_clkx : std_logic;
	
	-- bus
	signal niosel_int: std_logic;
	signal nmemsel_int: std_logic;
	signal chold: std_logic;
	signal csetup: std_logic;
	signal be_out_int: std_logic;
	
	signal bus_window_c: std_logic;	-- map $00Cxxx to MEMSEL too
	signal bus_window_9: std_logic; -- map $009xxx to MEMSEL
	
	-- components
	
	component Clock is
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
	   chold	: out std_logic;
	   csetup	: out std_logic;
	   
	   dotclk	: out std_logic;	-- pixel clock for video
	   dot2clk	: out std_logic;	-- half the pixel clock
	   slotclk	: out std_logic;	-- 1 slot = 8 pixel;
	   slot2clk	: out std_logic;	-- 1 slot = 16 pixel
	   cpu_window	: out std_logic;	-- 1 during CPU window on VRAM
	   chr_window	: out std_logic;	-- 1 during character fetch window
	   pxl_window	: out std_logic;	-- 1 during pixel fetch window
	   col_window	: out std_logic;	-- 1 during color fetch (end of slot)
	   sr_load	: out std_logic		-- load pixel SR on falling edge of dotclk when this is set
	 );
	end component;
	   
	component Mapper is
	  Port ( 
	   A : in  STD_LOGIC_VECTOR (15 downto 8);
           D : in  STD_LOGIC_VECTOR (7 downto 0);
	   reset : in std_logic;
	   phi2: in std_logic;
	   vpa: in std_logic;
	   vda: in std_logic;
	   vpb: in std_logic;
	   rwb : in std_logic;
	   
	   qclk : in std_logic;
	   
           cfgld : in  STD_LOGIC;	-- set when loading the cfg
	   
           RA : out std_logic_vector (19 downto 8);	-- mapped CPU address (FRAM)
	   --VA : out std_logic_vector (13 downto 12);	-- separate VRAM address for screen win
	   ffsel: out std_logic;
	   iosel: out std_logic;
	   memsel: out std_logic;
	   vramsel: out std_logic;
	   framsel: out std_logic;

	   boot: in std_logic;
	   lowbank: in std_logic_vector(3 downto 0);
	   vidblock: in std_logic_vector(2 downto 0);
	   wp_rom9: in std_logic;
	   wp_romA: in std_logic;
	   wp_romB: in std_logic;
	   wp_romPET: in std_logic;
	   -- bus
	   bus_window_9: in std_logic;
	   bus_window_c: in std_logic;

	   forceb0: in std_logic;
	   screenb0: in std_logic;
	   
	   dbgout: out std_logic
	  );
	end component;
	
	component Video is
	  Port ( 
	   A : out  STD_LOGIC_VECTOR (15 downto 0);
	   CPU_D : in std_logic_vector (7 downto 0);
	   phi2 : in std_logic;
	   
	   dena   : out std_logic;	-- display enable
           v_sync : out  STD_LOGIC;
           h_sync : out  STD_LOGIC;
	   pet_vsync: out std_logic;	-- for the PET screen interrupt

	   is_enable: in std_logic;	-- is display enabled
           is_80_in : in STD_LOGIC;	-- is 80 column mode?
	   is_hires : in std_logic;	-- is hires mode?
	   is_graph : in std_logic;	-- from PET I/O
	   is_double: in std_logic;	-- when set, use 50 char rows / 400 pixel rows
	   interlace: in std_logic;
	   movesync:  in std_logic;
	   
	   crtc_sel : in std_logic;	-- select line for CRTC
	   crtc_rs  : in std_logic;	-- register select
	   crtc_rwb : in std_logic;	-- r/-w
	   
	   qclk: in std_logic;		-- Q clock
           memclk : in STD_LOGIC;	-- system clock 8MHz
	   slotclk : in std_logic;
	   slot2clk: in std_logic;
	   chr_window : in std_logic;
	   pxl_window : in std_logic;
	   col_window : in std_logic;
	   
	   chr_fetch : out std_logic;
	   crom_fetch: out std_logic;
	   pxl_fetch : out std_logic;
	   col_fetch : out std_logic;
	   
	   sr_load : in std_logic;
	   
           is_vid : out STD_LOGIC;	-- true during video access phase
	   reset : in std_logic
	 );
	end component;

	component SPI is
	  Port ( 
	   DIN : in  STD_LOGIC_VECTOR (7 downto 0);
	   DOUT : out  STD_LOGIC_VECTOR (7 downto 0);
	   RS: in std_logic_vector(1 downto 0);
	   RWB: in std_logic;
	   CS: in std_logic;	-- includes clock
	   
	   serin: in std_logic;
	   serout: out std_logic;
	   serclk: out std_logic;
	   sersel: out std_logic_vector(2 downto 0);	   
	   spiclk : in std_logic;
	   
	   ipl: in std_logic;
	   reset : in std_logic
	 );
	end component;

	function To_Std_Logic(L: BOOLEAN) return std_ulogic is
	begin
		if L then
			return('1');
		else
			return('0');
		end if;
	end function To_Std_Logic;

begin

	clocky: Clock
	port map (
	   q50m,
	   reset,
	   memclk,
	   clk1m,
	   clk2m,
	   clk4m,
	   c8phi2,
	   c2phi2,
	   cphi2,
	   chold,
	   csetup,
	   dotclk,
	   dot2clk,
	   slotclk,
	   slot2clk,
	   cpu_window,
	   chr_window,
	   pxl_window,
	   col_window,
	   sr_load
	);

	reset <= not(nres);
	
	-- define CPU slots.
	-- mode(1 downto 0): 00=1MHz, 01=2MHz, 10=4MHz, 11=Max speed

	is_cpu_trigger <= '1'	when mode = "11" else
			clk4m	when mode = "10" else
			clk2m	when mode = "01" else
			clk1m;

	-- depending on mode, goes high when we have a CPU access pending,
	-- and else low when a CPU access is done
	is_cpu_p: process(reset, is_cpu_trigger, is_cpu, do_cpu, mode, memclk)
	begin
		if (reset = '1') then
			is_cpu <= '0';
		elsif (mode = "11") then
			is_cpu <= '1';
		elsif falling_edge(memclk) then
 			if (is_cpu_trigger = '1') then
				is_cpu <= '1';
			elsif (do_cpu = '1') then
				is_cpu <= '0';
			end if;
		end if;
	end process;
	
	-- note: 
	-- m_ramsel_out depends on bankl, which is qualified with rising edge of qclk
	-- memclk is created at falling edge of qclk
	-- is_vid is qualified with rising edge of qclk, but depends on pxl/char_window
	-- that is created at same falling edge of qclk as when memclk falls low
	-- so is_vid is early, but goes low at same falling edge as memclk
	wait_ram <= '1' when m_vramsel_out = '1' and is_vid_out = '1' else	-- video access in RAM
			'0';
	
	-- stretch clock such that we approx. one cycle per is_cpu_trigger (1, 2, 4MHz)
	-- wait_int rises with falling edge of memclk (see trigger above), or is 
	-- constant low (full speed)
	wait_int <= not(is_cpu); -- or ipl;
		
	release2_p: process(memclk_d, memclk_dd, memclk_ddd, reset)
	begin
		if (reset = '1') then
			do_cpu <= '0';
		elsif (rising_edge(memclk_ddd)) then
			if (	(is_bus = '0' 
					and wait_int = '0' and wait_ram = '0')
				or (is_bus = '1' 
					and wait_setup = '0' and wait_bus = '0')
				) then
				do_cpu <= '1';
			else
				do_cpu <= '0';
			end if;
		end if;
	end process;
	
	release3_p: process(memclk_d, reset, is_bus, chold, csetup)
	begin
		if (reset = '1'
			or chold = '0') then
			wait_setup <= '0';
		elsif (rising_edge(memclk_d)) then
		
			-- first four memclk cycles in phi2 (csetup=1)
			if (is_bus = '1'
				and csetup = '1'
				) then wait_setup <= '1';
			end if;
		end if;
		
		if (reset = '1') then
			wait_bus <= '0';
		elsif (rising_edge(memclk_d)) then
			
			-- memclk cycles after bus setup (csetup=0)
			if (wait_setup = '1') then
				-- wait_setup has taken over
				-- priority over setting it
				wait_bus <= '0';
			elsif (is_bus = '1' 
				and csetup = '0')
				then wait_bus <= '1';
			end if;
		end if;	
	end process;
	
	-- Note if we use phi2 without setting it high on waits (and would use RDY instead), 
	-- the I/O timers will always count on 8MHz - which is not what we want (at 1MHz at least)
	phi2_int <= memclk or not(do_cpu) or ipl;
	
	-- split phi2, stretched phi2 for the CPU to accomodate for waits.
	-- for full speed, don't delay VIA timers
	phi2_out <= phi2_int; -- or wait_bus or wait_setup;
	phi2_io_out <= memclk when mode="11" else
			phi2_int;
	rdy_out <= '1';

	
	-- use a pullup and this mechanism to drive a 5V signal from a 3.3V CPLD
	-- According to UG445 Figure 7: push up until detected high, then let pull up resistor do the rest.
	-- data_to_pin<= data  when ((data and data_to_pin) ='0') else 'Z';	
	phi2 <= phi2_out when ((phi2_out and phi2) = '0') else 'Z';
	phi2_io <= phi2_io_out when ((phi2_io_out and phi2_io) = '0') else 'Z';
		
	------------------------------------------------------
	-- CPU memory mapper
	
	cd_in <= D;
	ca_in <= A;
		
	mappy: Mapper
	port map (
	   ca_in(15 downto 8),
           cd_in,
	   reset,
	   phi2_int,
	   vpa,
	   vda,
	   vpb,
	   rwb,
	   q50m,
           cfgld_in,
	   ma_out,
	   --ma_vout,
	   m_ffsel_out,
	   m_iosel,
	   m_memsel,
	   m_vramsel_out,
	   m_framsel_out,
	   boot,
	   lowbank,
	   vidblock,
	   wp_rom9,
	   wp_romA,
	   wp_romB,
	   wp_romPET,
	   bus_window_9,
	   bus_window_c,
	   forceb0,
	   screenb0
	);

	forceb0 <= '1' when lockb0 = '1' and e = '1' else
		'0';
		
	cfgld_in <= '1' when is8296 = '1' and m_ffsel_out ='1' and ca_in(7 downto 0) = x"F0" else '0';

	-- internal selects
	sel0 <= '1' when m_iosel = '1' and ca_in(7 downto 4) = x"0" else '0';
	sel8 <= '1' when m_iosel = '1' and ca_in(7 downto 4) = x"8" else '0';

	nbussel_p: process(reset, memclk)
	begin
		if (reset = '1') then
			niosel <= '1';
			nmemsel <= '1';
		elsif (falling_edge(memclk)) then
			niosel <= niosel_int
					or wait_bus; 
			nmemsel <= nmemsel_int
					or wait_bus;
		end if;
	end process;
	
	-- external selects are inverted
	niosel_int <= --'0' when extio = '1'			-- external I/O
			--else '1' when ioinh = '1'	-- I/O inhibit
			--else 
			'0' when m_iosel = '1' and not(ca_in(6 downto 4) = "000") 
			else '1';

	nmemsel_int <= not (m_memsel); -- not for now

	is_bus <= not(niosel_int and nmemsel_int);
	
	-------------
	-- CS/A bus
	
	sync <= vda and vpa;

	be_p: process(reset, memclk)
	begin
		if(reset = '1') then
			be_out_int <= '0';
		elsif (rising_edge(memclk)) then
			be_out_int <= not(
				(niosel_int and nmemsel_int) 
				or wait_bus
				or be_in
				);
		end if;
	end process;
	nbe_out <= not( be_out_int );
	nbe_dout <=  not( be_out_int ) or not(phi2_int);
	
	------------------------------------------------------
	-- video
	--
	viccy: Video
	port map (
		va_out,
		cd_in, 
		phi2_int,
		v_dena,
		vsync,
		hsync,
		pet_vsync,
		vis_enable,
		vis_80_in,
		vis_hires_in,
		vgraphic,
		vis_double_in,
		interlace,
		movesync,
		sel8,
		ca_in(0),
		rwb,
		q50m,		-- Q clock (50MHz)
		memclk,		-- sysclk (~8MHz)
		slotclk,
		slot2clk,
		chr_window,
		pxl_window,
		col_window,
		chr_fetch,
		crom_fetch,
		pxl_fetch,
		col_fetch,
		v_ldsync_d,	--sr_load,	-- needed to sync disp_enable with sr_load
		is_vid_out,
		reset
	);

	dena <= not(v_dena);
	
	dbg_out <= not(crom_fetch);
	
	vgraphic <= graphic;
	
	dclk <= not(dotclk) when vis_80_in = '1' else not(dot2clk);
	
	------------------------------------------------------
	-- SPI interface
	
	spi_comp: SPI
	port map (
	   cd_in,
	   spi_dout,
	   ca_in(1 downto 0),
	   rwb,
	   spi_cs,
	   spi_in,
	   spi_outx,
	   spi_clkx,
	   spi_sel,
	   memclk,
	   
	   ipl_state,
	   reset
	);

	-- CPU access to SPI registers
	spi_cs <= To_Std_Logic(sel0 = '1' and ca_in(3) = '1' and ca_in(2) = '0' and phi2_int = '1');
	
	-- SPI serial data in - shared except IN3 for SD card
	spi_in <= spi_in3 when spi_sel = "011" else
			spi_in1;
	
	-- SPI serial data out
	spi_out <= ipl_out	when ipl = '1' 	else
		spi_outx;
	-- SPI serial clock
	spi_clk <= ipl_cnt(0)	when ipl = '1' and ipl_state = '0' else
		spi_clkx;
		
	-- SPI select lines
	-- select flash chip
	nflash <= '1'		when reset = '1' else
			'0' 	when ipl = '1'	else
			'0'	when spi_sel = "001" else
			'1';
		
	spi_nsel2 <= '1'	when reset = '1' else
			'0' 	when spi_sel = "010" else
			'1';
	spi_nsel3 <= '1'	when reset = '1' else
			'0' 	when spi_sel = "011" else
			'1';
	spi_nsel4 <= '1'	when reset = '1' else
			'0' 	when spi_sel = "100" else
			'1';
	spi_nsel5 <= '1'	when reset = '1' else
			'0' 	when spi_sel = "101" else
			'1';
		
	------------------------------------------------------
	-- control registers
	
	Ctrl_P: process(sel0, phi2_int, rwb, reset, ca_in, D)
	begin
		if (reset = '1') then
			vis_hires_in <= '0';
			vis_80_in <= '0';
			vis_enable <= '1';
			vis_double_in <= '0';
			interlace <= '0';
			mode <= "00";
			screenb0 <= '1';
			wp_rom9 <= '0';
			wp_romA <= '0';
			wp_romPET <= '0';
			is8296 <= '0';
			lowbank <= (others => '0');
			vidblock <= (others => '0');
			boot <= '1';
			lockb0 <= '0';
			movesync <= '0';
			bus_window_c <= '0';
			bus_window_9 <= '0';
		elsif (falling_edge(phi2_int) and sel0='1' and rwb='0' and ca_in(3) = '0') then
			-- Write to $E80x
			case (ca_in(2 downto 0)) is
			when "000" =>
				-- video controls
				-- vis_hires_in <= D(0);
				vis_80_in <= D(1);
				screenb0 <= not(D(2));
				vis_double_in <= D(3);
				interlace <= D(4);
				movesync <= D(6);
				vis_enable <= not(D(7));
			when "001" =>
				-- memory map controls
				lockb0 <= D(0);
				boot <= D(1);
				--is8296 <= D(3);
				wp_rom9 <= D(4);
				wp_romA <= D(5);
				wp_romB <= D(6);
				wp_romPET <= D(7);
			when "010" =>
				-- bank controls
				lowbank <= D(3 downto 0);
				vidblock <= D(6 downto 4);
			when "011" =>
				-- speed controls
				mode(1 downto 0) <= D(1 downto 0); -- speed bits
			when "100" =>
				-- bus controls
				bus_window_9 <= D(0);
				bus_window_c <= D(1);
			when others =>
				null;
			end case;
		end if;
	end process;


	v_out_p: process(q50m, memclk, VA_select, ipl, nvramsel_int, nframsel_int, ipl, reset,
			chr_fetch, crom_fetch, pxl_fetch, col_fetch, is_vid_out,
			memclk_dd)
	begin
		if (reset = '1') then
			pxlld 		<= '0';
			ramrwb_int	<= '1';
			memclk_d	<= '0';
			memclk_ddd	<= '0';
			v_ldsync 	<= '0';
		elsif (rising_edge(q50m)) then
			pxlld 		<= not(memclk) or not(chr_fetch or pxl_fetch);
			v_ldsync	<= not(memclk) or not (col_fetch);
	
			memclk_d <= memclk;
			memclk_ddd <= memclk_dd;
			
			nframsel <= nframsel_int;
			nvramsel <= nvramsel_int;

			if (ipl = '1') then
				VA_select <= VRA_IPL;
			elsif (crom_fetch = '1') then
				-- when crom_fetch is set, pxl_fetch is also set, so this must be first
				VA_select <= VRA_CHRROM;
			elsif (chr_fetch = '1' or pxl_fetch = '1' or col_fetch = '1') then
				VA_select <= VRA_VIDEO;
			else
				VA_select <= VRA_CPU;
			end if;
			
			if (ipl = '1') then
				ramrwb_int <= '0';	-- IPL load writes data to RAM
			elsif (is_vid_out = '1') then
				ramrwb_int <= '1';	-- video only reads
			elsif (m_vramsel_out = '0') then
				ramrwb_int <= '1';	-- not selected
			elsif (memclk = '0') then
				ramrwb_int <= rwb;
			end if;
			
		end if;

		-- keep VA, ramrwb etc stable one half qclk cycle after
		-- de-select.
		if (reset = '1') then
			VA 		<= (others => 'Z');
			ramrwb		<= '1';
			nchromaddr	<= '0';
			memclk_dd	<= '0';
			v_ldsync_d 	<= '0';
		elsif (falling_edge(q50m)) then
		
			-- RAM R/W (only for video RAM, FRAM gets /WE from CPU's RWB)
			ramrwb <= ramrwb_int; 

			memclk_dd <= memclk_d;

			v_ldsync_d 	<= v_ldsync;

			case (VA_select) is
			when VRA_IPL =>
				nchromaddr <= '1';
				VA(7 downto 0) <= ipl_cnt(11 downto 4);
				VA(18 downto 8) <= ipl_addr(18 downto 8);
			when VRA_CPU =>
				nchromaddr <= '1';
				VA(7 downto 0) <= ca_in (7 downto 0);
				VA(11 downto 8) <= ma_out (11 downto 8);
				VA(13 downto 12) <= ma_out (13 downto 12);
				VA(18 downto 14) <= ma_out (18 downto 14);
				--VA(18 downto 8) <= "00011111111";
			when VRA_VIDEO =>  
				nchromaddr <= '1';
				VA(15 downto 0) <= va_out(15 downto 0);
				VA(18 downto 16) <= (others => '0');
			when VRA_CHRROM =>  
				nchromaddr <= '0';  -- provide VA(11 downto 4) via HW latch
				VA(3 downto 0) <= va_out(3 downto 0);
				VA(11 downto 4) <= (others => 'Z');
				VA(15 downto 12) <= va_out(15 downto 12);
				VA(18 downto 16) <= (others => '0');
			when others =>
				VA 	<= (others => 'Z');
			end case;
		end if;
	end process;
	
	colorld <= v_ldsync;
	nsrload <= v_ldsync;
				
	FA(19 downto 16) <= 	ma_out(19 downto 16);
	FA(15) <=		ma_out(15);
			
	-- data transfer between CPU data bus and video/memory data bus
	
	VD <= 	spi_dout	when ipl = '1' 		else	-- IPL
		D 		when VA_select = VRA_CPU and ramrwb_int = '0'	else	-- CPU write
		(others => 'Z');
		
	D <= 	VD when VA_select = VRA_CPU
		--x"EA" when is_vid_out='0'	-- NOP sled
			and rwb='1' 
			and m_vramsel_out ='1' 
			and phi2_int='1' 
			and is_cpu='1' 	-- do not bleed video access into system bus when waiting but breaks timing
		else
		spi_dout when spi_cs = '1'
			and rwb = '1'
		else
			(others => 'Z');
		
	-- select RAM
	
	nframsel_int <= '1'	when memclk = '0' else
			'0'	when m_framsel_out = '1' else
			'1';
	
	-- memclk changes at falling edge
	nvramsel_int <= ipl_cnt(0) when ipl = '1' else	-- IPL loads data into RAM
			'1'	when memclk = '0' else	-- inactive after previous access
			'0' 	when is_vid_out='1' else
			'1' 	when wait_int = '1' else
			not(m_vramsel_out);
	
	------------------------------------------------------
	-- IPL logic
	
	ipl_p: process(memclk, reset, ipl)
	begin
		if (reset = '1') then 
			ipl_state <= '0';
			ipl_cnt <= (others => '0');
			ipl <= '1';
		elsif (falling_edge(memclk) and ipl_d = '1') then
		
			--ipl <= '0';	-- block IPL to test
			
			if (ipl_state_d = '0') then
				-- initial count and SPI Flash read command
				
				if (ipl_next = '1') then
					ipl_state <= '1';
					ipl_cnt <= (others => '0');
				else
					ipl_cnt <= ipl_cnt + 1;
				end if;
			else
				-- read block
				if (ipl_next = '1') then
					ipl <= '0';
					ipl_state <= '0';
				else
					ipl_cnt <= ipl_cnt + 1;
				end if;
			end if;
		end if;
	end process;
	
	ipl_state_p: process(reset, memclk, ipl_state)
	begin
		if (reset = '1') then
			ipl_state_d <= '0';
			ipl_next <= '0';
			ipl_out <= '0';
			ipl_d <= '1';
		elsif (rising_edge(memclk)) then
			ipl_state_d <= ipl_state;
			ipl_d <= ipl;
			
			ipl_next <= '0';
			if (ipl_state = '0') then
				if (ipl_cnt = "000001000000") then
					ipl_next <= '1';
				end if;
				
				if (ipl_cnt >= "000000001011"
					and ipl_cnt <= "000000001110"
					) then
					ipl_out <= '1';
				else
					ipl_out <= '0';
				end if;

			else
				if (ipl_cnt = "111111111111") then
					ipl_next <= '1';
				end if;
				
				ipl_out <= '0';
			end if;
		end if;
	end process;


end Behavioral;

