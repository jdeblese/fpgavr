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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package uartrx_pkg is
	component uartrx
		Port (
			rx     : in std_logic;
			strobe : out std_logic;
			data   : out std_logic_vector(7 downto 0);
			ferror : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;
end uartrx_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.uartrx_pkg.all;

entity uartrx is
	Port (
		rx     : in std_logic;
		strobe : out std_logic;
		data   : out std_logic_vector(7 downto 0);
		ferror : out std_logic;
		clk    : in STD_LOGIC;
		rst    : in STD_LOGIC);
end uartrx;

architecture Behavioral of uartrx is
	constant ndivcountbits : integer := 6;
	signal divcount  : unsigned(ndivcountbits-1 downto 0);
	signal divstrobe : std_logic;
	signal div_en    : std_logic;

	signal bitcount : unsigned(3 downto 0);
	signal shifter  : std_logic_vector(8 downto 0);

	signal count16 : unsigned(3 downto 0);
	signal strobe16 : std_logic;

begin

	-- Sample clock, strobe at the center of each bit
	clkdiv : process(rst,clk)
		constant countto : unsigned := to_unsigned(53,ndivcountbits);  -- Count to    53, 16*115740   Hz @ 100 MHz, error 0.468%
	begin
		if rst = '1' then
			divcount <= (others => '0');
			divstrobe <= '0';
		elsif rising_edge(clk) then
			divstrobe <= '0';
			if divcount = countto then
				divcount <= (others => '0');
				divstrobe <= '1';
			else
				divcount <= divcount + "1";
			end if;
		end if;
	end process;

	-- Divide sample clock by 16
	process(rst,clk)
	begin
		if rst = '1' then
			count16 <= (others => '0');
			strobe16 <= '0';
		elsif rising_edge(clk) then
			strobe16 <= '0';
			if div_en = '0' then
				count16 <= X"0";
			elsif divstrobe = '1' then
				count16 <= count16 + "1";
				-- Strobe divided clock midway in bit
				if count16 = X"8" then
					strobe16 <= '1';
				end if;
			end if;
		end if;
	end process;

	-- On slow strobe, shift data in and increment the counter
	recv : process(rst,clk)
	begin
		if rst = '1' then
			shifter <= (others => '0');
			bitcount <= (others => '0');
		elsif rising_edge(clk) then
			if div_en = '1' then
				if strobe16 = '1' then
					shifter <= rx & shifter(8 downto 1);
					bitcount <= bitcount + "1";
				end if;
			else
				bitcount <= (others => '0');
			end if;
		end if;
	end process;

	-- On a falling edge, enable the divider. When the count hits 10,
	-- disable the divider and output the data
	ctrl : process(rst,clk)
		variable old : std_logic;
	begin
		if rst = '1' then
			div_en <= '0';
			data <= (others => '0');
			ferror <= '0';
			strobe <= '0';
			old := '0';
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
			end if;
			old := rx;
		end if;
	end process;

end Behavioral;

