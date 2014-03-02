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
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;

ENTITY uartrx_tb IS
END uartrx_tb;

ARCHITECTURE behavior OF uartrx_tb IS

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
	signal finished : std_logic := '0';

	signal baudclk : std_logic := '0';
	signal run : std_logic := '0';

	-- Test vector
	type char_array is array (integer range<>) of std_logic_vector(7 downto 0);
	constant STRLEN : integer := 3;
	constant TEST : char_array(0 to STRLEN-1) := (x"41", x"00", x"ff");
	signal current : std_logic_vector(7 downto 0);

	signal strobed : std_logic;
	signal srst : std_logic := '1';

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : entity work.uartrx PORT MAP (
		rx => rx,
		strobe => strobe,
		data => data,
		ferror => ferror,
		clk => clk,
		rst => rst
	);

	-- Clock process definitions
	clk <= not clk after clk_period/2 when finished /= '1' else '0';
	baudclk <= not baudclk after baud_period/2 when run = '1' else '0';

	-- Strobe detection
	strobedet_proc : process(rst,clk)
	begin
		if srst = '1' then
			strobed <= '0';
		elsif rising_edge(clk) then
			if strobe = '1' then
				strobed <= '1';
			end if;
		end if;
	end process;

	-- Stimulus process
	stim_proc: process
	begin
		-- hold reset state for 100 ns.
		wait for 100 ns;
		wait until falling_edge(clk);
		rst <= '0';
		srst <= '0';
		wait for clk_period*2;
		wait until falling_edge(clk);

		-- Test a few specific values. Neccessary, considering below?
		for B in 0 to STRLEN-1 loop
			-- Single byte transmission
			current <= TEST(B);
			run <= '1';
			rx <= '0';
			wait for baud_period;
			for I in 0 to 7 loop
				rx <= current(I);
				wait for baud_period;
			end loop;
			rx <= '1';
			wait for baud_period;
			run <= '0';
			-- Check output data and strobe
			wait for clk_period;
			wait until rising_edge(clk);
			assert data = current report "Mismatch between transmitted and received data" severity error;
			assert ferror = '0' report "Framing error reported where there is none" severity error;
			assert strobed = '1' report "Strobe did not fire" severity error;
			assert data /= current report "Byte was correctly received" severity note;
			-- Extra pause
			srst <= '1';
			wait for baud_period * 3;
			srst <= '0';
		end loop;

		-- Test a framing error
		current <= "10000011";
		run <= '1';
		rx <= '0';
		wait for baud_period;
		for I in 0 to 7 loop
			rx <= current(I);
			wait for baud_period;
		end loop;
		rx <= '0';  -- ERROR!
		wait for baud_period;
		run <= '0';
		-- Check output data, strobe and error
		wait for clk_period;
		wait until rising_edge(clk);
		assert ferror = '1' report "Framing error sent, not reported" severity error;
		assert strobed = '1' report "Strobe did not fire" severity error;
		assert ferror /= '1' report "Framing error correctly detected" severity note;
		-- Extra pause
		wait for baud_period * 3;
		rx <= '1';

		-- Reset again
		rst <= '1';
		srst <= '1';
		wait for clk_period * 2;
		rst <= '0';
		srst <= '0';
		wait for clk_period*2;
		wait until falling_edge(clk);
		assert ferror = '0' report "Reset was not sucessful, ferror /= '0'" severity error;
		assert strobe = '0' report "Reset was not sucessful, strobe /= '0'" severity error;
		assert strobed = '0' report "Reset was not sucessful, strobed /= '0'" severity error;

		-- Test all 8-bit values
		for B in 0 to 255 loop
			-- Single byte transmission
			current <= std_logic_vector(to_unsigned(B,8));
			run <= '1';
			rx <= '0';
			wait for baud_period;
			for I in 0 to 7 loop
				rx <= current(I);
				wait for baud_period;
			end loop;
			rx <= '1';
			wait for baud_period;
			run <= '0';
			-- Check output data and strobe
			wait for clk_period;
			wait until rising_edge(clk);
			assert data = current report "Mismatch between transmitted and received data" severity error;
			assert ferror = '0' report "Framing error reported where there is none" severity error;
			assert strobed = '1' report "Strobe did not fire" severity error;
			-- Extra pause
			srst <= '1';
			wait for baud_period * 3;
			srst <= '0';
		end loop;

		finished <= '1';
		rst <= '1';
		assert false report "Testbench complete" severity note;

	end process;

END;
