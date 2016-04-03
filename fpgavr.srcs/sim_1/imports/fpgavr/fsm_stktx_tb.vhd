--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   22:03:36 10/27/2012
-- Design Name:   
-- Module Name:   /home/jw/projects/xilinx/fpgavr/fsm_stktx_tb.vhd
-- Project Name:  fpgavr
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: fsm_stktx
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
 
ENTITY fsm_stktx_tb IS
END fsm_stktx_tb;
 
ARCHITECTURE behavior OF fsm_stktx_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT fsm_stktx
    PORT(
         uart_strobe : OUT  std_logic;
         uart_data : OUT  std_logic_vector(7 downto 0);
         uart_busy : IN  std_logic;
         buffer_addr : IN  std_logic_vector(10 downto 0);
         buffer_data : IN  std_logic_vector(7 downto 0);
         buffer_wren : IN  std_logic;
         strobe : IN  std_logic;
         busy : OUT  std_logic;
         clk : IN  std_logic;
         rst : IN  std_logic
        );
    END COMPONENT;

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
   signal buffer_addr : std_logic_vector(10 downto 0) := (others => '0');
   signal buffer_data : std_logic_vector(7 downto 0) := (others => '0');
   signal buffer_wren : std_logic := '0';
   signal strobe : std_logic := '0';
   signal clk : std_logic := '0';
   signal rst : std_logic := '1';

 	--Intermediates
   signal uart_strobe : std_logic;
   signal uart_data : std_logic_vector(7 downto 0);
   signal uart_busy : std_logic;

 	--Outputs
   signal tx : std_logic;
   signal fsm_busy : std_logic;
    
   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut1: fsm_stktx PORT MAP (
          uart_strobe => uart_strobe,
          uart_data => uart_data,
          uart_busy => uart_busy,
          buffer_addr => buffer_addr,
          buffer_data => buffer_data,
          buffer_wren => buffer_wren,
          strobe => strobe,
          busy => fsm_busy,
          clk => clk,
          rst => rst
        );

   -- Instantiate the Unit Under Test (UUT)
   uut2: uarttx PORT MAP (
          tx => tx,
          strobe => uart_strobe,
          data => uart_data,
          busy => uart_busy,
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

		buffer_addr <= "000" & X"00";
		buffer_data <= X"04";
		buffer_wren <= '1';		
      wait for clk_period;
		buffer_addr <= "000" & X"01";
		buffer_data <= X"00";
		buffer_wren <= '1';		
      wait for clk_period;
		buffer_addr <= "000" & X"02";
		buffer_data <= X"02";
		buffer_wren <= '1';		
      wait for clk_period;
		buffer_addr <= "000" & X"03";
		buffer_data <= X"80";
		buffer_wren <= '1';		
      wait for clk_period;
		buffer_addr <= "000" & X"04";
		buffer_data <= X"AA";
		buffer_wren <= '1';
      wait for clk_period;
		buffer_wren <= '0';
		strobe <= '1';
      wait for clk_period;
		strobe <= '0';

      wait;
   end process;

END;
