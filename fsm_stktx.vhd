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

package fsm_stktx_pkg is
	component fsm_stktx
		Port (
			uart_strobe : out std_logic;
			uart_data   : out std_logic_vector(7 downto 0);
			uart_busy   : in  std_logic;
			buffer_addr   : in  std_logic_vector(10 downto 0);
			buffer_data   : in  std_logic_vector(7 downto 0);
			buffer_wren	  : in  std_logic;
			strobe : in  std_logic;
			busy   : out std_logic;
			clk : in  STD_LOGIC;
			rst : in  STD_LOGIC);
	end component;
end fsm_stktx_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.stk500def.all;
use work.fsm_stktx_pkg.all;

entity fsm_stktx is
	Port (
		uart_strobe : out std_logic;
		uart_data   : out std_logic_vector(7 downto 0);
		uart_busy   : in  std_logic;
		buffer_addr   : in  std_logic_vector(10 downto 0);
		buffer_data   : in  std_logic_vector(7 downto 0);
		buffer_wren	  : in  std_logic;
		strobe : in  std_logic;
		busy   : out std_logic;
		clk : in  STD_LOGIC;
		rst : in  STD_LOGIC);
end fsm_stktx;

architecture Behavioral of fsm_stktx is
	signal ADDRA : std_logic_vector(13 downto 0);
	signal DATAA : std_logic_vector(31 downto 0);
	signal ADDRB : std_logic_vector(13 downto 0);
	signal DATAB : std_logic_vector(31 downto 0);

	signal readaddr, readaddr_new : unsigned(10 downto 0);
	signal readdata : std_logic_vector(7 downto 0);

	signal data : std_logic_vector(7 downto 0);
	signal datamux : std_logic_vector(1 downto 0);
	signal datalen : std_logic_vector(15 downto 0);
	signal databyte : std_logic_vector(16 downto 0);

	signal cksum, cksum_new : std_logic_vector(7 downto 0);
	signal cksum_en : std_logic;

	signal active : std_logic;

	signal tick : std_logic_vector(1 downto 0);

	type state_type is (st_idle, st_strobe, st_waitforbusy, st_waitforidle);
	signal state, state_new : state_type;
	signal uart_data_new : std_logic_vector(7 downto 0);
	signal busy_next, uart_strobe_new : std_logic;

	-- 17 bits, due to header
	signal txcount, txcount_new : unsigned(16 downto 0);
	signal txlen, txlen_new : unsigned(16 downto 0);
begin

	-- Algorith
	-- While waiting for a strobe, dispatch writes an STK packet
	--   into the buffer, prefixing it with its sequence number and length
	-- On strobe, this fsm starts transmitting a packet, reading
	--   the packet lenth and data as needed
	-- Busy is asserted during a transmit

	syn_proc : process(rst, clk)
	begin
		if rst = '1' then
			state <= st_idle;
			readaddr <= (others => '0');

			txcount <= (others => '0');
			txlen <= (others => '0');
			cksum <= (others => '0');

			uart_data <= (others => '0');
			uart_strobe <= '0';

			busy <= '0';
		elsif rising_edge(clk) then
			state <= state_new;
			readaddr <= readaddr_new;

			txcount <= txcount_new;
			txlen <= txlen_new;
			cksum <= cksum_new;

			uart_data <= uart_data_new;
			uart_strobe <= uart_strobe_new;

			busy <= busy_next;
		end if;
	end process;

	com_proc : process(state, readaddr, readdata, txcount, txlen, cksum, strobe, uart_busy)
		variable state_next : state_type;
		variable readaddr_next : unsigned(10 downto 0);
		variable txcount_next, txlen_next : unsigned(16 downto 0);
		variable cksum_next : std_logic_vector(7 downto 0);
	begin
		-- Signals that maintain state
		state_next := state;
		readaddr_next := readaddr;
		txcount_next := txcount;
		txlen_next := txlen;
		cksum_next := cksum;

		-- Signals that don't maintain state
		uart_data_new <= (others => '0');
		uart_strobe_new <= '0';
		busy_next <= '1';

		case state is
			when st_idle =>
				busy_next <= '0';
				readaddr_next := (others => '0');
				txcount_next := (others => '0');
				txlen_next := '0' & x"0005";
				cksum_next := (others => '0');

				if strobe = '1' then
					-- Raise busy flag as soon as possible
					busy_next <= '1';
					state_next := st_strobe;
				end if;

			when st_strobe =>
				cksum_next := cksum xor readdata;
				uart_data_new <= readdata;
				uart_strobe_new <= '1';
				readaddr_next := readaddr + "1";
				txcount_next := txcount + "1";

				if txcount = x"2" then
					txlen_next(15 downto 8) := unsigned(readdata);
				elsif txcount = x"3" then
					txlen_next(7 downto 0) := unsigned(readdata);
				elsif txcount = x"4" then
					txlen_next := txlen_next + x"5";
				end if;

				state_next := st_waitforbusy;

			when st_waitforbusy =>
				if uart_busy = '1' then
					state_next := st_waitforidle;
				end if;

			when st_waitforidle =>
				uart_data_new <= cksum;
				if uart_busy = '0' then
					if txcount > txlen then
						state_next := st_idle;
					elsif txcount = txlen then
						-- Append the checksum
						uart_strobe_new <= '1';
						txcount_next := txcount + "1";
						state_next := st_waitforbusy;
					else
						state_next := st_strobe;
					end if;
				end if;

			when others =>
				state_next := st_idle;
		end case;

		state_new <= state_next;
		readaddr_new <= readaddr_next;
		txcount_new <= txcount_next;
		txlen_new <= txlen_next;
		cksum_new <= cksum_next;
	end process;

	TxRAM : RAMB16BWER
	generic map (
		DATA_WIDTH_A => 9,
		DATA_WIDTH_B => 9,
		DOA_REG => 0,
		DOB_REG => 0,
		EN_RSTRAM_A => TRUE,
		EN_RSTRAM_B => TRUE,
		INIT_FILE => "NONE",
		RSTTYPE => "SYNC",
		RST_PRIORITY_A => "CE",
		RST_PRIORITY_B => "CE",
		SIM_COLLISION_CHECK => "ALL",
		SIM_DEVICE => "SPARTAN6",
		WRITE_MODE_B => "READ_FIRST"  -- Allows port A to read same addr
	)
	port map (
		-- Port A, read_only
		DOA => DATAA,       -- 32-bit output: data output
		ADDRA => ADDRA,     -- 14-bit input: address input, low three are unused
		CLKA => CLK,        -- 1-bit input: clock input
		ENA => '1',         -- 1-bit input: enable input
		WEA => "0000",      -- 4-bit input: byte-wide write enable input
		DIA => X"00000000", -- 32-bit input: data input
		DIPA => "0000",     -- 4-bit input: parity input
		REGCEA => '0',      -- 1-bit input: register clock enable input
		RSTA => '0',        -- 1-bit input: register set/reset input
		-- Port B, write-only
		CLKB => clk,        -- 1-bit input: clock input
		ADDRB => ADDRB,     -- 14-bit input: address input, low three are unused
		ENB => buffer_wren, -- 1-bit input: enable input
		WEB => "1111",      -- 4-bit input: byte-wide write enable input, must all be 1 or odd bytes won't be written
		DIB => DATAB,       -- 32-bit input: data input
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);

	ADDRA <= std_logic_vector(readaddr) & "000";
	readdata <= DATAA(7 downto 0);

	ADDRB <= buffer_addr & "000";
	DATAB <= X"000000" & buffer_data;

end Behavioral;
