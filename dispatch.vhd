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

package dispatch_pkg is
	component dispatch
		Port (
			-- Connects to the readfsm block's ring buffer
			ringaddr  : out std_logic_vector(10 downto 0);
			ringdata  : in std_logic_vector(7 downto 0);
			cmdstrobe : in std_logic;
			-- Connects to the transmitter's buffer
			txaddr    : out std_logic_vector(10 downto 0);
			txdata    : out std_logic_vector(7 downto 0);
			txwr      : out std_logic;
			txstrobe  : out std_logic;
			txbusy    : in  std_logic;
			-- Outputs to the device being programmed
			MISO      : in  std_logic;
			MOSI      : out std_logic;
			SCK       : out std_logic;
			-- Error flags
			procerr   : out std_logic;
			busyerr   : out std_logic;
			-- Misc.
			clk      : in STD_LOGIC;
			rst      : in STD_LOGIC);
	end component;
end dispatch_pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.stk500def.all;
use work.dispatch_pkg.all;

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
		SCK       : out std_logic;
		procerr   : out std_logic;
		busyerr   : out std_logic;
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end dispatch;

architecture Behavioral of dispatch is

	-- ***********
	-- FSM signals
	-- ***********

	type state_type is (st_start, st_storecmd, st_cmdunknown,
	    st_storeseq, st_getlenhi, st_getlenlo,
	    st_getparam1, st_getparam2,
	    st_setparam1, st_setparam2,
	    st_signon1, st_signon2, st_signon3,
	    st_ispinit1, st_ispinit2, st_ispfin1,
	    st_ispreadsig1, st_ispreadsig2, st_ispreadsig3,
		st_ispmulti1, st_ispmulti2, st_ispmulti3, st_ispmultitx, st_ispmultiwait,
	    st_fin1, st_fin2, st_fin3, st_fin4);
	signal state, state_new : state_type;

	signal byteinc : std_logic;
	signal target, target_new : std_logic_vector(7 downto 0);

	-- registers for number of bytes to receive and to transmit
	signal numrx, numrx_new : unsigned(7 downto 0);
	signal numtx, numtx_new : unsigned(7 downto 0);
	-- counter for the number of bytes transmitted
	signal spicount, spicount_new : unsigned(8 downto 0);
	-- data to be transmitted over the SPI link
	signal spidata, spidata_new : std_logic_vector(7 downto 0);
	-- strobe signal indicating data valid
	signal spistrobe, spistrobe_new : std_logic;

	-- ***********************
	-- Received packet signals
	-- ***********************
	signal ringptr, ringptr_new : unsigned(10 downto 0);
	signal packetptr, packetptr_new : unsigned(10 downto 0);
	signal packetlen, packetlen_new : unsigned(15 downto 0);

	-- *********************
	-- Output packet signals
	-- *********************
	signal msgbodylen, msgbodylen_new : unsigned(15 downto 0);

	-- Device model string, returned on INIT
	constant MSTRLEN : integer := 8;
	type char_array is array (integer range<>) of std_logic_vector(7 downto 0);
	constant MODEL : char_array(0 to MSTRLEN-1) := (X"41", X"56", X"52", X"49", X"53", X"50", X"5F", X"32");  -- AVRISP_2
	signal strlen, strlen_new : unsigned(3 downto 0);

	-- Output strobe
	signal txstrobe_new : std_logic;

	-- *****************
	-- STK500 Parameters
	-- *****************
	constant BUILD_NUMBER : std_logic_vector(15 downto 0) := X"0001";
	constant HW_VER       : std_logic_vector(7 downto 0) := X"01";
	constant SW_VER       : std_logic_vector(15 downto 0) := X"0200";
	constant stk_vtarget  : std_logic_vector(7 downto 0) := X"21";  -- 3.3 V
	constant stk_vadjust  : std_logic_vector(7 downto 0) := X"21";  -- 3.3 V
	signal stk_osc_pscale : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_osc_cmatch : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_topcard_detect : std_logic_vector(7 downto 0);
	signal stk_data       : std_logic_vector(7 downto 0);
	signal stk_status     : std_logic_vector(7 downto 0);
	signal stk_sck_duration, stk_sck_duration_new : unsigned(7 downto 0);
	signal stk_rst_polarity, stk_rst_polarity_new : std_logic;  -- RESET flag polarity
	signal stk_init, stk_init_new : std_logic_vector(7 downto 0);

	constant isp_nregs : integer := 7;
	-- timeout, stabDelay, cmdexeDelay, synchLoops, byteDelay, pollValue, pollIndex
	signal isp_regs, isp_regs_new : char_array(0 to isp_nregs-1);
	signal isp_idx, isp_idx_new : unsigned(3 downto 0);

	-- **********
	-- SPI Output
	-- **********
	constant ndivbits : integer := 16;
	signal sckcountto : unsigned(ndivbits-1 downto 0);  -- set by a separate process
	signal sckdivcount, sckdivcount_new : unsigned(ndivbits-1 downto 0);
	signal sck_int, sck_int_new : std_logic;
	signal sck_en, sck_en_new : std_logic;
	signal shifter, shifter_new : std_logic_vector(7 downto 0);
	signal shiftcount, shiftcount_new : unsigned(2 downto 0);

	signal spibusy, spibusy_new : std_logic;
	signal mosi_int, mosi_new : std_logic;


