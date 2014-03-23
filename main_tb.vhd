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

	signal MISO : std_logic := '0';
	signal MOSI : std_logic;
	signal SCK : std_logic;
	signal DEVPWR : std_logic;
	signal DEVRST : std_logic;

	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	-- Clock period definitions
	constant clk_period : time := 10 ns;

	constant baud_period : time := 4.32 us;

	signal extra,extrarx : std_logic_vector(7 downto 0);

	type char_array is array (integer range<>) of std_logic_vector(7 downto 0);

	  -- 0x1B 0xFF 0x00 0x01 0x0e 0x01 0xEA
	constant LINIT1 : integer := 7;
	constant DINIT1 : char_array(0 to LINIT1-1) := (x"1b", x"01", x"00", x"01", x"0e", x"01", x"14");

	constant LPARAM : integer := 8;
	type param_array is array (integer range<>) of char_array(0 to LPARAM-1);
	constant NPARAM : integer := 4;
	constant DPARAM : param_array(0 to NPARAM-1) := (
		(x"1b", x"02", x"00", x"02", x"0e", x"03", x"90", x"86"),
		(x"1b", x"03", x"00", x"02", x"0e", x"03", x"91", x"86"),
		(x"1b", x"04", x"00", x"02", x"0e", x"03", x"92", x"82"),
		(x"1b", x"05", x"00", x"02", x"0e", x"03", x"94", x"85"));

	constant LPROGM : integer := 18;
	constant DPROGM : char_array(0 to LPROGM-1) := (x"1B", x"06", x"00", x"0c", x"0e", x"10", x"c8", x"04", x"19", x"20", x"00", x"53", x"03", x"ac", x"53", x"00", x"00", x"55");

	constant LERASE : integer := 13;
	constant DERASE : char_array(0 to LERASE-1) := (x"1b", x"13", x"00", x"07", x"0e", x"12", x"09", x"00", x"ac", x"88", x"19", x"38", x"1f");

	constant LADDR1 : integer := 11;
	constant DADDR1 : char_array(0 to LADDR1-1) := (x"1b", x"13", x"00", x"05", x"0e", x"06", x"00", x"00", x"00", x"10", x"15");

	constant LREAD1 : integer := 10;
	constant DREAD1 : char_array(0 to LREAD1-1) := (x"1b", x"14", x"00", x"04", x"0e", x"14", x"00", x"03", x"20", x"32");

	constant LENDPROG : integer := 9;
	constant DENDPROG : char_array(0 to LENDPROG-1) := (x"1B", x"15", x"00", x"03", x"0e", x"11", x"02", x"03", x"13");

BEGIN

	assert readfsmerr /= '1' report "Rx FSM error in testbench" severity error;

	u1 : entity work.uartrx port map ( rx => RxD, strobe => urstrobe, data => urdata, ferror => rxfrerror, clk => CLK, rst => RST );
	u2 : entity work.readfsm port map( uart_strobe => urstrobe, uart_data => urdata, ringaddr => rdaddr, ringdata => rddata, cmdstrobe => rdstrobe, readerr => readfsmerr, tokenerr => readtokenerr, clk => CLK, rst => RST );
	u3 : entity work.dispatch port map( ringaddr => rdaddr, ringdata => rddata, cmdstrobe => rdstrobe, txaddr => dtaddr, txdata => dtdata, txwr => dtwr, txstrobe => dtstrobe, txbusy => dtbusy, MISO => MISO, MOSI => MOSI, SCK => SCK, DEVPWR => DEVPWR, DEVRST => DEVRST, procerr => dispatcherr, busyerr => dispatchbusy, clk => CLK, rst => RST );
	u4 : entity work.fsm_stktx port map( uart_strobe => tustrobe, uart_data => tudata, uart_busy => tubusy, buffer_addr => dtaddr, buffer_data => dtdata, buffer_wren => dtwr, strobe => dtstrobe, busy => dtbusy, clk => CLK, rst => RST );
	u5 : entity work.uarttx port map( tx => TxD, strobe => tustrobe, data => tudata, busy => tubusy, clk => CLK, rst => RST );

	MISO <= MOSI;

	uextra   : entity work.uartrx port map (rx => TxD, strobe => open, data => extra, ferror => open, clk => CLK, rst => RST);
	uextrarx : entity work.uartrx port map (rx => RxD, strobe => open, data => extrarx, ferror => open, clk => CLK, rst => RST);

	-- Clock process definitions
	clk <= not clk after clk_period/2;  -- when finished /= '1' else '0';

	-- Stimulus process
	stim_proc: process
	begin
		-- hold reset state for 100 ns.
		wait for 100 ns;

		rst <= '0';

		wait for clk_period*10;

		for C in DINIT1'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DINIT1(C)'low to DINIT1(C)'high loop
				RxD <= DINIT1(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for baud_period*250;

--		for P in DPARAM'range loop
--			for C in DPARAM(P)'range loop
--				RxD <= '0'; wait for baud_period;  -- START
--				for b in DPARAM(P)(C)'low to DPARAM(P)(C)'high loop
--					RxD <= DPARAM(P)(C)(b); wait for baud_period;
--				end loop;
--				RxD <= '1'; wait for baud_period;  -- START
--			end loop;
--			wait for baud_period*250;
--		end loop;

		for C in DPROGM'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DPROGM(C)'low to DPROGM(C)'high loop
				RxD <= DPROGM(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for 4 ms;  -- Start-up time
		wait for baud_period*300;

		for C in DERASE'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DERASE(C)'low to DERASE(C)'high loop
				RxD <= DERASE(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for 9 ms;
		wait for baud_period*300;

		for C in DADDR1'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DADDR1(C)'low to DADDR1(C)'high loop
				RxD <= DADDR1(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for baud_period*150;

		for C in DREAD1'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DREAD1(C)'low to DREAD1(C)'high loop
				RxD <= DREAD1(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for baud_period*500;

		for C in DENDPROG'range loop
			RxD <= '0'; wait for baud_period;  -- START
			for b in DENDPROG(C)'low to DENDPROG(C)'high loop
				RxD <= DENDPROG(C)(b); wait for baud_period;
			end loop;
			RxD <= '1'; wait for baud_period;  -- START
		end loop;
		wait for 5 ms;  -- Shutdown time
		wait for baud_period*300;

		wait;
	end process;

END;
