library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all ;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.synchronizer_pkg.all;
use work.uartrx_pkg.all;
use work.readfsm_pkg.all;
use work.dispatch_pkg.all;
use work.fsm_stktx_pkg.all;
use work.uarttx_pkg.all;

entity main is
	Port (
		RxD : IN STD_LOGIC;
		TxD : OUT STD_LOGIC;
		MISO : IN STD_LOGIC;
		MOSI : OUT STD_LOGIC;
		SCK : OUT STD_LOGIC;
		RST : IN STD_LOGIC;
		CLK : in  STD_LOGIC;
		LED : OUT STD_LOGIC_VECTOR(7 downto 0) );
end main;

architecture Behavioral of main is
	-- uartrx
	signal urdata : std_logic_vector(7 downto 0);
	signal urstrobe : std_logic;

	-- readfsm
	signal rdaddr : std_logic_vector(10 downto 0);
	signal rddata : std_logic_vector(7 downto 0);
	signal rdstrobe : std_logic;

	-- dispatch
	signal dtaddr : std_logic_vector(10 downto 0);
	signal dtdata : std_logic_vector(7 downto 0);
	signal dtwr : std_logic;
	signal dtstrobe : std_logic;
	signal dtbusy : std_logic;

	-- fsm_stktx
	signal tudata : std_logic_vector(7 downto 0);
	signal tustrobe : std_logic;
	signal tubusy : std_logic;

	-- uarttx
	signal rxfrerror : std_logic;
	signal readfsmerr : std_logic;
	signal readtokenerr : std_logic;
	signal dispatcherr : std_logic;
	signal dispatchbusy : std_logic;

	-- synchronizers
	signal syncrx, syncmiso : std_logic;

begin

	led(7) <= tubusy;
	led(6) <= dtbusy;
	led(5) <= '0';
	led(0) <= rxfrerror;
	led(1) <= readfsmerr;
	led(2) <= dispatcherr;
	led(3) <= dispatchbusy;
	led(4) <= readtokenerr;

	u0 : synchronizer port map(RxD, syncrx, CLK, RST);
	u1 : uartrx port map (syncrx, urstrobe, urdata, rxfrerror, CLK, RST);
	u2 : readfsm port map(urstrobe, urdata, rdaddr, rddata, rdstrobe, readfsmerr, readtokenerr, CLK, RST);
	u3 : dispatch port map(rdaddr, rddata, rdstrobe, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, syncmiso, MOSI, SCK, dispatcherr, dispatchbusy, CLK, RST);
	u7 : synchronizer port map(MISO, syncmiso, CLK, RST);
	u4 : fsm_stktx port map(tustrobe, tudata, tubusy, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, CLK, RST);
	u5 : uarttx port map(TxD, tustrobe, tudata, tubusy, CLK, RST);

end Behavioral;
