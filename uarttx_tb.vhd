--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:22:27 10/27/2012
-- Design Name:   
-- Module Name:   /home/jw/projects/xilinx/fpgavr/uarttx_tb.vhd
-- Project Name:  fpgavr
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: uarttx
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
 
ENTITY uarttx_tb IS
END uarttx_tb;
 
ARCHITECTURE behavior OF uarttx_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT uarttx
    PORT(
         tx : OUT  std_logic;
         strobe : IN  std_logic;
         data : IN  std_logic_vector(7 downto 0);
         busy : OUT  std_logic;
         clk : IN  std_logic;
         rst : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal strobe : std_logic := '0';
   signal data : std_logic_vector(7 downto 0) := (others => '0');
   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

 	--Outputs
   signal tx : std_logic;
   signal busy : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: uarttx PORT MAP (
          tx => tx,
          strobe => strobe,
          data => data,
          busy => busy,
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

      wait for clk_period*10;

		data <= "10010111";
		strobe <= '1';
      wait for clk_period;
		strobe <= '0';

      wait;
   end process;

END;
