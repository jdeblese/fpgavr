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
