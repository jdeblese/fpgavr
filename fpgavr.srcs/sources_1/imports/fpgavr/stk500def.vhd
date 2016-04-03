library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package stk500def is
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

end package stk500def;
