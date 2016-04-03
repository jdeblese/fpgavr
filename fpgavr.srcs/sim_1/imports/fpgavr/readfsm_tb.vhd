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

use work.stk500def.all;

ENTITY readfsm_tb IS
END readfsm_tb;

ARCHITECTURE behavior OF readfsm_tb IS

	--Inputs
	signal ustrobe : std_logic := '0';
	signal udata   : std_logic_vector(7 downto 0) := (others => '0');
	signal raddr   : std_logic_vector(10 downto 0) := (others => '0');
	signal clk     : std_logic := '0';
	signal rst     : std_logic := '1';

 	--Outputs
	signal rdata   : std_logic_vector(7 downto 0);
	signal cstrobe : std_logic;
	signal rerror  : std_logic;
	signal terror  : std_logic;

	-- Clock period definitions
	constant clk_period : time := 10 ns;
	signal finished : std_logic := '0';

	-- Test data
	signal msgsize : std_logic_vector(15 downto 0);
	signal cksum : std_logic_vector(7 downto 0);
	signal sequence : std_logic_vector(7 downto 0);
	signal current : std_logic_vector(7 downto 0);

	signal strobed : std_logic;
	signal srst : std_logic := '1';

BEGIN

	-- Instantiate the Unit Under Test (UUT)
	uut : entity work.readfsm PORT MAP (
		uart_strobe => ustrobe,
		uart_data => udata,
		ringaddr => raddr,
		ringdata => rdata,
		cmdstrobe => cstrobe,
		readerr => rerror,
		tokenerr => terror,
		debug => open,
		clk => clk,
		rst => rst
	);

	-- Clock process definitions
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	-- Strobe detection
	strobedet_proc : process(rst,clk)
	begin
		if srst = '1' then
			strobed <= '0';
		elsif rising_edge(clk) then
			if cstrobe = '1' then
				strobed <= '1';
			end if;
		end if;
	end process;

	-- Stimulus process
	stim_proc: process
		variable tmpbyte : std_logic_vector(7 downto 0);
		variable intsize : integer;
	begin
		-- hold reset state for 100 ns.
		wait for 100 ns;
		wait until falling_edge(clk);
		rst <= '0';
		srst <= '0';
		wait for clk_period*2;

		-- Transmit a valid packet at maximum speed
		sequence <= X"40";
		intsize := 258;
		msgsize <= std_logic_vector(to_unsigned(intsize, 16));  -- why not msgsize'range?
		wait until rising_edge(clk);
		ustrobe <= '1';
		udata <= MESSAGE_START;
		cksum <= MESSAGE_START;
		wait until rising_edge(clk);
		udata <= sequence;
		cksum <= cksum xor sequence;
		wait until rising_edge(clk);
		udata <= msgsize(15 downto 8);
		cksum <= cksum xor msgsize(15 downto 8);
		wait until rising_edge(clk);
		udata <= msgsize(7 downto 0);
		cksum <= cksum xor msgsize(7 downto 0);
		wait until rising_edge(clk);
		udata <= TOKEN;
		cksum <= cksum xor TOKEN;
		wait until rising_edge(clk);
		for byte in 0 to intsize-1 loop
			tmpbyte := std_logic_vector(to_unsigned(byte, 8));
			udata <= tmpbyte;
			cksum <= cksum xor tmpbyte;
			wait until rising_edge(clk);
		end loop;
		udata <= cksum;
		wait until rising_edge(clk);
		ustrobe <= '0';
		assert strobed = '0' report "Strobe should not have fired yet" severity error;
		wait until rising_edge(clk);
		srst <= '1';
		assert cstrobe = '1' report "Strobe did not fire" severity error;
		wait until rising_edge(clk);
		srst <= '0';
		assert cstrobe = '0' report "Strobe fired for more than 1 clock edge" severity error;

		-- Verify the stored packet
		raddr <= "000" & x"00";
		wait until falling_edge(clk);
		assert rdata = sequence report "Saved sequence number doesn't match" severity error;

		raddr <= "000" & x"01";
		wait until falling_edge(clk);
		assert rdata = msgsize(15 downto 8) report "Saved message size MSB is incorrect" severity error;

		raddr <= "000" & x"02";
		wait until falling_edge(clk);
		assert rdata = msgsize(7 downto 0) report "Saved message size LSB is incorrect" severity error;

		for byte in 0 to intsize-1 loop
			raddr <= std_logic_vector(to_unsigned(byte + 3, 11));
			wait until falling_edge(clk);
			assert rdata = std_logic_vector(to_unsigned(byte, 8)) report "Saved data does not match transmitted" severity error;
		end loop;
		assert false report "Transmitted packet has been verified" severity note;

		wait for clk_period*10;
		finished <= '1';
		rst <= '1';
		assert false report "Testbench complete" severity note;

	end process;

END;
