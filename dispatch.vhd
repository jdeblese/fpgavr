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

library work;
use work.stk500def.all;

entity dispatch is
	Port (
		ringaddr  : out std_logic_vector(10 downto 0);
		ringdata  : in std_logic_vector(7 downto 0);
		cmdstrobe : in std_logic;
		txaddr    : out std_logic_vector(10 downto 0);
		txdata    : out std_logic_vector(7 downto 0);
		txwr      : out std_logic;
		txstrobe  : out std_logic;
		txbusy    : in  std_logic;
		procerr   : out std_logic;
		busyerr   : out std_logic;
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end dispatch;

architecture Behavioral of dispatch is
	type state_type is (st_start, st_err, st_getcmd, st_storecmd, st_cmdunknown,
	    st_getseq, st_storeseq, st_getlenhi, st_getlenlo,
	    st_getparam1, st_getparam2,
	    st_signon1, st_signon2,
	    st_fin1, st_fin2, st_fin3, st_fin4);
	signal state, next_state : state_type;

	signal inaddr : std_logic_vector(10 downto 0);
	signal inread : std_logic;
	signal inlen  : std_logic_vector(15 downto 0);

	signal bytelen : std_logic_vector(16 downto 0);
	signal byteinc : std_logic;

	-- Parameters
	constant BUILD_NUMBER : std_logic_vector(15 downto 0) := X"0001";
	constant HW_VER       : std_logic_vector(7 downto 0) := X"01";
	constant SW_VER       : std_logic_vector(15 downto 0) := X"0001";
	signal stk_vtarget    : std_logic_vector(7 downto 0);
	signal stk_vadjust    : std_logic_vector(7 downto 0);
	signal stk_osc_pscale : std_logic_vector(7 downto 0);
	signal stk_osc_cmatch : std_logic_vector(7 downto 0);
	signal stk_sck_duration   : std_logic_vector(7 downto 0);
	signal stk_topcard_detect : std_logic_vector(7 downto 0);
	signal stk_status     : std_logic_vector(7 downto 0);
	signal stk_data       : std_logic_vector(7 downto 0);
	signal stk_rst_polarity   : std_logic;
	signal stk_init       : std_logic_vector(7 downto 0);

begin
	-- Address counter for the receive ring buffer
	--
	-- Increments the address on command, resets
	-- to zero
	ringaddr <= inaddr;
	addr_proc : process(rst,clk)
	begin
		if rst = '1' then
			inaddr <= (others => '0');
		elsif falling_edge(clk) then
			if inread = '1' then
				inaddr <= inaddr + "1";
			end if;
		end if;
	end process;

	-- Transmit byte counter
	outbyte_proc : process(rst,clk)
	begin
		if rst = '1' then
			bytelen <= (others => '0');
		elsif rising_edge(clk) then
			if state = st_start then
				bytelen <= (others => '0');
			elsif byteinc = '1' then
				bytelen <= bytelen + "1";
			end if;
		end if;
	end process;

	process(rst,clk)
	begin
		if rst = '1' then
			inlen <= (others => '0');
		elsif falling_edge(clk) then
			if state = st_getlenhi then
				inlen(15 downto 8) <= ringdata;
			elsif state = st_getlenlo then
				inlen(7 downto 0) <= ringdata;
			end if;
		end if;
	end process;

	process(rst,clk)
	begin
		if rst = '1' then
			txstrobe <= '0';
		elsif rising_edge(clk) then
			if state = st_fin3 then
				txstrobe <= '1';
			else
				txstrobe <= '0';
			end if;
		end if;
	end process;

	process(rst,clk)
	begin
		if rst = '1' then
			busyerr <= '0';
		elsif falling_edge(clk) then
			if cmdstrobe = '1' and state /= st_start then
				busyerr <= '1';
			end if;
		end if;
	end process;

	-- FSM
	sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start;
		elsif falling_edge(clk) then
			state <= next_state;
		end if;
	end process;

	-- FSM
	comb_proc : process(state,cmdstrobe,ringdata,txbusy,bytelen)
	begin

		next_state <= state;
		inread <= '0';
		byteinc <= '0';
		txaddr <= (others => '0');
		txwr <= '0';
		txdata <= (others => '0');
		procerr <= '0';

		case state is
			when st_start =>  -- Wait for a command strobe
				if cmdstrobe = '1' then
					next_state <= st_getseq;
				end if;

			when st_getseq =>  -- Read in the sequence number
				next_state <= st_storeseq;

			when st_storeseq =>  -- write to x0000
				inread <= '1';
				txaddr <= "000" & X"00";
				txdata <= ringdata;
				txwr <= '1';
				next_state <= st_getlenhi;

			when st_getlenhi =>
				inread <= '1';
				next_state <= st_getlenlo;

			when st_getlenlo =>
				inread <= '1';
				next_state <= st_getcmd;

			when st_getcmd =>  -- Read in the command
				next_state <= st_storecmd;

			when st_storecmd =>  -- Write to x0003
				inread <= '1';
				txaddr <= "000" & X"03";
				txdata <= ringdata;
				txwr <= '1';
				byteinc <= '1';

				case ringdata is
					when CMD_SIGN_ON => next_state <= st_signon1;
					when CMD_GET_PARAMETER =>
						next_state <= st_getparam1;
--						inread <= '1';
					when others => next_state <= st_cmdunknown;
				end case;

			-- CMD_SIGN_ON

			when st_signon1 =>
				-- Write OK to x0004
				txaddr <= "000" & X"04";
				txwr <= '1';
				txdata <= STATUS_CMD_OK;
				byteinc <= '1';

				next_state <= st_signon2;

			when st_signon2 =>
				-- Write string length 0 to x0005
				txaddr <= "000" & X"05";
				txwr <= '1';
				txdata <= X"00";
				byteinc <= '1';

				next_state <= st_fin1;

			-- CMD_GET_PARAMETER

			when st_getparam1 =>
				-- Write status to x0004
				txaddr <= "000" & X"04";
				txwr <= '1';
				byteinc <= '1';

				if ringdata = PARAM_RESET_POLARITY then
					txdata <= STATUS_CMD_FAILED;
					next_state <= st_fin1;
				else
					txdata <= STATUS_CMD_OK;
					next_state <= st_getparam2;
				end if;

			when st_getparam2 =>
				inread <= '1';
				-- Write parameter to x0005
				txaddr <= "000" & X"05";
				txwr <= '1';
				byteinc <= '1';

				case ringdata is
					when PARAM_BUILD_NUMBER_LOW => txdata <= BUILD_NUMBER(7 downto 0);
					when PARAM_BUILD_NUMBER_HIGH => txdata <= BUILD_NUMBER(15 downto 8);
					when others => txdata <= ringdata;
				end case;

				next_state <= st_fin1;

			-- Wrap-up

			when st_cmdunknown =>
				-- Write UNKNOWN to x0004
				txaddr <= "000" & X"04";
				txwr <= '1';
				txdata <= STATUS_CMD_UNKNOWN;
				byteinc <= '1';

				next_state <= st_fin1;

			when st_fin1 =>
				txaddr <= "000" & X"01";
				txwr <= '1';
				txdata <= bytelen(15 downto 8);
				next_state <= st_fin2;

			when st_fin2 =>
				txaddr <= "000" & X"02";
				txwr <= '1';
				txdata <= bytelen(7 downto 0);

				next_state <= st_fin3;

			when st_fin3 =>
				next_state <= st_fin4;

			when st_fin4 =>
				if txbusy = '1' then
					next_state <= st_fin4;
				else
					next_state <= st_start;
				end if;

			when st_err =>
				procerr <= '1';
				next_state <= st_err;

			when others =>
				next_state <= state;
		end case;
	end process;

end Behavioral;
