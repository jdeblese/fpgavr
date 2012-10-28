--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   22:03:36 10/27/2012
-- Design Name:   
-- Module Name:   /home/jw/projects/xilinx/fpgavr/main_tb.vhd
-- Project Name:  fpgavr
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: main
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY main_tb IS
END main_tb;
 
ARCHITECTURE behavior OF main_tb IS 

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
	signal dispatcherr : std_logic;

	signal RxD : std_logic := '1';
	signal TxD : std_logic;
 
   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

   -- Clock period definitions
   constant clk_period : time := 10 ns;

   constant baud_period : time := 8.681 us;
 
BEGIN
 
	u1 : uartrx port map (RxD, urstrobe, urdata, rxfrerror, CLK, RST);
	u2 : readfsm port map(urstrobe, urdata, rdaddr, rddata, rdstrobe, readfsmerr, CLK, RST);
	u3 : dispatch port map(rdaddr, rddata, rdstrobe, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, dispatcherr, CLK, RST);
	u4 : fsm_stktx port map(tustrobe, tudata, tubusy, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, CLK, RST);
	u5 : uarttx port map(TxD, tustrobe, tudata, tubusy, CLK, RST);

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	
		
		rst <= '0';

      wait for clk_period*10;

	  RxD <= '0';  -- Transmit x1B
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit xFF (seq)
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit x00
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit x01
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit x0e
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit x01
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

	  RxD <= '0';  -- Transmit x15
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '0';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1';
	  wait for baud_period;
	  RxD <= '1'; -- Stop bit
	  wait for baud_period;

      wait;
   end process;

END;
