library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all ;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.synchronizer_pkg.all;
use work.uartrx_pkg.all;
--use work.uarttx_pkg.all;

entity testrx is
	Port (
		RxD : IN STD_LOGIC;
		TxD : OUT STD_LOGIC;
		MISO : IN STD_LOGIC;
		MOSI : OUT STD_LOGIC;
		RST : IN STD_LOGIC;
		CLK : in  STD_LOGIC;
		LED : OUT STD_LOGIC_VECTOR(7 downto 0) );
end testrx;

architecture Behavioral of testrx is
	-- uartrx
	signal urdata : std_logic_vector(7 downto 0);
	signal urstrobe : std_logic;

	-- uarttx
	signal rxfrerror : std_logic;
	signal txbusy : std_logic;

	-- synchronizers
	signal syncrx : std_logic;

begin

	process(rst,clk,urstrobe,RxD,syncrx)
	begin
		if rst = '1' then
			led <= (others => '0');
		elsif rising_edge(clk) and urstrobe = '1' then
			led <= urdata;
		end if;
	end process;


	u0 : synchronizer port map(RxD, syncrx, CLK, RST);
	u1 : uartrx port map (syncrx, urstrobe, urdata, rxfrerror, CLK, RST);
--	u5 : uarttx port map(TxD, urstrobe, urdata, txbusy, CLK, RST);
	TxD <= '1';
	MOSI <= '0';

end Behavioral;
