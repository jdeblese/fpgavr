library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all ;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity testtx is
    Port (
        RxD : IN STD_LOGIC;
        TxD : OUT STD_LOGIC;
        RST : IN STD_LOGIC;
        CLK : in  STD_LOGIC;
        LED : OUT STD_LOGIC_VECTOR(7 downto 0) );
end testtx;

architecture Behavioral of testtx is

	component uarttx
		Port (
			tx     : out std_logic;
			strobe : in std_logic;
			data   : in std_logic_vector(7 downto 0);
			busy   : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;

	signal strobe : std_logic;
	signal data   : std_logic_vector(7 downto 0);
	signal busy   : std_logic;

	signal clkdiv : std_logic_vector(26 downto 0);
	signal count  : std_logic_vector(7 downto 0);

begin

	data <= count;
	led(7) <= busy;
	led(6) <= strobe;
	led(5) <= clkdiv(26);
	led(4) <= rst;
	led(3 downto 0) <= (others => '0');

	u1 : uarttx port map(TxD, strobe, data, busy, CLK, RST);

	process(rst,clk)
	begin
		if rst = '1' then
			clkdiv <= (others => '0');
		elsif rising_edge(clk) then
			clkdiv <= clkdiv + "1";
		end if;
	end process;

	process(rst,clk)
		variable old : std_logic;
	begin
		if rst = '1' then
			strobe <= '0';
			count <= X"20";
		elsif rising_edge(clk) then
			strobe <= '0';
			if old = '0' and clkdiv(26) = '1' then
				strobe <= '1';
				count <= count + "1";
			end if;
			old := clkdiv(26);
		end if; 
	end process;

end Behavioral;
