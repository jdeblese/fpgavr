--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   21:31:40 09/11/2012
-- Design Name:   
-- Module Name:   /home/jw/projects/xilinx/fpgavr/serio_tb.vhd
-- Project Name:  fpgavr
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: serio
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
 
ENTITY serio_tb IS
END serio_tb;
 
ARCHITECTURE behavior OF serio_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT serio
    PORT(
         MISO : IN  std_logic;
         MOSI : OUT  std_logic;
         SCK : OUT  std_logic;
         tx : IN  std_logic_vector(7 downto 0);
         rx : OUT  std_logic_vector(7 downto 0);
         txstrobe : IN  std_logic;
         rxstrobe : OUT  std_logic;
         clk : IN  std_logic;
         rst : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal MISO : std_logic := '0';
   signal tx : std_logic_vector(7 downto 0) := (others => '0');
   signal txstrobe : std_logic := '0';
   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

 	--Outputs
   signal MOSI : std_logic;
   signal SCK : std_logic;
   signal rx : std_logic_vector(7 downto 0);
   signal rxstrobe : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: serio PORT MAP (
          MISO => MISO,
          MOSI => MOSI,
          SCK => SCK,
          tx => tx,
          rx => rx,
          txstrobe => txstrobe,
          rxstrobe => rxstrobe,
          clk => clk,
          rst => rst
        );

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

      wait for 100*clk_period;
      MISO <= '1';
      wait for 100*clk_period;

      wait for 23*clk_period;
      tx <= "10010011";
      txstrobe <= '1';
      wait for clk_period;
      tx <= (others => '0');
      txstrobe <= '0';
      wait for 76*clk_period;

      wait for 100*clk_period;
      MISO <= '0';

      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 100*clk_period;
      wait for 22*clk_period;
      txstrobe <= '1';
      wait for clk_period;
      txstrobe <= '0';
      wait for 77*clk_period;
      -- insert stimulus here 

      wait;
   end process;

END;
