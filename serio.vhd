----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:22:20 09/11/2012 
-- Design Name: 
-- Module Name:    serio - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
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

entity serio is
	Port ( 
		MISO : in  STD_LOGIC;
		MOSI : out  STD_LOGIC;
		SCK : out  STD_LOGIC;
		tx : in  STD_LOGIC_VECTOR (7 downto 0);
		rx : out  STD_LOGIC_VECTOR (7 downto 0);
		txstrobe : in  STD_LOGIC;
		rxstrobe : out  STD_LOGIC;
		clk : in STD_LOGIC;
		rst : in STD_LOGIC);
end serio;

architecture Behavioral of serio is
	signal divcount : std_logic_vector(6 downto 0);
	signal div100 : std_logic;

	signal shifter : std_logic_vector(7 downto 0);
	signal shiftcount : std_logic_vector(4 downto 0);

	signal txen : std_logic;
	signal latch : std_logic_vector(7 downto 0);
begin

	SCK <= div100 and txen;

	clkdiv : process(rst,clk)
	begin
		if rst = '1' then
			divcount <= (others => '0');
			div100 <= '0';
		elsif rising_edge(clk) then
			if divcount = "1100011" then
				divcount <= (others => '0');
				div100 <= '0';
			else
				divcount <= divcount + "1";
				if divcount >= "110001" then
					div100 <= '1';
				end if;
			end if;
		end if;
	end process;

	-- Strobe rxstrobe high for one clock cycle from falling edge to falling edge
	rxdrive : process(rst,clk)
	begin
		if rst = '1' then
			rxstrobe <= '0';
			rx <= (others => '0');
		elsif falling_edge(clk) then
			if txen = '0' and shiftcount = "1000" then
				rxstrobe <= '1';
				rx <= shifter;
			else
				rxstrobe <= '0';
			end if;
		end if;
	end process;

	txdrive : process(rst,clk)
		variable delay : std_logic;
	begin
		if rst = '1' then
			txen <= '0';
			latch <= (others => '0');
		elsif rising_edge(clk) then
			if shiftcount = "0000" and txstrobe = '1' then
				latch <= tx;
				delay := '1';
			elsif shiftcount = "1000" then
				txen <= '0';
			end if;

			if delay = '1' and divcount < "0010111" then  -- Delay the data if it arrives too late to apply to MOSI
				txen <= '1';
				delay := '0';
			end if;
		end if;
	end process;

	shiftreg : process(rst,clk)
		variable old : std_logic;
		variable olden : std_logic;
	begin
		if rst = '1' then
			shifter <= (others => '0');
			shiftcount <= (others => '0');
			olden := '0';
		elsif rising_edge(clk) then
			if txen = '1' then
				-- Latch Tx data on the rising edge of txen
				if olden = '0' then
					shifter <= latch;
				end if;

				if divcount = "0011000" then
					MOSI <= shifter(7);
				elsif divcount = "1100011" then
					shifter(7 downto 0) <= shifter(6 downto 0) & MISO;
					shiftcount <= shiftcount + "1";
				end if;
			else
				shiftcount <= (others => '0');
			end if;
			olden := txen;
			old := div100;
		end if;
	end process;


end Behavioral;