begin

	-- ****************************
	-- SPI Transciever Subprocesses
	-- ****************************

	-- The following transciever handles all serial communication with the
	-- device to be programmed. Timing, polarity and other parameters are
	-- read from the registers of the dispatch FSM. Data is latched and
	-- transmission started on a strobe signal from the dispatch FSM. A
	-- busy signal is available, so there is no need for a final strobe to
	-- indicate when transmission is complete/data is available.

	SCK <= sck_int;
	MOSI <= mosi_int;

	-- SCK clock counter value calculator
	-- Using formula for AVRISP from STK500 datasheet, converted to
	-- half period in 100 MHz clock tics (T / 2Tc)
	-- AVR068 pp. 30-31
	process(clk,rst)
		variable pipeline, tmp : unsigned(ndivbits-1 downto 0);
	begin
		if rising_edge(clk) then
			if rst = '1' then
				sckcountto <= (others => '0');
			elsif stk_sck_duration(7 downto 2) = "000000" then
				case stk_sck_duration(1 downto 0) is
					when "00" => sckcountto <= to_unsigned(53,ndivbits);    -- 925926 Hz
					when "01" => sckcountto <= to_unsigned(216,ndivbits);   -- 230415 Hz
					when "10" => sckcountto <= to_unsigned(867,ndivbits);   -- 57604 Hz
					when "11" => sckcountto <= to_unsigned(1735,ndivbits);  -- 28802 Hz
					when others => null;
				end case;
			else
				-- FIXME where does '270' come from?
				tmp := pipeline + to_unsigned(270,ndivbits);
				if stk_sck_duration(0) = '0' then
					sckcountto <= tmp;
				else
					sckcountto <= tmp + "1";
				end if;
				-- Pipelined to enable a clock of 100 MHz
				pipeline := 325 * stk_sck_duration + stk_sck_duration(7 downto 1);
			end if;
		end if;
	end process;

	-- SPI FSM
	spi_sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			sckdivcount <= (others => '0');
			sck_int <= '0';
			sck_en <= '0';
			sckdivcount <= (others => '0');
			shifter <= (others => '0');
			shiftcount <= (others => '0');
			spibusy <= '0';
			mosi_int <= '0';
		elsif rising_edge(clk) then
			sck_int <= sck_int_new;
			sck_en <= sck_en_new;
			sckdivcount <= sckdivcount_new;
			shifter <= shifter_new;
			shiftcount <= shiftcount_new;
			spibusy <= spibusy_new;
			mosi_int <= mosi_new;
		end if;
	end process;

	spi_comb_proc : process(sck_int, sck_en, sckcountto, sckdivcount, shifter, shiftcount, spibusy, spistrobe, spidata, mosi_int, MISO)
		variable sckdivcount_next : unsigned(ndivbits-1 downto 0);
		variable sck_int_next : std_logic;
		variable sck_en_next : std_logic;
		variable shifter_next : std_logic_vector(7 downto 0);
		variable shiftcount_next : unsigned(2 downto 0);
		variable spibusy_next : std_logic;
		variable mosi_next : std_logic;
	begin
		sck_int_next := sck_int;
		sck_en_next := sck_en;
		sckdivcount_next := sckdivcount;
		shifter_next := shifter;
		shiftcount_next := shiftcount;
		spibusy_next := spibusy;

		mosi_next := mosi_int;

		if spibusy = '0' and spistrobe = '1' then
			spibusy_next := '1';
			sck_en_next := '1';

			shiftcount_next := (others => '0');
			sckdivcount_next := (others => '0');

			-- MOSI is sampled by the AVR on the rising edge of SCK.
			-- Therefore, start with SCK = '0' and the first bit
			-- already on MOSI. Data is MSb first.
			mosi_next := spidata(7);
			shifter_next := spidata(6 downto 0) & '0';
			sck_int_next := '0';
		end if;

		-- sck_en is disabled by this process alone, so can never be disabled
		-- halfway through a transition.
		if sck_en = '1' then
			if sckdivcount = sckcountto then
				sckdivcount_next := (others => '0');
				sck_int_next := not sck_int;

				-- Shift a bit in on the rising edge
				if sck_int_next = '1' then
					shifter_next(0) := MISO;
				end if;

				-- Increment the bit counter on the falling edge
				if sck_int_next = '0' then
					shiftcount_next := shiftcount + "1";

					if shiftcount = "111" then
						-- Just shifted out the last bit, so we're done
						spibusy_next := '0';
						sck_en_next := '0';
					else
						-- Shift out the next bit
						mosi_next := shifter(7);
						shifter_next := shifter(6 downto 0) & '0';
					end if;
				end if;

			else
				sckdivcount_next := sckdivcount + "1";
			end if;
		end if;

		sck_int_new <= sck_int_next;
		sck_en_new <= sck_en_next;
		sckdivcount_new <= sckdivcount_next;
		shifter_new <= shifter_next;
		shiftcount_new <= shiftcount_next;
		spibusy_new <= spibusy_next;
		mosi_new <= mosi_next;
	end process;

	-- ***********************
	-- Backwards compatibility
	-- ***********************

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

	-- ************
	-- Dispatch FSM
	-- ************

	-- Builds an STK500 reply message in the local ring buffer based
	-- on the received message and on the reaction from the device

	ringaddr <= std_logic_vector(ringptr);

	main_sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start;

			msgbodylen <= (others => '0');
			ringptr <= (others => '0');
			packetlen <= (others => '0');
			packetptr <= (others => '0');
			strlen <= (others => '0');
			txstrobe <= '0';

			target <= (others => '0');
			stk_rst_polarity <= '1';
			stk_init <= (others => '0');
			stk_sck_duration <= "00000011";

			isp_regs <= (others => (others => '0'));
			isp_idx <= x"0";

			numrx <= (others => '0');
			numtx <= (others => '0');

			spicount <= (others => '0');
			spidata <= (others => '0');
			spistrobe <= '0';
		elsif rising_edge(clk) then
			state <= state_new;

			msgbodylen <= msgbodylen_new;
			ringptr <= ringptr_new;
			packetlen <= packetlen_new;
			packetptr <= packetptr_new;
			strlen <= strlen_new;
			txstrobe <= txstrobe_new;
			target <= target_new;
			stk_rst_polarity <= stk_rst_polarity_new;
			stk_init <= stk_init_new;
			stk_sck_duration <= stk_sck_duration_new;

			isp_regs <= isp_regs_new;
			isp_idx <= isp_idx_new;

			numrx <= numrx_new;
			numtx <= numtx_new;

			spicount <= spicount_new;
			spidata <= spidata_new;
			spistrobe <= spistrobe_new;
		end if;
	end process;


	main_comb_proc : process(state, cmdstrobe, msgbodylen, ringptr, ringdata, packetlen, packetptr, strlen, txbusy, target, stk_rst_polarity, stk_init, stk_sck_duration, isp_regs, isp_idx, numrx, numtx, spicount, spidata, spistrobe, spibusy, shifter)
		variable msgbodylen_next : unsigned(15 downto 0);
		variable ringptr_next : unsigned(10 downto 0);
		variable packetptr_next : unsigned(10 downto 0);
		variable packetlen_next : unsigned(15 downto 0);
		variable strlen_next : unsigned(3 downto 0);
		variable target_next : std_logic_vector(7 downto 0);
		variable stk_sck_duration_next : unsigned(7 downto 0);
		variable stk_rst_polarity_next : std_logic;
		variable stk_init_next : std_logic_vector(7 downto 0);
		variable txstrobe_next : std_logic;
		variable isp_regs_next : char_array(0 to isp_nregs-1);
		variable isp_idx_next : unsigned(3 downto 0);
		variable spicount_next : unsigned(8 downto 0);
		variable spidata_next : std_logic_vector(7 downto 0);
		variable spistrobe_next : std_logic;
		variable numtx_next : unsigned(7 downto 0);
		variable numrx_next : unsigned(7 downto 0);
	begin
		-- Pipelined signals
		msgbodylen_next := msgbodylen;
		ringptr_next := ringptr;
		packetlen_next := packetlen;
		packetptr_next := packetptr;
		strlen_next := strlen;

		target_next := target;
		stk_rst_polarity_next := stk_rst_polarity;
		stk_init_next := stk_init;
		stk_sck_duration_next := stk_sck_duration;

		isp_regs_next := isp_regs;
		isp_idx_next := isp_idx;

		numrx_next := numrx;
		numtx_next := numtx;

		spicount_next := spicount;
		spidata_next := spidata;
		spistrobe_next := '0';

		txstrobe_next := '0';

		-- Non-pipelined signals
		state_new <= state;
		txaddr <= (others => '0');
		txdata <= (others => '0');
		txwr <= '0';

		case state is
			when st_start =>  -- Wait for confirmation of a command received
				msgbodylen_next := x"0000";

				if cmdstrobe = '1' then
					state_new <= st_storeseq;
					-- It takes one clock tick to read from the ringbuffer, so
					-- ringptr should lead on the current state by one tick. Otherwise
					-- wait states will be required.
					ringptr_next := ringptr + "1";
				end if;

			-- *******
			-- Startup
			-- *******

			-- Read in the received packet header from the RX ring buffer and
			-- start preparing a response packet

			-- Ringbuffer contains <seq> <lenhi|lenlo> <cmd> <...>

			when st_storeseq =>
				-- Received sequence number will be sent back
				txaddr <= "000" & x"01";
				-- FIXME possible critical path
				txdata <= ringdata;
				txwr <= '1';

				ringptr_next := ringptr + "1";

				state_new <= st_getlenhi;

			when st_getlenhi =>
				packetlen_next(15 downto 8) := unsigned(ringdata);
				ringptr_next := ringptr + "1";
				state_new <= st_getlenlo;

				-- Use this opportunity to write the message start byte
				txaddr <= "000" & x"00";
				txdata <= MESSAGE_START;
				txwr <= '1';


			when st_getlenlo =>
				packetlen_next(7 downto 0) := unsigned(ringdata);
				ringptr_next := ringptr + "1";
				state_new <= st_storecmd;

				-- Use this opportunity to write the token byte
				txaddr <= "000" & x"04";
				txdata <= TOKEN;
				txwr <= '1';

				packetptr_next := ringptr;

			when st_storecmd =>
				-- Answer ID is usually identical to the received command ID
				txaddr <= "000" & x"05";
				-- FIXME possible critical path
				txdata <= ringdata;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				-- Current ringpointer address is cmd+1, so byte after command will
				-- be available in next state. Increment it, so that commands that
				-- need to read multiple bytes can without an extra state. Don't worry
				-- about commands with no parameters, as packetptr is used to set
				-- the correct ringptr once the command is complete.
				ringptr_next := ringptr + "1";

				case ringdata is
					when CMD_SIGN_ON => state_new <= st_signon1;
					when CMD_GET_PARAMETER => state_new <= st_getparam1;
					when CMD_SET_PARAMETER => state_new <= st_setparam1;
					when CMD_ENTER_PROGMODE_ISP =>
						state_new <= st_ispinit1;
						isp_idx_next := x"0";
					when CMD_LEAVE_PROGMODE_ISP => state_new <= st_ispfin1;
					when CMD_SPI_MULTI => state_new <= st_ispmulti1;
