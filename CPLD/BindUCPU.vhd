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

entity BindUCPU is
    Port ( 
	-- clock
	   q50m : in std_logic;
	   nres : in std_logic;
		nirq : out std_logic;
	
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
	   rdy : in std_logic;
           phi2 : out  STD_LOGIC;	-- with pull-up to go to 5V
	   vpb : in std_logic;
	   e : in std_logic;
	   mlb: in std_logic;
	   --mx : in std_logic;

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
	   
	-- V/RAM interface
	   VA : out std_logic_vector (18 downto 0);	-- 512k
	   FA : out std_logic_vector (19 downto 15);	-- 512k, mappable in 32k blocks
	   VD : inout std_logic_vector (7 downto 0);
	   
	   nvramsel : out STD_LOGIC;
	   nframsel : out STD_LOGIC;
	   ramrwb : out std_logic;
	   
      vsync : out  STD_LOGIC;
      hsync : out  STD_LOGIC;
	   pet_vsync: out std_logic;

		pxl_out: out std_logic_vector(3 downto 0);
	   
	-- SPI
	   spi_out : out std_logic;
	   spi_clk : out std_logic;
	   -- MISO
	   spi_in1  : in std_logic;
	   spi_in3  : in std_logic;
	   -- selects
		spi_sela : out std_logic;
		spi_selb : out std_logic;
		spi_selc : out std_logic;
			   
	-- Audio / DAC output
		spi_naudio : out std_logic;
		spi_aclk : out std_logic;
		spi_amosi : out std_logic;
		nldac : out std_logic
				
	-- debug
		--dbg: in std_logic
	 );
	 attribute system_jitter: string;
	 attribute system_jitter of q50m: signal is "10 ps";
	 attribute maxskew: string;
	 attribute maxskew of q50m : signal is "3 ns";
	 attribute maxdelay: string;
	 attribute maxdelay of q50m : signal is "3 ns";
end BindUCPU;

architecture Behavioral of BindUCPU is

	
    component Top is
    Port ( 
	-- clock
	   q50m : in std_logic;
	   nres : in std_logic;
		nirq : out std_logic;
	
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
	   rdy : in std_logic;
           phi2 : out  STD_LOGIC;	-- with pull-up to go to 5V
	   vpb : in std_logic;
	   e : in std_logic;
	   mlb: in std_logic;
	   --mx : in std_logic;

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
	   
	-- PETIO
		sel1: out std_logic;
		sel2: out std_logic;
		sel4: out std_logic;

	-- V/RAM interface
	   VA : out std_logic_vector (18 downto 0);	-- 512k
	   FA : out std_logic_vector (19 downto 15);	-- 512k, mappable in 32k blocks
	   VD : inout std_logic_vector (7 downto 0);
	   
	   nvramsel : out STD_LOGIC;
	   nframsel : out STD_LOGIC;
	   ramrwb : out std_logic;
	   
      vsync : out  STD_LOGIC;
      hsync : out  STD_LOGIC;
	   pet_vsync: out std_logic;

		pxl_out: out std_logic_vector(7 downto 0);
	   
	-- SPI
	   spi_out : out std_logic;
	   spi_clk : out std_logic;
	   -- MISO
	   spi_in1  : in std_logic;
	   spi_in3  : in std_logic;
	   -- selects
		spi_sela : out std_logic;
		spi_selb : out std_logic;
		spi_selc : out std_logic;
			   
	-- Audio / DAC output
		spi_naudio : out std_logic;
		spi_aclk : out std_logic;
		spi_amosi : out std_logic;
		nldac : out std_logic
				
	-- debug
		--dbg: in std_logic
	 );
	end component;
	   
	signal sel1: std_logic;
	signal sel2: std_logic;
	signal sel4: std_logic;
	signal v_out: std_logic_vector(7 downto 0);
	
begin


	core: Top
	port map (
	-- clock
	   q50m ,
	   nres ,
		nirq ,
	
	   -- CS/A out bus timing
	   c8phi2	,
	   c2phi2	,
	   cphi2	,

	-- config
	   graphic,
	   
	-- CPU interface
	   A ,
           D ,
           vda ,
           vpa ,
	   rwb ,
	   rdy ,
           phi2 ,
	   vpb ,
	   e ,
	   mlb,
	   --mx ,

	-- bus
	-- ROM, I/O (on CPU bus)	   
	   sync ,
	   nmemsel,
	   niosel,
	   extio,
	   ioinh,
	   nbe_out ,
	   nbe_dout ,
	   be_in,
		
	-- PETIO
		sel1,
		sel2,
		sel4,
		
	-- V/RAM interface
	   VA ,
	   FA ,
	   VD ,
	   
	   nvramsel ,
	   nframsel ,
	   ramrwb ,
	   
      vsync ,
      hsync ,
	   pet_vsync,

		v_out,
	   
	-- SPI
	   spi_out ,
	   spi_clk ,
	   -- MISO
	   spi_in1  ,
	   spi_in3  ,
	   -- selects
	spi_sela ,
		spi_selb ,
		spi_selc ,
			   
	-- Audio / DAC output
		spi_naudio ,
		spi_aclk ,
		spi_amosi ,
		nldac 
				
	);

	pxl_out(3) <= v_out(7);
	pxl_out(2) <= v_out(4);
	pxl_out(1) <= v_out(1);
	pxl_out(0) <= v_out(0) or v_out(3) or v_out(6);

	end Behavioral;
