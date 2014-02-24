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
	    st_fin1, st_fin2, st_fin3, st_fin4);
	signal state, state_new : state_type;

	signal byteinc : std_logic;
	signal target, target_new : std_logic_vector(7 downto 0);

	-- ***********************
	-- Received packet signals
	-- ***********************
	signal ringptr, ringptr_new : unsigned(10 downto 0);
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
	signal stk_vtarget    : std_logic_vector(7 downto 0);  -- fixed-point 10x the voltage: 3.3V => 33
	signal stk_vadjust    : std_logic_vector(7 downto 0);  -- fixed-point 10x the voltage: 3.3V => 33
	signal stk_osc_pscale : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_osc_cmatch : std_logic_vector(7 downto 0);  -- AT90S8535 Timer, see data sheet
	signal stk_topcard_detect : std_logic_vector(7 downto 0);
	signal stk_data       : std_logic_vector(7 downto 0);
	signal stk_status     : std_logic_vector(7 downto 0);
	signal stk_sck_duration, stk_sck_duration_new : unsigned(7 downto 0);
	signal stk_rst_polarity, stk_rst_polarity_new : std_logic;  -- RESET flag polarity
	signal stk_init, stk_init_new : std_logic_vector(7 downto 0);

	constant isp_nregs : integer := 11;
	-- timeout, stabDelay, cmdexeDelay, synchLoops, byteDelay, pollValue, pollIndex, cmd1..4
	signal isp_regs : char_array(0 to isp_nregs-1);
	signal isp_idx : integer;

	constant ndivbits : integer := 16;
	signal sckdivcount : unsigned(ndivbits-1 downto 0);
	signal sckcountto : unsigned(ndivbits-1 downto 0);
	signal sck_out, sck_strobe, sck_en : std_logic;

	signal porta_inc, portb_inc : std_logic;

	signal ispbytecount : unsigned(7 downto 0);
	signal isptx : std_logic;
	signal isptxbusy : std_logic;

	signal shifter : std_logic_vector(7 downto 0);
	signal shiftcount : unsigned(2 downto 0);

	-- ***************
	-- Raw RAM Signals
	-- ***************
	signal RAM_OADDR, RAM_IADDR : std_logic_vector(13 downto 0);
	signal RAM_OUT, RAM_IN : std_logic_vector(31 downto 0);
	signal RAM_WEN : std_logic_vector(3 downto 0);
begin

	-- SCK clock counter value calculator
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

	-- ISP shift register
	shiftreg : process(rst,clk)
		variable old : std_logic;
		variable bytecount : unsigned(7 downto 0);
	begin
		if rst = '1' then
			shifter <= (others => '0');
			shiftcount <= (others => '0');
			old := '0';
			bytecount := (others => '0');
		elsif falling_edge(clk) then
			if isptx = '1' then
				-- Latch Tx data on the rising edge of txen
				if old = '0' then
					shifter <= RAM_OUT(7 downto 0);
					-- RAM_OADDR += 1
				end if;

				-- MOSI is sampled by AVR on rising edge, MISO available on falling
				MOSI <= shifter(7);
				if sck_strobe = '1'  and sck_out = '1' then
					shifter(7 downto 0) <= shifter(6 downto 0) & MISO;
					shiftcount <= shiftcount + "1";
					-- When final bit shifted out, read in next byte
					if shiftcount = "111" then
						shifter <= RAM_OUT(7 downto 0);
						-- RAM_OADDR += 1
						bytecount := bytecount + X"01";
					end if;
				end if;
			else
				shiftcount <= (others => '0');
			end if;
			old := isptx;
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


	sck_en <= '0';
	isptx <= '0';
	isptxbusy <= '0';
	isp_regs <= (others => (others => '0'));

	-- ************
	-- Dispatch FSM
	-- ************

	-- Builds an STK500 reply message in the local ring buffer based
	-- on the received message and on the reaction from the device

	ringaddr <= std_logic_vector(ringptr);

	sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start;

			msgbodylen <= (others => '0');
			ringptr <= (others => '0');
			packetlen <= (others => '0');
			strlen <= (others => '0');
			txstrobe <= '0';

			target <= (others => '0');
			stk_rst_polarity <= '1';
			stk_init <= (others => '0');
			stk_sck_duration <= (others => '0');

		elsif rising_edge(clk) then
			state <= state_new;

			msgbodylen <= msgbodylen_new;
			ringptr <= ringptr_new;
			packetlen <= packetlen_new;
			strlen <= strlen_new;
			txstrobe <= txstrobe_new;
			target <= target_new;
			stk_rst_polarity <= stk_rst_polarity_new;
			stk_init <= stk_init_new;
			stk_sck_duration <= stk_sck_duration_new;
		end if;
	end process;


	comb_proc : process(state, cmdstrobe, msgbodylen, ringptr, ringdata, packetlen, strlen, txbusy, target, stk_rst_polarity, stk_init, stk_sck_duration)
		variable msgbodylen_next : unsigned(15 downto 0);
		variable ringptr_next : unsigned(10 downto 0);
		variable packetlen_next : unsigned(15 downto 0);
		variable strlen_next : unsigned(3 downto 0);
		variable target_next : std_logic_vector(7 downto 0);
		variable stk_sck_duration_next : unsigned(7 downto 0);
		variable stk_rst_polarity_next : std_logic;
		variable stk_init_next : std_logic_vector(7 downto 0);
		variable txstrobe_next : std_logic;