--					when CMD_READ_SIGNATURE_ISP => state_new <= st_ispreadsig1;
					when others => state_new <= st_cmdunknown;
				end case;

			-- *******
			-- Wrap-up
			-- *******

			-- Save the computed message body length and indicate to the
			-- TX subsystem that it can start transmission

			when st_cmdunknown =>
				-- Write status CMD_UNKNOWN
				txaddr <= "000" & x"06";
				txdata <= STATUS_CMD_UNKNOWN;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				state_new <= st_fin1;

			when st_fin1 =>  -- Save the packet length msB
				txaddr <= "000" & x"02";
				txdata <= std_logic_vector(msgbodylen(15 downto 8));
				txwr <= '1';
				state_new <= st_fin2;

			when st_fin2 =>  -- Save the packet length lsB
				txaddr <= "000" & x"03";
				txdata <= std_logic_vector(msgbodylen(7 downto 0));
				txwr <= '1';
				txstrobe_next := '1';

				state_new <= st_fin3;

			when st_fin3 =>  -- Wait for transmission to start
				if txbusy = '0' then
					state_new <= st_fin3;
				else
					state_new <= st_fin4;
				end if;

			when st_fin4 =>  -- Wait for transmission to finish
				if txbusy = '1' then
					state_new <= st_fin4;
				else
					-- Ensure that the pointer is in the right place, regardless
					ringptr_next := packetptr + packetlen(10 downto 0);
					state_new <= st_start;
				end if;

			-- ***********
			-- CMD_SIGN_ON
			-- ***********

			when st_signon1 =>
				-- Write status OK
				txaddr <= "000" & x"06";
				txdata <= STATUS_CMD_OK;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				stk_init_next := X"00";

				state_new <= st_signon2;

			when st_signon2 =>
				-- Write string length
				txaddr <= "000" & x"07";
				txdata <= std_logic_vector(to_unsigned(MSTRLEN,8));
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				-- Copy string length for strcpy operation
				strlen_next := to_unsigned(MSTRLEN,4) - "1";

				state_new <= st_signon3;

			when st_signon3 =>
				-- 7 preceeding bytes for header
				txaddr <= "0000000" & std_logic_vector(strlen + x"8");
				-- This next operation creates an asynchronous RAM
				txdata <= MODEL(to_integer(strlen));
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				if strlen = 0 then
					state_new <= st_fin1;
				else
					state_new <= st_signon3;
					strlen_next := strlen - 1;
				end if;

			-- *****************
			-- CMD_GET_PARAMETER
			-- *****************

			when st_getparam1 =>
				-- Write status
				txaddr <= "000" & X"06";
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				-- Just as with setparam, need to store the parameter id
				target_next := ringdata;

				if    ringdata = PARAM_OSC_PSCALE
				   or ringdata = PARAM_OSC_CMATCH
				   or ringdata = PARAM_TOPCARD_DETECT
				   or ringdata = PARAM_DATA
				   or ringdata = PARAM_RESET_POLARITY then
					-- No need to advance ringpointer, as fin4 will do clean-up
					txdata <= STATUS_CMD_FAILED;
					state_new <= st_fin1;
				else
					txdata <= STATUS_CMD_OK;
					state_new <= st_getparam2;
				end if;

			when st_getparam2 =>
				-- ringptr will now points to the start of the next packet
				ringptr_next := ringptr + "1";
				-- Write parameter to x0005
				txaddr <= "000" & X"07";
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				case target is
					when PARAM_BUILD_NUMBER_LOW => txdata <= BUILD_NUMBER(7 downto 0);
					when PARAM_BUILD_NUMBER_HIGH => txdata <= BUILD_NUMBER(15 downto 8);
					when PARAM_HW_VER => txdata <= HW_VER;
					when PARAM_SW_MAJOR => txdata <= SW_VER(15 downto 8);
					when PARAM_SW_MINOR => txdata <= SW_VER(7 downto 0);
					when PARAM_SCK_DURATION => txdata <= std_logic_vector(stk_sck_duration(7 downto 0));
					when PARAM_CONTROLLER_INIT => txdata <= stk_init(7 downto 0);
					when PARAM_VTARGET => txdata <= stk_vtarget;
					when PARAM_VADJUST => txdata <= stk_vadjust;
					when others => txdata <= X"00";
				end case;

				state_new <= st_fin1;

			-- *****************
			-- CMD_SET_PARAMETER
			-- *****************

			when st_setparam1 =>
				-- Write status
				txaddr <= "000" & X"06";
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				ringptr_next := ringptr + "1";
				target_next := ringdata;

				if ringdata = PARAM_RESET_POLARITY
					or ringdata = PARAM_SCK_DURATION
					or ringdata = PARAM_CONTROLLER_INIT then
					txdata <= STATUS_CMD_OK;  -- This critical path is slow
					state_new <= st_setparam2;
				else
					txdata <= STATUS_CMD_FAILED;
					state_new <= st_fin1;
				end if;

			when st_setparam2 =>
				ringptr_next := ringptr + "1";

				if target = PARAM_RESET_POLARITY then
					if ringdata = X"00" then
						stk_rst_polarity_next := '0';
					else
						stk_rst_polarity_next := '1';
					end if;
				elsif target = PARAM_SCK_DURATION then
					stk_sck_duration_next := unsigned(ringdata);
				elsif target = PARAM_CONTROLLER_INIT then
					stk_init_next := ringdata;
				end if;
				state_new <= st_fin1;

			-- **********************
			-- CMD_ENTER_PROGMODE_ISP
			-- **********************

			when st_ispinit1 =>
				isp_regs_next(to_integer(isp_idx)) := ringdata;
				ringptr_next := ringptr + x"1";
				if isp_idx = to_unsigned(isp_nregs-1,3) then
					state_new <= st_ispmultitx;
					msgbodylen_next := msgbodylen + "1";
				else
					isp_idx_next := isp_idx + x"1";
				end if;

				-- Write status OK
				txaddr <= "000" & X"06";
				txdata <= STATUS_CMD_OK;
				txwr <= '1';

				-- Set up a CMD_SPI_MULTI
				numtx_next := x"04";
				numrx_next := x"00";
				target_next := x"00";

			-- **********************
			-- CMD_LEAVE_PROGMODE_ISP
			-- **********************
			when st_ispfin1 =>
				-- Write status OK
				txaddr <= "000" & X"06";
				txdata <= STATUS_CMD_OK;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				state_new <= st_fin1;

			-- **********************
			-- CMD_SPI_MULTI
			-- **********************
			when st_ispmulti1 =>
				-- Write status OK
				txaddr <= "000" & X"06";
				txdata <= STATUS_CMD_OK;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				-- Get number of transmit bytes
				numtx_next := unsigned(ringdata);
				ringptr_next := ringptr + "1";

				state_new <= st_ispmulti2;

			when st_ispmulti2 =>
				-- Get number of receive bytes
				numrx_next := unsigned(ringdata);
				ringptr_next := ringptr + "1";

				state_new <= st_ispmulti3;

			when st_ispmulti3 =>
				-- Write second status OK after received data
				-- TODO make a test to check there's no overflow here
				txaddr <= "00" & std_logic_vector(('0' & numrx) + x"07");
				txdata <= STATUS_CMD_OK;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

				target_next := ringdata; -- RxStartAddr

				-- Current ringpointer address points to the first data byte,
				-- so that data byte will be available in the next state
				ringptr_next := ringptr + "1";

				state_new <= st_ispmultitx;

				spicount_next := (others => '0');

			when st_ispmultitx =>

				if spicount >= numtx then
					-- Transmit nulls as padding
					spidata_next := (others => '0');
				else
					spidata_next := ringdata;
				end if;

				if spicount >= unsigned(target) + numrx and spicount >= numtx then
				   state_new <= st_fin1;
				else
					spistrobe_next := '1';
					state_new <= st_ispmultiwait;
				end if;

			when st_ispmultiwait =>
				txdata <= shifter;

				if spistrobe = '1' or spibusy = '1' then
					state_new <= st_ispmultiwait;
				else
					spicount_next := spicount + "1";

					-- Write the byte received from the device to the response buffer
					if spicount >= unsigned(target) then
						txaddr <= '0' & std_logic_vector(('0' & spicount) - unsigned(target) + x"07");
						txwr <= '1';
						msgbodylen_next := msgbodylen + "1";
					end if;

					-- Advance the ring pointer. Data will still be available
					-- for the one cycle spent in the multitx state
					ringptr_next := ringptr + "1";

					state_new <= st_ispmultitx;
				end if;

