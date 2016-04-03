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
 
ENTITY main_tb2 IS
END main_tb2;
 
ARCHITECTURE behavior OF main_tb2 IS 

	component main is
		Port (
			RxD : IN STD_LOGIC;
			TxD : OUT STD_LOGIC;
			RST : IN STD_LOGIC;
			CLK : in  STD_LOGIC;
			LED : OUT STD_LOGIC_VECTOR(7 downto 0) );
	end component;


	signal RxD : std_logic := '1';
	signal TxD : std_logic;
	signal LED : std_logic_vector(7 downto 0);
 
   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

   -- Clock period definitions
   constant clk_period : time := 10 ns;

   constant baud_period : time := 8.681 us;
 
BEGIN
 
	u1 : main port map (RxD, TxD, RST, CLK, LED);

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

	  wait for baud_period*100;

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
