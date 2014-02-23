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

package readfsm_pkg is
	component readfsm
		Port (
			uart_strobe : in std_logic;
			uart_data : in std_logic_vector(7 downto 0);
			ringaddr : in std_logic_vector(10 downto 0);
			ringdata : out std_logic_vector(7 downto 0);
			cmdstrobe : out std_logic;
			readerr : out std_logic;
			tokenerr : out std_logic;
			clk      : in STD_LOGIC;
			rst      : in STD_LOGIC);
	end component;
end readfsm_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.readfsm_pkg.all;

entity readfsm is
	Port (
		uart_strobe : in std_logic;
		uart_data : in std_logic_vector(7 downto 0);
		ringaddr : in std_logic_vector(10 downto 0);
		ringdata : out std_logic_vector(7 downto 0);
		cmdstrobe : out std_logic;
		readerr : out std_logic;
		tokenerr : out std_logic;
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end readfsm;

architecture Behavioral of readfsm is
	signal rxlen, rxlen_new : unsigned(15 downto 0);

	signal ringptr, ringptr_new : unsigned(10 downto 0);
	signal oldptr, oldptr_new  : unsigned(10 downto 0);
	signal ring_wr : std_logic;

	signal ADDRA : std_logic_vector(13 downto 0);
	signal DATAA : std_logic_vector(31 downto 0);
	signal ADDRB : std_logic_vector(13 downto 0);
	signal DATAB : std_logic_vector(31 downto 0);

	type state_type is (st_start, st_seq, st_szhi, st_szlo, st_token, st_rcv, st_cksum,
	                    st_tokenerr, st_ckerr);
	signal state, next_state, return_state, return_state_new : state_type;

	signal cksum, cksum_new : std_logic_vector(7 downto 0);

	-- cmdstrobe could be output directly from the combinatorial logic. This strobe is
	-- driven by the state of the rxstrobe, however, so doing so could lead to a very long
	-- critical path. The strobe is therefore pipelined.
	signal cmdstrobe_int, cmdstrobe_new : std_logic;

begin

	cmdstrobe <= cmdstrobe_int;

	-- Outputs and internal registers change on the rising edge
	process(rst,clk)
	begin
		if rst = '1' then
			-- IO
			cmdstrobe_int <= '0';
			-- Memory
			cksum <= (others => '0');
			ringptr <= (others => '0');
			oldptr <= (others => '0');
			rxlen <= (others => '0');
			-- FSM
			state <= st_start;
			return_state <= st_start;
		elsif rising_edge(clk) then
			-- IO
			cmdstrobe_int <= cmdstrobe_new;
			-- Memory
			cksum <= cksum_new;
			ringptr <= ringptr_new;
			oldptr <= oldptr_new;
			rxlen <= rxlen_new;
			-- FSM
			state <= next_state;
			return_state <= return_state_new;
		end if;
	end process;

	-- Combinatorial logic
	comb_proc : process(state,uart_strobe,uart_data,rxlen,cksum,ringptr,oldptr,return_state,rxlen)
		variable ringptr_next : unsigned(10 downto 0);
		variable oldptr_next : unsigned(10 downto 0);
		variable cksum_next : std_logic_vector(7 downto 0);
		variable cmdstrobe_next : std_logic;
		variable rxlen_next : unsigned(15 downto 0);
	begin

		next_state <= state;
		return_state_new <= return_state;
		ring_wr <= '0';
		readerr <= '0';
		tokenerr <= '0';


		rxlen_next := rxlen;
		ringptr_next := ringptr;
		oldptr_next := oldptr;
		cmdstrobe_next := '0';
		cksum_next := cksum;

		case state is
			when st_start =>  -- Wait for a start byte
				oldptr_next := ringptr;
				if uart_strobe = '1' and uart_data = X"1B" then
					cksum_next := uart_data;
					next_state <= st_seq;
				end if;

			when st_seq =>  -- Save the sequence number. Check vs local counter?
				if uart_strobe = '1' then
					cksum_next := uart_data xor cksum;

					-- Data written and pointer incremented on next rising edge
					ring_wr <= '1';
					ringptr_next := ringptr + "1";

					next_state <= st_szhi;
				end if;

			when st_szhi =>  -- Read high byte of length
				if uart_strobe = '1' then
					cksum_next := uart_data xor cksum;
					rxlen_next(15 downto 8) := unsigned(uart_data);

					-- Data written and pointer incremented on next rising edge
					ring_wr <= '1';
					ringptr_next := ringptr + "1";

					next_state <= st_szlo;
				end if;

			when st_szlo =>  -- Read low byte of length
				if uart_strobe = '1' then
					cksum_next := uart_data xor cksum;
					rxlen_next(7 downto 0) := unsigned(uart_data);

					-- Data written and pointer incremented on next rising edge
					ring_wr <= '1';
					ringptr_next := ringptr + "1";

					next_state <= st_token;
				end if;

			when st_token =>  -- Check the token, jump to error if incorrect
				if uart_strobe = '1' then
					cksum_next := uart_data xor cksum;
					-- Verify the token
					if uart_data = X"0E" then
						next_state <= st_rcv;
					else
						next_state <= st_tokenerr;
					end if;
				end if;

			when st_tokenerr =>
				tokenerr <= '1';
				next_state <= st_tokenerr;


			when st_rcv =>  -- Save data as long as length > 0
				if uart_strobe = '1' then
					cksum_next := uart_data xor cksum;

					-- Data written and pointer incremented on next rising edge
					ring_wr <= '1';
					ringptr_next := ringptr + "1";

					rxlen_next := rxlen - "1";

					-- Check against rxlen to shorten the critical path
					if rxlen = "1" then
						next_state <= st_cksum;
					else
						next_state <= st_rcv;
					end if;
				end if;

			when st_cksum =>  -- Compare checksums, jump to error if they don't match
				if uart_strobe = '1' then
					if uart_data = cksum then
						cmdstrobe_next := '1';
						next_state <= st_start;
					else
						next_state <= st_ckerr;
					end if;
				end if;

			when st_ckerr =>  -- Rewind the ring buffer pointer
				readerr <= '1';
				ringptr_next := oldptr;
				next_state <= st_ckerr;

			when others =>
				next_state <= state;
		end case;

		-- Latch the new values
		rxlen_new <= rxlen_next;
		ringptr_new <= ringptr_next;
		oldptr_new <= oldptr_next;
		cksum_new <= cksum_next;
		cmdstrobe_new <= cmdstrobe_next;
	end process;

	RxRAM : RAMB16BWER
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
		-- Port A
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
		ENB => ring_wr,     -- 1-bit input: enable input
		WEB => "1111",      -- 4-bit input: byte-wide write enable input, must all be 1 or odd bytes won't be written
		DIB => DATAB,       -- 32-bit input: data input
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);

	ADDRA <= ringaddr & "000";
	ADDRB <= std_logic_vector(ringptr) & "000";
	DATAB <= X"000000" & uart_data;
	ringdata <= DATAA(7 downto 0);

end Behavioral;
