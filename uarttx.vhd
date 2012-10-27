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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uarttx is
	Port (
		tx     : out std_logic;
		strobe : in std_logic;
		data   : in std_logic_vector(7 downto 0);
		busy   : out std_logic;
		clk    : in STD_LOGIC;
		rst    : in STD_LOGIC);
end uarttx;

architecture Behavioral of uarttx is
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
			divcount <= countto(13 downto 0) - "1";  -- Start at one tic before strobe
		elsif rising_edge(clk) then
			divstrobe <= '0';
			if div_en = '0' then
				divcount <= countto(13 downto 0) - "1";  -- Start at one tic before strobe
			elsif divcount = countto then
				divcount <= (others => '0');
				divstrobe <= '1';
			else
				divcount <= divcount + "1";
			end if;
		end if;
	end process;

	-- On internal strobe, shift data out and increment the counter
	trans : process(rst,clk)
	begin
		if rst = '1' then
			tx <= '1';
			shifter <= (others => '0');
			bitcount <= (others => '0');
		elsif rising_edge(clk) then
			if div_en = '1' then 
				if divstrobe = '1' then
					tx <= shifter(0);
					shifter <= '1' & shifter(8 downto 1);
					bitcount <= bitcount + "1";
				end if;
			else
				bitcount <= (others => '0');
				shifter <= data & '0';
			end if;
		end if;
	end process;

	-- Enable the divider on strobe
	ctrl : process(rst,clk)
	begin
		if rst = '1' then
			div_en <= '0';
		elsif rising_edge(clk) then
			if div_en = '1' and bitcount = "1011" then  -- Terminate on bit 11, the second stop bit
				div_en <= '0';
				busy <= '0';
			elsif strobe = '1' then
				div_en <= '1';
				busy <= '1';
			end if;
		end if;
	end process;

end Behavioral;

