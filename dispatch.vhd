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
use IEEE.STD_LOGIC_UNSIGNED."+";
use ieee.numeric_std.all;

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
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end dispatch;

architecture Behavioral of dispatch is
	type state_type is (st_start, st_err, st_storecmd, st_cmdunknown,
	    st_storeseq, st_getlenhi, st_getlenlo,
	    st_getparam1, st_getparam2,
	    st_setparam1, st_setparam2,
	    st_signon1, st_signon2, st_signon3,
	    st_fin1, st_fin2, st_fin3, st_fin4);
	signal state : state_type;

	signal ringptr : std_logic_vector(10 downto 0);
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

	constant MSTRLEN : integer := 8;
	type char_array is array (integer range<>) of std_logic_vector(7 downto 0);
	constant MODEL : char_array(0 to MSTRLEN-1) := (X"41", X"56", X"52", X"49", X"53", X"50", X"5F", X"32");  -- AVRISP_2
	signal strlen : integer;

	signal tmp : std_logic_vector(7 downto 0);

begin
	-- Address counter for the receive ring buffer
	--
	-- Increments the address on command, resets
	-- to zero
	ringaddr <= ringptr;

	-- FSM
	sync_proc : process(rst,clk)
		variable hdrptr : std_logic_vector(10 downto 0);
	begin
		if rst = '1' then
			state <= st_start;
			bytelen <= (others => '0');
			ringptr <= (others => '0');
			inlen <= (others => '0');
			tmp <= (others => '0');
			txwr <= '0';
			txstrobe <= '0';
			procerr <= '0';
		elsif falling_edge(clk) then
			txwr <= '0';
			txstrobe <= '0';
			procerr <= '0';
			case state is
				when st_start =>  -- Wait for confirmation of a command received
					if cmdstrobe = '1' then
						state <= st_storeseq;
						bytelen <= (others => '0');
					end if;

				-- Ringbuffer contains <seq> <lenhi|lenlo> <cmd> <...>

				when st_storeseq =>
					txaddr <= "000" & X"00";
					txdata <= ringdata;
					txwr <= '1';
					ringptr <= ringptr + "1";
					state <= st_getlenhi;

				when st_getlenhi =>
					inlen(15 downto 8) <= ringdata;
					ringptr <= ringptr + "1";
					state <= st_getlenlo;

				when st_getlenlo =>
					inlen(7 downto 0) <= ringdata;
					ringptr <= ringptr + "1";
					state <= st_storecmd;

				when st_storecmd =>
					hdrptr := ringptr;
					txaddr <= "000" & X"03";
					txdata <= ringdata;
					txwr <= '1';
					ringptr <= ringptr + "1";
					bytelen <= bytelen + "1";

					case ringdata is
						when CMD_SIGN_ON => state <= st_signon1;
						when CMD_GET_PARAMETER => state <= st_getparam1;
						when CMD_SET_PARAMETER => state <= st_setparam1;
						when others => state <= st_cmdunknown;
					end case;

				-- CMD_SIGN_ON

				when st_signon1 =>
					-- Write OK to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					txdata <= STATUS_CMD_OK;
					bytelen <= bytelen + "1";


					state <= st_signon2;

				when st_signon2 =>
					-- Write string length 0 to x0005
					txaddr <= "000" & X"05";
					txwr <= '1';
					bytelen <= bytelen + "1";

					-- Transmit string length
					txdata <= std_logic_vector(to_unsigned(MSTRLEN,8));
					strlen <= MSTRLEN - 1;

					state <= st_signon3;

				when st_signon3 =>
						txaddr <= std_logic_vector(to_unsigned(strlen + 6,11));  -- 6 preceeding bytes for header
					txdata <= MODEL(strlen);
					txwr <= '1';
					bytelen <= bytelen + "1";

					if strlen = 0 then
						state <= st_fin1;
					else
						state <= st_signon3;
						strlen <= strlen - 1;
					end if;

				-- CMD_GET_PARAMETER

				when st_getparam1 =>
					-- Write status to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					bytelen <= bytelen + "1";

					if ringdata = PARAM_RESET_POLARITY then
						txdata <= STATUS_CMD_FAILED;
						state <= st_fin1;
					else
						txdata <= STATUS_CMD_OK;
						state <= st_getparam2;
					end if;

				when st_getparam2 =>
					ringptr <= ringptr + "1";
					-- Write parameter to x0005
					txaddr <= "000" & X"05";
					txwr <= '1';
					bytelen <= bytelen + "1";

					case ringdata is
						when PARAM_BUILD_NUMBER_LOW => txdata <= BUILD_NUMBER(7 downto 0);
						when PARAM_BUILD_NUMBER_HIGH => txdata <= BUILD_NUMBER(15 downto 8);
						when PARAM_HW_VER => txdata <= HW_VER;
						when PARAM_SW_MAJOR => txdata <= SW_VER(15 downto 8);
						when PARAM_SW_MINOR => txdata <= SW_VER(7 downto 0);
						when others => txdata <= X"00";
					end case;

					state <= st_fin1;

				-- CMD_SET_PARAMETER
				when st_setparam1 =>
					-- Write status to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					bytelen <= bytelen + "1";
					ringptr <= ringptr + "1";
					tmp <= ringdata;

					if ringdata = PARAM_RESET_POLARITY then
						txdata <= STATUS_CMD_OK;
						state <= st_setparam2;
					else
						txdata <= STATUS_CMD_FAILED;
						state <= st_fin1;
					end if;

				when st_setparam2 =>
					ringptr <= ringptr + "1";

					if tmp = PARAM_RESET_POLARITY then
						if ringdata = X"00" then
							stk_rst_polarity <= '0';
						else
							stk_rst_polarity <= '1';
						end if;
					end if;
					state <= st_fin1;

				-- Wrap-up

				when st_cmdunknown =>
					-- Write UNKNOWN to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					txdata <= STATUS_CMD_UNKNOWN;
					bytelen <= bytelen + "1";

					state <= st_fin1;

				when st_fin1 =>
					txaddr <= "000" & X"01";
					txwr <= '1';
					txdata <= bytelen(15 downto 8);
					state <= st_fin2;

				when st_fin2 =>
					txaddr <= "000" & X"02";
					txwr <= '1';
					txdata <= bytelen(7 downto 0);
					txstrobe <= '1';

					state <= st_fin3;

				when st_fin3 =>
					if txbusy = '0' then
						state <= st_fin3;
					else
						state <= st_fin4;
					end if;

				when st_fin4 =>
					if txbusy = '1' then
						state <= st_fin4;
					else
						ringptr <= hdrptr + inlen(10 downto 0);
						state <= st_start;
					end if;

				when st_err =>
					procerr <= '1';
					state <= st_err;

				when others =>
					state <= state;
			end case;
		end if;
	end process;

end Behavioral;
