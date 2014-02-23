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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

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
	signal rxlen : std_logic_vector(15 downto 0);

	signal ringptr, ringptr_new : std_logic_vector(10 downto 0);
	signal oldptr  : std_logic_vector(10 downto 0);
	signal ring_wr : std_logic;

	signal ADDRA : std_logic_vector(13 downto 0);
	signal DATAA : std_logic_vector(31 downto 0);
	signal ADDRB : std_logic_vector(13 downto 0);
	signal DATAB : std_logic_vector(31 downto 0);

	type state_type is (st_start0, st_start1, st_seq,
		st_szhi0, st_szhi1, st_szlo0, st_szlo1, st_token0, st_token1,
		st_rcv0, st_rcv1, st_cksum0, st_cksum1, st_tokenerr, st_ckerr, st_incptr, st_ringwr);
	signal state, next_state, return_state, return_state_new : state_type;

	signal cksum, cksum_new : std_logic_vector(7 downto 0);
	signal cmdstrobe_int, cmdstrobe_new : std_logic;

begin

	cmdstrobe <= cmdstrobe_int;

	-- Outputs and internal registers change on the rising edge
	process(rst,clk)
	begin
		if rst = '1' then
			cmdstrobe_int <= '0';
			cksum <= (others => '0');
			ringptr <= (others => '0');
		elsif rising_edge(clk) then
			cmdstrobe_int <= cmdstrobe_new;
			cksum <= cksum_new;
			ringptr <= ringptr_new;
		end if;
	end process;

	-- FSM changes state on the falling edge
	sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start0;
			return_state <= st_start0;
		elsif falling_edge(clk) then
			state <= next_state;
			return_state <= return_state_new;
		end if;
	end process;

	-- Combinatorial logic
	comb_proc : process(state,uart_strobe,uart_data,rxlen,cksum,ringptr,oldptr,return_state)
		variable ringptr_next : std_logic_vector(10 downto 0);
		variable cksum_next : std_logic_vector(7 downto 0);
		variable cmdstrobe_next : std_logic;
	begin

		next_state <= state;
		return_state_new <= return_state;
		ring_wr <= '0';
		readerr <= '0';
		tokenerr <= '0';


		ringptr_next := ringptr;
		cmdstrobe_next := '0';
		cksum_next := cksum;

		case state is
			when st_start0 =>  -- Wait for a start byte
				if uart_strobe = '1' and uart_data = X"1B" then
					next_state <= st_start1;
				end if;

			when st_start1 =>
				cksum_next := uart_data;
				next_state <= st_seq;

			when st_seq =>  -- Save the sequence number. Check vs local counter?
				if uart_strobe = '1' then
					return_state_new <= st_szhi0;
					next_state <= st_ringwr;
				end if;

			when st_szhi0 =>  -- Read high byte of length
				if uart_strobe = '1' then
					next_state <= st_szhi1;
				end if;

			when st_szhi1 =>
				cksum_next := uart_data xor cksum;
				ring_wr <= '1';
				return_state_new <= st_szlo0;
				next_state <= st_incptr;

			when st_szlo0 =>  -- Read low byte of length
				if uart_strobe = '1' then
					next_state <= st_szlo1;
				end if;

			when st_szlo1 =>
				cksum_next := uart_data xor cksum;
				ring_wr <= '1';
				return_state_new <= st_token0;
				next_state <= st_incptr;

			when st_token0 =>  -- Check the token, jump to error if incorrect
				if uart_strobe = '1' then
					next_state <= st_token1;
				end if;

			when st_token1 =>
				cksum_next := uart_data xor cksum;
				if uart_data = X"0E" then
					next_state <= st_rcv0;
				else
					next_state <= st_tokenerr;
				end if;

			when st_tokenerr =>
				tokenerr <= '1';
				next_state <= st_tokenerr;


			when st_rcv0 =>
				if uart_strobe = '1' then
					next_state <= st_rcv1;
				end if;

			when st_rcv1 =>  -- Save data as long as length > 0
				cksum_next := uart_data xor cksum;
				ring_wr <= '1';
				if rxlen = "0" then
					return_state_new <= st_cksum0;
				else
					return_state_new <= st_rcv0;
				end if;
				next_state <= st_incptr;

			when st_cksum0 =>  -- Compare checksums, jump to error if they don't match
				if uart_strobe = '1' then
					if uart_data = cksum then
						next_state <= st_cksum1;
					else
						next_state <= st_ckerr;
					end if;
				end if;

			when st_cksum1 =>
				cmdstrobe_next := '1';
				next_state <= st_start0;

			when st_ckerr =>  -- Rewind the ring buffer pointer
				readerr <= '1';
				ringptr_next := oldptr;
				next_state <= st_ckerr;

			when st_ringwr =>
				cksum_next := uart_data xor cksum;
				ring_wr <= '1';
				next_state <= st_incptr;

			when st_incptr =>
				ringptr_next := ringptr + "1";
				next_state <= return_state;

			when others =>
				next_state <= state;
		end case;

		-- Latch the new values
		ringptr_new <= ringptr_next;
		cksum_new <= cksum_next;
		cmdstrobe_new <= cmdstrobe_next;
	end process;

	-- Store the value of the ring buffer pointer when starting a new receive cycle
	ptr_old : process(rst, clk)
	begin
		if rst = '1' then
			oldptr <= (others => '0');
		elsif rising_edge(clk) then
			if state = st_start1 then
				oldptr <= ringptr;
			end if;
		end if;
	end process;

	savelen : process(rst,clk)
	begin
		if rst = '1' then
			rxlen <= (others => '0');
		elsif rising_edge(clk) then
			if uart_strobe = '1' then
				if state = st_szhi1 then
					rxlen(15 downto 8) <= uart_data;
				elsif state = st_szlo1 then
					rxlen(7 downto 0) <= uart_data;
				elsif state = st_rcv1 then
					rxlen <= rxlen - "1";
				end if;
			end if;
		end if;
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
	ADDRB <= ringptr & "000";
	DATAB <= X"000000" & uart_data;
	ringdata <= DATAA(7 downto 0);

end Behavioral;
