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
		MISO      : in  std_logic;
		MOSI      : out std_logic;
		procerr   : out std_logic;
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end dispatch;

architecture Behavioral of dispatch is
	type state_type is (st_start, st_storecmd, st_cmdunknown,
	    st_storeseq, st_getlenhi, st_getlenlo,
	    st_getparam1, st_getparam2,
	    st_setparam1, st_setparam2,
	    st_signon1, st_signon2, st_signon3,
	    st_ispinit1, st_ispinit2, st_ispfin1,
	    st_ispreadsig1, st_ispreadsig2, st_ispreadsig3,
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
	constant SW_VER       : std_logic_vector(15 downto 0) := X"0200";
	signal stk_vtarget    : std_logic_vector(7 downto 0);  -- fixed-point 10x the voltage: 3.3V => 33
	signal stk_vadjust    : std_logic_vector(7 downto 0);  -- fixed-point 10x the voltage: 3.3V => 33
	signal stk_osc_pscale : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_osc_cmatch : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_sck_duration   : unsigned(7 downto 0);
	signal stk_topcard_detect : std_logic_vector(7 downto 0);
	signal stk_data       : std_logic_vector(7 downto 0);
	signal stk_rst_polarity   : std_logic;  -- RESET flag polarity
	signal stk_status     : std_logic_vector(7 downto 0);
	signal stk_init       : std_logic_vector(7 downto 0);

	constant MSTRLEN : integer := 8;
	type char_array is array (integer range<>) of std_logic_vector(7 downto 0);
	constant MODEL : char_array(0 to MSTRLEN-1) := (X"41", X"56", X"52", X"49", X"53", X"50", X"5F", X"32");  -- AVRISP_2
	signal strlen : integer;

	constant isp_nregs : integer := 11;
	-- timeout, stabDelay, cmdexeDelay, synchLoops, byteDelay, pollValue, pollIndex, cmd1..4
	signal isp_regs : char_array(0 to isp_nregs-1);
	signal isp_idx : integer;

	signal tmp : std_logic_vector(7 downto 0);

	constant ndivbits : integer := 16;
	signal sckdivcount : unsigned(ndivbits-1 downto 0);
	signal sckcountto : unsigned(ndivbits-1 downto 0);
	signal sck_out, sck_strobe, sck_en : std_logic;

	signal ADDRA, ADDRB : unsigned(13 downto 0);
	signal PORTA_IN, PORTA_OUT : std_logic_vector(31 downto 0);
	signal PORTB_IN, PORTB_OUT : std_logic_vector(31 downto 0);
--	signal PORTA_EN, PORTB_EN : std_logic;
	signal PORTA_WEN, PORTB_WEN : std_logic_vector(3 downto 0);
	signal PORTA_WR, PORTB_WR : std_logic;
	signal porta_inc, portb_inc : std_logic;

	signal ispbytecount : unsigned(7 downto 0);
	signal isptx : std_logic;
	signal isptxbusy : std_logic;
begin

	process(rst,clk,PORTB_WR)
	begin
		if rst = '1' then
			ADDRB <= (others => '0');
		elsif rising_edge(clk) and portb_inc = '1' then
			ADDRB <= ADDRB + X"01";
		end if;
	end process;

	-- Address counter for the receive ring buffer
	--
	-- Increments the address on command, resets
	-- to zero
	ringaddr <= ringptr;

	-- Using formula for AVRISP from STK500 datasheet, converted to
	-- half period in 100 MHz clock tics (T / 2Tc)
	process(clk,rst)
	begin
		if rst = '1' then
			sckcountto <= (others => '0');
		elsif rising_edge(clk) then
			if stk_sck_duration(7 downto 2) = "000000" then
				case stk_sck_duration(1 downto 0) is
					when "00" => sckcountto <= to_unsigned(53,ndivbits);
					when "01" => sckcountto <= to_unsigned(216,ndivbits);
					when "10" => sckcountto <= to_unsigned(867,ndivbits);
					when "11" => sckcountto <= to_unsigned(1735,ndivbits);
					when others => null;
				end case;
			else
				if stk_sck_duration(0) = '0' then
					sckcountto <= 325 * stk_sck_duration + stk_sck_duration(7 downto 1) + to_unsigned(270,ndivbits);
				else
					sckcountto <= 325 * stk_sck_duration + stk_sck_duration(7 downto 1) + to_unsigned(271,ndivbits);
				end if;
			end if;
		end if;
	end process;

	-- SCK clock divider, also strobe output
	sckdiv : process(rst,clk)
	begin
		if rst = '1' then
			sckdivcount <= (others => '0');
			sck_out <= '0';
			sck_strobe <= '0';
		elsif rising_edge(clk) then
			sck_strobe <= '0';
			if sck_en = '1' or sck_out = '1' then  -- if sck is disabled during sck=1, nicely wind down
				if sckdivcount = sckcountto then
					sckdivcount <= (others => '0');
					sck_out <= not sck_out;
					sck_strobe <= '1';
				else
					sckdivcount <= sckdivcount + to_unsigned(1,ndivbits);
				end if;
			end if;
		end if;
	end process;

	shiftreg : process(rst,clk)
		variable old : std_logic;
	begin
		if rst = '1' then
			shifter <= (others => '0');
			shiftcount <= (others => '0');
			old := '0';
			ADDRA <= (others => '0');
		elsif falling_edge(clk) then
			if isptx = '1' then
				-- Latch Tx data on the rising edge of txen
				if old = '0' then
					shifter <= PORTA_OUT;
					ADDRA <= ADDRA + "1";
				end if;

				-- MOSI is sampled by AVR on rising edge, MISO available on falling
				MOSI <= shifter(7);
				if sck_strobe = '1'  and sck_out = '1' then
					shifter(7 downto 0) <= shifter(6 downto 0) & MISO;
					shiftcount <= shiftcount + "1";
					if shiftcount = "111" then

				end if;
			else
				shiftcount <= (others => '0');
			end if;
			old := isptx;
		end if;
	end process;

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

			stk_rst_polarity <= '1';
			stk_init <= (others => '0');
			stk_sck_duration <= (others => '0');

			isp_regs <= (others => (others => '0'));

			sck_en <= '0';

			isptx <= '0';
			isptxbusy <= '0';

		elsif falling_edge(clk) then
			txwr <= '0';
			txstrobe <= '0';
			procerr <= '0';

			sck_en <= '0';

			isptx <= '0';
			isptxbusy <= '0';

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
						when CMD_ENTER_PROGMODE_ISP =>
							state <= st_ispinit1;
							isp_idx <= 0;
						when CMD_LEAVE_PROGMODE_ISP =>
							state <= st_ispfin1;
						when CMD_READ_SIGNATURE_ISP => state <= st_ispreadsig1;
						when others => state <= st_cmdunknown;
					end case;

				-- CMD_SIGN_ON

				when st_signon1 =>
					-- Write OK to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					txdata <= STATUS_CMD_OK;
					bytelen <= bytelen + "1";
					stk_init <= X"00";

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

					if ringdata = PARAM_VTARGET
						or ringdata = PARAM_VADJUST
						or ringdata = PARAM_OSC_PSCALE
						or ringdata = PARAM_OSC_CMATCH
						or ringdata = PARAM_TOPCARD_DETECT
						or ringdata = PARAM_DATA
						or ringdata = PARAM_RESET_POLARITY then
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
						when PARAM_SCK_DURATION => txdata <= std_logic_vector(stk_sck_duration(7 downto 0));
						when PARAM_CONTROLLER_INIT => txdata <= stk_init(7 downto 0);
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

					if ringdata = PARAM_RESET_POLARITY
						or ringdata = PARAM_SCK_DURATION
						or ringdata = PARAM_CONTROLLER_INIT then
						txdata <= STATUS_CMD_OK;  -- This critical path is slow
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
					elsif tmp = PARAM_SCK_DURATION then
						stk_sck_duration <= unsigned(ringdata);
					elsif tmp = PARAM_CONTROLLER_INIT then
						stk_init <= ringdata;
					end if;
					state <= st_fin1;

				-- CMD_ENTER_PROGMODE_ISP
				when st_ispinit1 =>
					isp_regs(isp_idx) <= ringdata;
					ringptr <= ringptr + "1";
					if isp_idx = isp_nregs-1 then
						state <= st_ispinit2;
					else
						isp_idx <= isp_idx + 1;
					end if;

				when st_ispinit2 =>
					-- Write status to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					bytelen <= bytelen + "1";
					txdata <= STATUS_CMD_OK;
					state <= st_fin1;

				-- CMD_LEAVE_PROGMODE_ISP
				when st_ispfin1 =>
					-- Write status to x0004
					txaddr <= "000" & X"04";
					txwr <= '1';
					bytelen <= bytelen + "1";
					txdata <= STATUS_CMD_OK;
					state <= st_fin1;


				-- CMD_READ_SIGNATURE_ISP
				when st_ispreadsig1 =>
					tmp <= ringdata;
					ringptr <= ringptr + "1";
					ispbytecount <= X"03";
					txaddr <= "000" & X"04";
					txwr <= '1';
					bytelen <= bytelen + "1";
					txdata <= STATUS_CMD_OK;
					state <= st_ispreadsig2;

				when st_ispreadsig2 =>
					PORTB_IN <= ringdata;
					PORTB_WR <= '1';
					portb_inc <= '1';
					ringptr <= ringptr + "1";
					isptx <= '1';
					if ispbytecount = X"00" then
						state <= st_ispreadsig3;
					else
						txaddr <= "000" & X"06";
						txwr <= '1';
						bytelen <= bytelen + "1";
						txdata <= STATUS_CMD_OK;
						ispbytecount <= ispbytecount - X"01";
						state <= st_ispreadsig2;
					end if;

				when st_ispreadsig3 =>
					if isptxbusy = '1' then
						state <= st_ispreadsig3;
					else
						txaddr <= "000" & X"05";
						txwr <= '1';
						bytelen <= bytelen + "1";
						txdata <= PORTB_OUT;
						portb_inc <= '1';
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

				when others =>
					state <= state;
			end case;
		end if;
	end process;

	ispram : RAMB16BWER
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
	)
	port map (
		-- Port A, to ISP transciever
		DOA => PORTA_IN,    -- 32-bit output: data output
		ADDRA => ADDRA,     -- 14-bit input: address input, low three are unused
		CLKA => CLK,        -- 1-bit input: clock input
		ENA => '1',         -- 1-bit input: enable input
		WEA => PORTA_WEN,   -- 4-bit input: byte-wide write enable input
		DIA => PORTA_OUT,   -- 32-bit input: data input
		DIPA => "0000",     -- 4-bit input: parity input
		REGCEA => '0',      -- 1-bit input: register clock enable input
		RSTA => '0',        -- 1-bit input: register set/reset input
		-- Port B, to dispatch FSM
		DOB => PORTB_IN,    -- 32-bit output: data output
		ADDRB => ADDRB,     -- 14-bit input: address input, low three are unused
		CLKB => clk,        -- 1-bit input: clock input
		ENB => '1',         -- 1-bit input: enable input
		WEB => PORTB_WEN,   -- 4-bit input: byte-wide write enable input, must all be 1 or odd bytes won't be written
		DIB => PORTB_OUT,   -- 32-bit input: data input
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);
	PORTA_WEN <= PORTA_WR & PORTA_WR & PORTA_WR & PORTA_WR;
	PORTB_WEN <= PORTB_WR & PORTB_WR & PORTB_WR & PORTB_WR;

	-- Temporarily disable port A
	PORTA_IN <= (others => '0');
	ADDRA <= (others => '0');
	PORTA_EN <= '0';
	PORTA_WR <= '0';

end Behavioral;
