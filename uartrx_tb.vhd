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
 
ENTITY uartrx_tb IS
END uartrx_tb;
 
ARCHITECTURE behavior OF uartrx_tb IS 
 
	component uartrx
		Port (
			rx     : in std_logic;
			strobe : out std_logic;
			data   : out std_logic_vector(7 downto 0);
			ferror : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;

	--Inputs
	signal rx : std_logic := '1';
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

 	--Outputs
	signal strobe : std_logic;
	signal data   : std_logic_vector(7 downto 0);
	signal ferror : std_logic;

	-- Clock period definitions
	constant clk_period : time := 10 ns;
	constant baud_period : time := 8.6805555555 us;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	uut: uartrx PORT MAP (
		rx => rx,
		strobe => strobe,
		data => data,
		ferror => ferror,
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

		wait for 10*clk_period;

		rx <= '0';  -- Start
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '0';
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '0';
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '0';
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '1';  -- Stop
		wait for baud_period;

		-- Framing error
		rx <= '0';  -- Start
		wait for baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '0';
		wait for 6*baud_period;
		rx <= '1';
		wait for baud_period;
		rx <= '0';  -- Stop
		wait for baud_period;

		wait;
	end process;

END;