--			-- CMD_READ_SIGNATURE_ISP
--			when st_ispreadsig1 =>
--				-- Save RetAddr in tmp and advance Rx ring pointer
--				tmp <= ringdata;
--				ringptr_next := ringptr + "1";

--				-- 4 bytes to transmit over ISP interface
--				ispbytecount <= X"03";

--				-- save status in Tx buffer
--				txdata <= STATUS_CMD_OK;
--				txaddr <= "000" & X"04";
--				txwr <= '1';
--				msgbodylen_next := msgbodylen + "1";

--				state_new <= st_ispreadsig2;

--			when st_ispreadsig2 =>
--				-- Save sequence of 4 commands into ISP ring buffer
--				ispring_idata <= ringdata;
--				ispring_wr <= '1';
--				ringptr_next := ringptr + "1";

--				if ispbytecount = X"00" then
--					-- Save second status byte in response
--					txdata <= STATUS_CMD_OK;
--					txaddr <= "000" & X"06";
--					txwr <= '1';
--					msgbodylen_next := msgbodylen + "1";

--					-- Activate transmission
--					isptx <= '1';
--					ispbytecount <= X"04";

--					state_new <= st_ispreadsig3;
--				else
--					ispbytecount <= ispbytecount - X"01";

--					state_new <= st_ispreadsig2;
--				end if;

--			when st_ispreadsig3 =>
--				if isptxbusy = '1' then
--					state_new <= st_ispreadsig3;
--				else
--					txaddr <= "000" & X"05";
--					txwr <= '1';
--					msgbodylen_next := msgbodylen + "1";
--					txdata <= PORTB_OUT;
--					portb_inc <= '1';
--					state_new <= st_fin1;


			when others =>
				state_new <= state;
		end case;

		msgbodylen_new <= msgbodylen_next;
		ringptr_new <= ringptr_next;
		packetlen_new <= packetlen_next;
		packetptr_new <= packetptr_next;
		strlen_new <= strlen_next;
		txstrobe_new <= txstrobe_next;

		target_new <= target_next;
		stk_rst_polarity_new <= stk_rst_polarity_next;
		stk_init_new <= stk_init_next;
		stk_sck_duration_new <= stk_sck_duration_next;

		isp_regs_new <= isp_regs_next;
		isp_idx_new <= isp_idx_next;

		numrx_new <= numrx_next;
		numtx_new <= numtx_next;

		spicount_new <= spicount_next;
		spidata_new <= spidata_next;
		spistrobe_new <= spistrobe_next;
	end process;

end Behavioral;