--		variable hdrptr : std_logic_vector(10 downto 0);
	begin
		-- Pipelined signals
		msgbodylen_next := msgbodylen;
		ringptr_next := ringptr;
		packetlen_next := packetlen;
		strlen_next := strlen;

		target_next := target;
		stk_rst_polarity_next := stk_rst_polarity;
		stk_init_next := stk_init;
		stk_sck_duration_next := stk_sck_duration;

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


			when st_storecmd =>
				-- Answer ID is usually identical to the received command ID
				txaddr <= "000" & x"05";
				txdata <= ringdata;
				txwr <= '1';
				msgbodylen_next := msgbodylen + "1";

--				hdrptr := ringptr;
--				ringptr_next := ringptr + "1";  -- On exit from this state, ringptr points after cmd

				case ringdata is
					when CMD_SIGN_ON => state_new <= st_signon1;
					when CMD_GET_PARAMETER => state_new <= st_getparam1;
					when CMD_SET_PARAMETER => state_new <= st_setparam1;
--					when CMD_ENTER_PROGMODE_ISP =>
--						state_new <= st_ispinit1;
--						isp_idx <= 0;
--					when CMD_LEAVE_PROGMODE_ISP =>
--						state_new <= st_ispfin1;
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
--					ringptr_next := hdrptr + inlen(10 downto 0);
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

				if ringdata = PARAM_VTARGET
				   or ringdata = PARAM_VADJUST
				   or ringdata = PARAM_OSC_PSCALE
				   or ringdata = PARAM_OSC_CMATCH
				   or ringdata = PARAM_TOPCARD_DETECT
				   or ringdata = PARAM_DATA
				   or ringdata = PARAM_RESET_POLARITY then
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

				state_new <= st_fin1;

			-- *****************
			-- CMD_SET_PARAMETER
			-- *****************

			when st_setparam1 =>
				-- Write status to x0004
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

--			-- CMD_ENTER_PROGMODE_ISP
--			when st_ispinit1 =>
--				isp_regs(isp_idx) <= ringdata;
--				ringptr_next := ringptr + "1";
--				if isp_idx = isp_nregs-1 then
--					state_new <= st_ispinit2;
--				else
--					isp_idx <= isp_idx + 1;
--				end if;

--			when st_ispinit2 =>
--				-- Write status to x0004
--				txaddr <= "000" & X"04";
--				txwr <= '1';
--				msgbodylen_next := msgbodylen + "1";
--				txdata <= STATUS_CMD_OK;
--				state_new <= st_fin1;

--			-- CMD_LEAVE_PROGMODE_ISP
--			when st_ispfin1 =>
--				-- Write status to x0004
--				txaddr <= "000" & X"04";
--				txwr <= '1';
--				msgbodylen_next := msgbodylen + "1";
--				txdata <= STATUS_CMD_OK;
--				state_new <= st_fin1;


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
		strlen_new <= strlen_next;
		txstrobe_new <= txstrobe_next;

		target_new <= target_next;
		stk_rst_polarity_new <= stk_rst_polarity_next;
		stk_init_new <= stk_init_next;
		stk_sck_duration_new <= stk_sck_duration_next;
	end process;

	-- *****************
	-- Output Packet RAM
	-- *****************

	-- Storage for the STK500 response packet, also receives data from the
	-- device as needed.

	ISPringbuf : RAMB16BWER
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
		SIM_DEVICE => "SPARTAN6"
	)
	port map (
		-- Port A, READ
		DOA => RAM_OUT,     -- 32-bit output: data output
		ADDRA => RAM_OADDR, -- 14-bit input: address input, low three are unused
		CLKA => CLK,        -- 1-bit input: clock input
		ENA => '1',         -- 1-bit input: enable input
		WEA => X"0",        -- 4-bit input: byte-wide write enable input
		DIA => X"00000000", -- 32-bit input: data input
		DIPA => "0000",     -- 4-bit input: parity input
		REGCEA => '0',      -- 1-bit input: register clock enable input
		RSTA => '0',        -- 1-bit input: register set/reset input
		-- Port B, WRITE
		DIB => RAM_IN,      -- 32-bit input: data input
		ADDRB => RAM_IADDR, -- 14-bit input: address input, low three are unused
		CLKB => clk,        -- 1-bit input: clock input
		ENB => '1',         -- 1-bit input: enable input
		WEB => RAM_WEN,     -- 4-bit input: byte-wide write enable input, must all be 1 or odd bytes won't be written
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);

end Behavioral;
