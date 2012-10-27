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

library UNISIM;
use UNISIM.VComponents.all;

entity readfsm is
	Port (
		rs232_rx : in std_logic;
		ringaddr : in std_logic_vector(10 downto 0);
		ringdata : out std_logic_vector(7 downto 0);
		cmdstrobe : out std_logic;
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end readfsm;

architecture Behavioral of readfsm is
	component uartrx
		Port (
			rx     : in std_logic;
			strobe : out std_logic;
			data   : out std_logic_vector(7 downto 0);
			ferror : out std_logic;
			clk    : in STD_LOGIC;
			rst    : in STD_LOGIC);
	end component;

	signal rxstrobe : std_logic;
	signal rxdata : std_logic_vector(7 downto 0);
	signal rxerror : std_logic;

	signal rxlen : std_logic_vector(15 downto 0);

	signal ringptr : std_logic_vector(10 downto 0);
	signal oldptr  : std_logic_vector(10 downto 0);
	signal rewind  : std_logic;
	signal ring_wr : std_logic;

	signal ADDRA : std_logic_vector(13 downto 0);
	signal DATAA : std_logic_vector(31 downto 0);
	signal ADDRB : std_logic_vector(13 downto 0);
	signal DATAB : std_logic_vector(31 downto 0);

	signal cksum : std_logic_vector(7 downto 0);
	signal cksum_en : std_logic;

	type state_type is (st_start, st_seq, st_szhi, st_szlo, st_token, st_rcv, st_cksum, st_end, st_err);
	signal state, next_state : state_type;


begin
	urx : uartrx port map (rx => rs232_rx, strobe=>rxstrobe, data=>rxdata, ferror=>rxerror, clk=>clk, rst=>rst);

	calcsum : process(rst, clk)
	begin
		if rst = '1' then
			cksum <= (others => '0');
		elsif rising_edge(clk) then
			if cksum_en = '0' then
				cksum <= (others => '0');
			elsif rxstrobe = '1' and state /= st_cksum then
				cksum <= rxdata xor cksum;
			end if;
		end if;
	end process;

	sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start;
		elsif rising_edge(clk) then
			state <= next_state;
		end if;
	end process;

	comb_proc : process(state,rxstrobe,rxdata)
	begin

		next_state <= state;
		ring_wr <= '0';
		cksum_en <= '1';
		cmdstrobe <= '0';
		rewind <= '0';

		case state is
			when st_start =>  -- Wait for a start byte
				if rxstrobe = '1' and rxdata = X"1B" then
					next_state <= st_seq;
				end if;

			when st_seq =>  -- Save the sequence number. Check?
				if rxstrobe = '1' then
					ring_wr <= '1';
					next_state <= st_szhi;
				end if;

			when st_szhi =>  -- Read high byte of length
				if rxstrobe = '1' then
					ring_wr <= '1';
					next_state <= st_szlo;
				end if;

			when st_szlo =>  -- Read low byte of length
				if rxstrobe = '1' then
					ring_wr <= '1';
					next_state <= st_token;
				end if;

			when st_token =>  -- Check the token, jump to error if incorrect
				if rxstrobe = '1' then
					if rxdata = X"0E" then
						next_state <= st_rcv;
					else
						next_state <= st_err;
					end if;
				end if;

			when st_rcv =>  -- Save data as long as length > 0
				if rxlen > "0" then
					if rxstrobe = '1' then
						ring_wr <= '1';
					end if;
				else
					next_state <= st_cksum;
				end if;

			when st_cksum =>  -- Compare checksums, jump to error if they don't match
				if rxstrobe = '1' then
					cksum_en <= '0';
					if rxdata = cksum then
						cmdstrobe <= '1';
						next_state <= st_start;
					else
						next_state <= st_err;
					end if;
				end if;

			when st_err =>  -- Rewind the ring buffer pointer
				rewind <= '1';
				next_state <= st_start;

			when others =>
				next_state <= state;
		end case;
	end process;

	-- Increment the ring buffer pointer when the buffer is written to, or rewind it when indicated
	ptr_inc : process(rst,clk)
	begin
		if rst = '1' then
			ringptr <= (others => '0');
		elsif rising_edge(clk) then
			if rewind = '1' then
				ringptr <= oldptr;
			elsif ring_wr = '1' then
				ringptr <= ringptr + "1";
			end if;
		end if;
	end process;

	-- Store the value of the ring buffer pointer when starting a new receive cycle
	ptr_old : process(rst, clk)
	begin
		if rst = '1' then
			oldptr <= (others => '0');
		elsif rising_edge(clk) then
			if state = st_start then
				oldptr <= ringptr;
			end if;
		end if;
	end process;

	savelen : process(rst,clk)
	begin
		if rst = '1' then
			rxlen <= (others => '0');
		elsif rising_edge(clk) then
			if rxstrobe = '1' then
				if state = st_szhi then
					rxlen(15 downto 8) <= rxdata;
				elsif state = st_szlo then
					rxlen(7 downto 0) <= rxdata;
				elsif state = st_rcv then
					rxlen <= rxlen - "1";
				end if;
			end if;
		end if;
	end process;

	bootram : RAMB16BWER
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
	DATAB <= X"000000" & rxdata;
	ringdata <= DATAA(7 downto 0);

end Behavioral;
