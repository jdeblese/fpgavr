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

package synchronizer_pkg is
	component synchronizer
		Port (
			async : in std_logic;
			sync  : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;
end synchronizer_pkg;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.synchronizer_pkg.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity synchronizer is
	Port (
		async : in std_logic;
		sync  : out std_logic;
		clk    : in STD_LOGIC;
		rst    : in STD_LOGIC);
end synchronizer;

architecture Behavioral of synchronizer is
	signal sreg : std_logic_vector(1 downto 0);

	attribute TIG : string;
	attribute IOB : string;
	attribute ASYNC_REG : string;
	attribute SHIFT_EXTRACT : string;
	attribute HBLKNM : string;
	attribute KEEP : string;

--	attribute KEEP of async : signal is "?";

	--  TIG="TRUE" - Specifies a timing ignore for the asynchronous input
	-- [Xst 1581] Constraint "TIG" is only supported in a XCF file outside the BEGIN MODEL/END section.
--	attribute TIG of async : signal is "TRUE";

	--  IOB="FALSE" = Specifies to not place the register into the IOB allowing
	--                both synchronization registers to exist in the same slice
	--                allowing for the shortest propagation time between them
	attribute IOB of async : signal is "FALSE";

	--  ASYNC_REG="TRUE" - Specifies registers will be receiving asynchronous data
	--                     input to allow for better timing simulation
	--                     characteristics
	attribute ASYNC_REG of sreg : signal is "TRUE";

	--  SHIFT_EXTRACT="NO" - Specifies to the synthesis tool to not infer an SRL
	attribute SHIFT_EXTRACT of sreg : signal is "NO";

	--  HBLKNM="sync_reg" - Specifies to pack both registers into the same slice, called sync_reg
	-- Xilinx forum: HBLKNM is a packing constraint that should be applied
	-- to logical instances. It's not valid to apply this constraint to nets.
--	attribute HBLKNM of sreg_0 : label is "sync_reg";
--	attribute HBLKNM of sreg_1 : label is "sync_reg";

begin

--	sreg_0 : FDCE
--	generic map (INIT => '0') -- Initial value of register ('0' or '1')  
--	port map (
--		Q => sreg(0),  -- Data output
--		C => clk,      -- Clock input
--		CE => '1',     -- Clock enable input
--		CLR => rst,    -- Asynchronous clear input
--		D => async     -- Data input
--	);
--
--	sreg_1 : FDCE
--	generic map (INIT => '0') -- Initial value of register ('0' or '1')  
--	port map (
--		Q => sreg(1),  -- Data output
--		C => clk,      -- Clock input
--		CE => '1',     -- Clock enable input
--		CLR => rst,    -- Asynchronous clear input
--		D => sreg(0)   -- Data input
--	);
--
--	sync <= sreg(1);

	-- Resynchronize asynchronous input

	process (rst,clk)
	begin
		if rst = '1' then
			sreg <= (others => '0');
			sync <= '0';
		elsif rising_edge(clk) then
			sync <= sreg(1);
			sreg <= sreg(0) & async;
		end if;
	end process;

end Behavioral;
