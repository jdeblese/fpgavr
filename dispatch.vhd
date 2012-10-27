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
		clk      : in STD_LOGIC;
		rst      : in STD_LOGIC);
end dispatch;

architecture Behavioral of dispatch is
	type state_type is (st_start, st_err, st_getcmd,
	    st_signon1, st_signon2,
	    st_fin1, st_fin2, st_fin3, st_fin4);
	signal state, next_state : state_type;
	
	signal inaddr : std_logic_vector(10 downto 0);
	signal inread : std_logic;

	signal bytelen : std_logic_vector(16 downto 0);
	signal byteinc : std_logic;

	signal active_cmd : std_logic_vector(7 downto 0);

	-- Parameters
	constant BUILD_NUMBER : std_logic_vector := X"0001";
	constant HW_VER       : std_logic_vector := X"01";
	constant SW_VER       : std_logic_vector := X"0001";
	signal stk_vtarget    : std_logic_vector(8 downto 0);
	signal stk_vadjust    : std_logic_vector(8 downto 0);
	signal stk_osc_pscale : std_logic_vector(8 downto 0);
	signal stk_osc_cmatch : std_logic_vector(8 downto 0);
	signal stk_sck_duration   : std_logic_vector(8 downto 0);
	signal stk_topcard_detect : std_logic_vector(8 downto 0);
	signal stk_status     : std_logic_vector(8 downto 0);
	signal stk_data       : std_logic_vector(8 downto 0);
	signal stk_rst_polarity   : std_logic;
	signal stk_init       : std_logic_vector(8 downto 0);

	-- STK message constants
	constant MESSAGE_START : std_logic_vector := X"1B";
	constant TOKEN         : std_logic_vector := X"0E";

	-- STK general command constants
	constant CMD_SIGN_ON               : std_logic_vector := X"01";
	constant CMD_SET_PARAMETER         : std_logic_vector := X"02";
	constant CMD_GET_PARAMETER         : std_logic_vector := X"03";
	constant CMD_SET_DEVICE_PARAMETERS : std_logic_vector := X"04";
	constant CMD_OSCCAL                : std_logic_vector := X"05";
	constant CMD_LOAD_ADDRESS          : std_logic_vector := X"06";
	constant CMD_FIRMWARE_UPGRADE      : std_logic_vector := X"07";

	-- STK ISP command constants
	constant CMD_ENTER_PROGMODE_ISP  : std_logic_vector := X"10";
	constant CMD_LEAVE_PROGMODE_ISP  : std_logic_vector := X"11";
	constant CMD_CHIP_ERASE_ISP      : std_logic_vector := X"12";
	constant CMD_PROGRAM_FLASH_ISP   : std_logic_vector := X"13";
	constant CMD_READ_FLASH_ISP      : std_logic_vector := X"14";
	constant CMD_PROGRAM_EEPROM_ISP  : std_logic_vector := X"15";
	constant CMD_READ_EEPROM_ISP     : std_logic_vector := X"16";
	constant CMD_PROGRAM_FUSE_ISP    : std_logic_vector := X"17";
	constant CMD_READ_FUSE_ISP       : std_logic_vector := X"18";
	constant CMD_PROGRAM_LOCK_ISP    : std_logic_vector := X"19";
	constant CMD_READ_LOCK_ISP       : std_logic_vector := X"1A";
	constant CMD_READ_SIGNATURE_ISP  : std_logic_vector := X"1B";
	constant CMD_READ_OSCCAL_ISP     : std_logic_vector := X"1C";
	constant CMD_SPI_MULTI           : std_logic_vector := X"1D";

	-- STK PP command constants
	constant CMD_ENTER_PROGMODE_PP   : std_logic_vector := X"20";
	constant CMD_LEAVE_PROGMODE_PP   : std_logic_vector := X"21";
	constant CMD_CHIP_ERASE_PP       : std_logic_vector := X"22";
	constant CMD_PROGRAM_FLASH_PP    : std_logic_vector := X"23";
	constant CMD_READ_FLASH_PP       : std_logic_vector := X"24";
	constant CMD_PROGRAM_EEPROM_PP   : std_logic_vector := X"25";
	constant CMD_READ_EEPROM_PP      : std_logic_vector := X"26";
	constant CMD_PROGRAM_FUSE_PP     : std_logic_vector := X"27";
	constant CMD_READ_FUSE_PP        : std_logic_vector := X"28";
	constant CMD_PROGRAM_LOCK_PP     : std_logic_vector := X"29";
	constant CMD_READ_LOCK_PP        : std_logic_vector := X"2A";
	constant CMD_READ_SIGNATURE_PP   : std_logic_vector := X"2B";
	constant CMD_READ_OSCCAL_PP      : std_logic_vector := X"2C";
	constant CMD_SET_CONTROL_STACK   : std_logic_vector := X"2D";

	-- STK HVSP command constants
	constant CMD_ENTER_PROGMODE_HVSP : std_logic_vector := X"30";
	constant CMD_LEAVE_PROGMODE_HVSP : std_logic_vector := X"31";
	constant CMD_CHIP_ERASE_HVSP     : std_logic_vector := X"32";
	constant CMD_PROGRAM_FLASH_HVSP  : std_logic_vector := X"33";
	constant CMD_READ_FLASH_HVSP     : std_logic_vector := X"34";
	constant CMD_PROGRAM_EEPROM_HVSP : std_logic_vector := X"35";
	constant CMD_READ_EEPROM_HVSP    : std_logic_vector := X"36";
	constant CMD_PROGRAM_FUSE_HVSP   : std_logic_vector := X"37";
	constant CMD_READ_FUSE_HVSP      : std_logic_vector := X"38";
	constant CMD_PROGRAM_LOCK_HVSP   : std_logic_vector := X"39";
	constant CMD_READ_LOCK_HVSP      : std_logic_vector := X"3A";
	constant CMD_READ_SIGNATURE_HVSP : std_logic_vector := X"3B";
	constant CMD_READ_OSCCAL_HVSP    : std_logic_vector := X"3C";

	-- STK status constants
	---- Success
	constant STATUS_CMD_OK : std_logic_vector := X"00";
	---- Warnings
	constant STATUS_CMD_TOUT          : std_logic_vector := X"80";
	constant STATUS_RDY_BSY_TOUT      : std_logic_vector := X"81";
	constant STATUS_SET_PARAM_MISSING : std_logic_vector := X"82";
	---- Errors
	constant STATUS_CMD_FAILED  : std_logic_vector := X"C0";
	constant STATUS_CKSUM_ERROR : std_logic_vector := X"C1";
	constant STATUS_CMD_UNKNOWN : std_logic_vector := X"C9";

	-- STK parameter constants
	constant PARAM_BUILD_NUMBER_LOW  : std_logic_vector := X"80";
	constant PARAM_BUILD_NUMBER_HIGH : std_logic_vector := X"81";
	constant PARAM_HW_VER            : std_logic_vector := X"90";
	constant PARAM_SW_MAJOR          : std_logic_vector := X"91";
	constant PARAM_SW_MINOR          : std_logic_vector := X"92";
	constant PARAM_VTARGET           : std_logic_vector := X"94";
	constant PARAM_VADJUST           : std_logic_vector := X"95";
	constant PARAM_OSC_PSCALE        : std_logic_vector := X"96";
	constant PARAM_OSC_CMATCH        : std_logic_vector := X"97";
	constant PARAM_SCK_DURATION      : std_logic_vector := X"98";
	constant PARAM_TOPCARD_DETECT    : std_logic_vector := X"9A";
	constant PARAM_STATUS            : std_logic_vector := X"9C";
	constant PARAM_DATA              : std_logic_vector := X"9D";
	constant PARAM_RESET_POLARITY    : std_logic_vector := X"9E";
	constant PARAM_CONTROLLER_INIT   : std_logic_vector := X"9F";

	-- STK answer constants
	constant ANSWER_CKSUM_ERROR : std_logic_vector := X"B0";

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
		elsif rising_edge(clk) then
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
			if byteinc = '1' then
				bytelen <= bytelen + "1";
			end if;
		end if;
	end process;

	-- FSM
	sync_proc : process(rst,clk)
	begin
		if rst = '1' then
			state <= st_start;
		elsif rising_edge(clk) then
			state <= next_state;
		end if;
	end process;

	-- FSM
	comb_proc : process(state,cmdstrobe,ringdata,txbusy)
	begin
		
		next_state <= state;
		inread <= '0';
		byteinc <= '1';
		txaddr <= (others => '0');
		txwr <= '0';
		txdata <= (others => '0');
		
		case state is
			when st_start =>  -- Wait for a command strobe
				if cmdstrobe = '1' then
					inread <= '1';
					next_state <= st_getcmd;
				end if;
				
			when st_getcmd =>  -- Read in the command
				active_cmd <= ringdata;

				-- Write the command to x0002
				txaddr <= "000" & X"02";
				txwr <= '1';
				txdata <= ringdata;
				byteinc <= '1';

				if ringdata = CMD_SIGN_ON then
					next_state <= st_signon1;
				else
					next_state <= st_err;
				end if;

			when st_signon1 =>
				-- Write OK to x0003
				txaddr <= "000" & X"03";
				txwr <= '1';
				txdata <= STATUS_CMD_OK;
				byteinc <= '1';

				next_state <= st_signon2;

			when st_signon2 =>
				-- Write string length 0 to x0004
				txaddr <= "000" & X"04";
				txwr <= '1';
				txdata <= X"00";
				byteinc <= '1';

				next_state <= st_fin1;

			when st_fin1 =>
				txaddr <= "000" & X"00";
				txwr <= '1';
				txdata <= bytelen(15 downto 8);
				next_state <= st_fin2;
					
			when st_fin2 =>
				txaddr <= "000" & X"01";
				txwr <= '1';
				txdata <= bytelen(7 downto 0);

				next_state <= st_fin3;
					
			when st_fin3 =>
				txstrobe <= '1';
				if txbusy = '0' then
					next_state <= st_fin3;
				else
					next_state <= st_fin4;
				end if;

			when st_fin4 =>
				if txbusy = '1' then
					next_state <= st_fin4;
				else
					next_state <= st_start;
				end if;

			when st_err =>
				next_state <= st_err;
			
			when others =>
				next_state <= state;
		end case;
	end process;
	
end Behavioral;
