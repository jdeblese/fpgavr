library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all ;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity main is
	Port (
		RxD : IN STD_LOGIC;
		TxD : OUT STD_LOGIC;
		RST : IN STD_LOGIC;
		CLK : in  STD_LOGIC;
		LED : OUT STD_LOGIC_VECTOR(7 downto 0) );
end main;

architecture Behavioral of main is
	component uartrx
		Port (
			rx     : in std_logic;
			strobe : out std_logic;
			data   : out std_logic_vector(7 downto 0);
			ferror : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;

	signal urdata : std_logic_vector(7 downto 0);
	signal urstrobe : std_logic;

	component readfsm is
		Port (
			uart_strobe : in std_logic;
			uart_data : in std_logic_vector(7 downto 0);
			ringaddr : in std_logic_vector(10 downto 0);
			ringdata : out std_logic_vector(7 downto 0);
			cmdstrobe : out std_logic;
			readerr : out std_logic;
			tokenerr : out std_logic;
			clk      : in STD_LOGIC;
			rst      : in STD_LOGIC);
	end component;

	signal rdaddr : std_logic_vector(10 downto 0);
	signal rddata : std_logic_vector(7 downto 0);
	signal rdstrobe : std_logic;

	component dispatch is
		Port (
			ringaddr  : out std_logic_vector(10 downto 0);
			ringdata  : in std_logic_vector(7 downto 0);
			cmdstrobe : in std_logic;
			txaddr    : out std_logic_vector(10 downto 0);
			txdata    : out std_logic_vector(7 downto 0);
			txwr      : out std_logic;
			txstrobe  : out std_logic;
			txbusy    : in  std_logic;
			procerr   : out std_logic;
			clk      : in STD_LOGIC;
			rst      : in STD_LOGIC);
	end component;

	signal dtaddr : std_logic_vector(10 downto 0);
	signal dtdata : std_logic_vector(7 downto 0);
	signal dtwr : std_logic;
	signal dtstrobe : std_logic;
	signal dtbusy : std_logic;

	COMPONENT fsm_stktx
	PORT(
		 uart_strobe : OUT  std_logic;
		 uart_data   : OUT  std_logic_vector(7 downto 0);
		 uart_busy   : IN  std_logic;
		 buffer_addr : IN  std_logic_vector(10 downto 0);
		 buffer_data : IN  std_logic_vector(7 downto 0);
		 buffer_wren : IN  std_logic;
		 strobe : IN  std_logic;
		 busy   : OUT  std_logic;
		 clk : IN  std_logic;
		 rst : IN  std_logic
		);
	END COMPONENT;

	signal tudata : std_logic_vector(7 downto 0);
	signal tustrobe : std_logic;
	signal tubusy : std_logic;

	component uarttx
		Port (
			tx     : out std_logic;
			strobe : in std_logic;
			data   : in std_logic_vector(7 downto 0);
			busy   : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;

	signal rxfrerror : std_logic;
	signal readfsmerr : std_logic;
	signal readtokenerr : std_logic;
	signal dispatcherr : std_logic;

begin

	led(7) <= tubusy;
	led(6) <= dtbusy;
	led(5 downto 4) <= (others => '0');
	led(0) <= rxfrerror;
	led(1) <= readfsmerr;
	led(2) <= dispatcherr;
	led(3) <= readtokenerr;

	u1 : uartrx port map (RxD, urstrobe, urdata, rxfrerror, CLK, RST);
	u2 : readfsm port map(urstrobe, urdata, rdaddr, rddata, rdstrobe, readfsmerr, readtokenerr, CLK, RST);
	u3 : dispatch port map(rdaddr, rddata, rdstrobe, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, dispatcherr, CLK, RST);
	u4 : fsm_stktx port map(tustrobe, tudata, tubusy, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, CLK, RST);
	u5 : uarttx port map(TxD, tustrobe, tudata, tubusy, CLK, RST);

end Behavioral;
