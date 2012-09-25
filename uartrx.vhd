library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uartrx is
	Port (
		rx     : in std_logic;
		strobe : out std_logic;
		data   : out std_logic_vector(7 downto 0);
		ferror : out std_logic;
		clk    : in STD_LOGIC;
		rst    : in STD_LOGIC);
end serio;

architecture Behavioral of serio is
	signal divcount  : std_logic_vector(13 downto 0);
	signal divstrobe : std_logic;
	signal div_en    : std_logic;

	signal bitcount : std_logic_vector(3 downto 0);
	signal shifter  : std_logic_vector(8 downto 0);
begin

	-- Strobe at the center of each bit
	clkdiv : process(rst,clk)
		constant countto : std_logic_vector(13 downto 0) := "00001101100011";  -- Count to   867, 115207   Hz @ 100 MHz
--		constant countto : std_logic_vector(13 downto 0) := "10100010110000";  -- Count to 10416,   9599.7 Hz @ 100 MHz
	begin
		if rst = '1' then
			divcount <= '0' & countto(13 downto 1);  -- Start at half the value, to strobe midway in the bit
		elsif rising_edge(clk) then
			divstrobe <= '0';
			if div_en = '0' then
				divcount <= (others => '0');
			elsif divcount = countto then
				divcount <= (others => '0');
				divstrobe <= '1';
			else
				divcount <= divcount + "1";
			end if;
		end if;
	end process;

	-- On internal strobe, shift data in and increment the counter
	recv : process(rst,clk)
	begin
		if rst = '1' then
			shifter <= (others => '0');
			bitcount <= (others => '0');
		elsif rising_edge(clk) then
			if div_en = '1' then 
				if divstrobe = '1' then
					shifter <= rx & shifter(8 downto 1);
					bitcount <= bitcount + "1";
				end if;
			else
				bitcount <= (others => '0');
				shifter <= (others => '0');
			end if;
		end if;
	end process;

	-- On a falling edge, enable the divider. When the count hits 10,
	-- disable the divider and output the data
	ctrl : process(rst,clk)
		old : std_logic;
	begin
		if rst = '1' then
			div_en <= '0';
			data <= (others => '0');
			ferror <= '0';
			strobe <= '0';
			old <= '0';
		elsif rising_edge(clk) then
			strobe <= '0';
			if div_en = '1' then
				if bitcount = "1010" then
					div_en <= '0';
					data <= shifter(7 downto 0);
					ferror <= not shifter(8);
					strobe <= '1';
				end if;
			else
				if old = '1' and rx = '0' then
					div_en <= '1';
				end if;
				old := rx;
			end if;
		end if;
	end process;

end Behavioral;

