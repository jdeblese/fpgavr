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

use work.synchronizer_pkg.all;
use work.uartrx_pkg.all;
use work.readfsm_pkg.all;
--use work.dispatch_pkg.all;
use work.fsm_stktx_pkg.all;
use work.uarttx_pkg.all;
 
ENTITY main_tb IS
END main_tb;
 
ARCHITECTURE behavior OF main_tb IS 

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

	-- other
	signal RxD : std_logic := '1';
	signal TxD : std_logic;
 
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	-- Clock period definitions
	constant clk_period : time := 10 ns;

	constant baud_period : time := 8.681 us;
 
BEGIN
 
	u1 : uartrx port map (RxD, urstrobe, urdata, rxfrerror, CLK, RST);
	u2 : readfsm port map(urstrobe, urdata, rdaddr, rddata, rdstrobe, readfsmerr, readtokenerr, CLK, RST);
--	u3 : dispatch port map(rdaddr, rddata, rdstrobe, dtaddr, dtdata, dtwr, dtstrobe, dtbusy, dispatcherr, dispatchbusy, CLK, RST);
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

	  RxD <= '0';  -- Transmit x1B, message start
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

	  RxD <= '0';  -- Transmit xFF, sequence number
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

	  RxD <= '0';  -- Transmit x00, message size msB
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

	  RxD <= '0';  -- Transmit x01, message size lsB
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

	  RxD <= '0';  -- Transmit x0e, token
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

	  RxD <= '0';  -- Transmit x01, message body
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

	  RxD <= '0';  -- Transmit xEA, checksum
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

	  wait for baud_period*100;

      -- Set polarity: 0x1b 0x0b 0x00 0x03 0x0e 0x02 0x9e 0x01 0x80

	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '0'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;
	  RxD <= '1'; wait for baud_period;

      wait;
   end process;

END;
