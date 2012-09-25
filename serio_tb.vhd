-- This is free and unencumbered software released into the public domain.
--
-- Anyone is free to copy, modify, publish, use, compile, sell, or
-- distribute this software, either in source code form or as a compiled
-- binary, for any purpose, commercial or non-commercial, and by any
-- means.
--
-- In jurisdictions that recognize copyright laws, the author or authors
-- of this software dedicate any and all copyright interest in the
-- software to the public domain. We make this dedication for the benefit
-- of the public at large and to the detriment of our heirs and
-- successors. We intend this dedication to be an overt act of
-- relinquishment in perpetuity of all present and future rights to this
-- software under copyright law.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
-- OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
-- OTHER DEALINGS IN THE SOFTWARE.
--
-- For more information, please refer to <http://unlicense.org/>

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
