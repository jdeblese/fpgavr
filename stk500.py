import sys, logging
from serial.serialposix import Serial
import struct

# STK message constants
MESSAGE_START = '\x1B'
TOKEN         = '\x0E'

# STK general command constants
CMD_SIGN_ON               = '\x01'
CMD_SET_PARAMETER         = '\x02'
CMD_GET_PARAMETER         = '\x03'
CMD_SET_DEVICE_PARAMETERS = '\x04'
CMD_OSCCAL                = '\x05'
CMD_LOAD_ADDRESS          = '\x06'
CMD_FIRMWARE_UPGRADE      = '\x07'


# STK ISP command constants
CMD_ENTER_PROGMODE_ISP  = '\x10'
CMD_LEAVE_PROGMODE_ISP  = '\x11'
CMD_CHIP_ERASE_ISP      = '\x12'
CMD_PROGRAM_FLASH_ISP   = '\x13'
CMD_READ_FLASH_ISP      = '\x14'
CMD_PROGRAM_EEPROM_ISP  = '\x15'
CMD_READ_EEPROM_ISP     = '\x16'
CMD_PROGRAM_FUSE_ISP    = '\x17'
CMD_READ_FUSE_ISP       = '\x18'
CMD_PROGRAM_LOCK_ISP    = '\x19'
CMD_READ_LOCK_ISP       = '\x1A'
CMD_READ_SIGNATURE_ISP  = '\x1B'
CMD_READ_OSCCAL_ISP     = '\x1C'
CMD_SPI_MULTI           = '\x1D'

# STK PP command constants
CMD_ENTER_PROGMODE_PP   = '\x20'
CMD_LEAVE_PROGMODE_PP   = '\x21'
CMD_CHIP_ERASE_PP       = '\x22'
CMD_PROGRAM_FLASH_PP    = '\x23'
CMD_READ_FLASH_PP       = '\x24'
CMD_PROGRAM_EEPROM_PP   = '\x25'
CMD_READ_EEPROM_PP      = '\x26'
CMD_PROGRAM_FUSE_PP     = '\x27'
CMD_READ_FUSE_PP        = '\x28'
CMD_PROGRAM_LOCK_PP     = '\x29'
CMD_READ_LOCK_PP        = '\x2A'
CMD_READ_SIGNATURE_PP   = '\x2B'
CMD_READ_OSCCAL_PP      = '\x2C'
CMD_SET_CONTROL_STACK   = '\x2D'

# STK HVSP command constants
CMD_ENTER_PROGMODE_HVSP = '\x30'
CMD_LEAVE_PROGMODE_HVSP = '\x31'
CMD_CHIP_ERASE_HVSP     = '\x32'
CMD_PROGRAM_FLASH_HVSP  = '\x33'
CMD_READ_FLASH_HVSP     = '\x34'
CMD_PROGRAM_EEPROM_HVSP = '\x35'
CMD_READ_EEPROM_HVSP    = '\x36'
CMD_PROGRAM_FUSE_HVSP   = '\x37'
CMD_READ_FUSE_HVSP      = '\x38'
CMD_PROGRAM_LOCK_HVSP   = '\x39'
CMD_READ_LOCK_HVSP      = '\x3A'
CMD_READ_SIGNATURE_HVSP = '\x3B'
CMD_READ_OSCCAL_HVSP    = '\x3C'

# STK status constants
## Success
STATUS_CMD_OK = '\x00'
## Warnings
STATUS_CMD_TOUT          = '\x80'
STATUS_RDY_BSY_TOUT      = '\x81'
STATUS_SET_PARAM_MISSING = '\x82'
## Errors
STATUS_CMD_FAILED  = '\xC0'
STATUS_CKSUM_ERROR = '\xC1'
STATUS_CMD_UNKNOWN = '\xC9'

# STK parameter constants
PARAM_BUILD_NUMBER_LOW  = '\x80'
PARAM_BUILD_NUMBER_HIGH = '\x81'
PARAM_HW_VER            = '\x90'
PARAM_SW_MAJOR          = '\x91'
PARAM_SW_MINOR          = '\x92'
PARAM_VTARGET           = '\x94'
PARAM_VADJUST           = '\x95'
PARAM_OSC_PSCALE        = '\x96'
PARAM_OSC_CMATCH        = '\x97'
PARAM_SCK_DURATION      = '\x98'
PARAM_TOPCARD_DETECT    = '\x9A'
PARAM_STATUS            = '\x9C'
PARAM_DATA              = '\x9D'
PARAM_RESET_POLARITY    = '\x9E'
PARAM_CONTROLLER_INIT   = '\x9F'

# STK answer constants
ANSWER_CKSUM_ERROR = '\xB0'

__seq = 40

def execute(serial, data) :
	global __seq

	assert type(serial) == Serial
	assert len(data) <= 65535

	txbuf = bytearray(MESSAGE_START + '%c%c%c' % (__seq, len(data)>>8, len(data)%256) + TOKEN + data)
	txbuf += '%c' % reduce(lambda a,b: a^b, txbuf)
	print " Sending: "+' '.join(['%2.2X'%c for c in txbuf])

	serial.write(txbuf)

	rxhead = serial.read(5)

	assert len(rxhead) == 5
	print " Received header: "+' '.join(['%2.2X'%c for c in bytearray(rxhead)])
	assert rxhead[0] == MESSAGE_START and rxhead[4] == TOKEN
	(rxseq,rxlen) = struct.unpack('>xBHx', rxhead)
	assert rxseq == __seq
	rxdata = serial.read(rxlen)
	print " Received data: "+' '.join(['%2.2X'%c for c in bytearray(rxdata)])
	assert len(rxdata) == rxlen
	print " Checksum: %2.2X"%struct.unpack('B',serial.read(1))
	print " Shoud be: %X"%reduce(lambda a,b: a^b, bytearray(rxhead + rxdata))
#	assert struct.unpack('B', serial.read(1)) == reduce(lambda a,b: a^b, bytearray(rxhead + rxdata))

	__seq = (__seq + 1 if __seq < 256 else 0)

	return rxdata

def get_param(serial, param) :
	ans = execute(serial, CMD_GET_PARAMETER + param)
	assert len(ans) >= 2  # Only 2 if failed
	(cmd, stat, val) = struct.unpack('ccB', ans)
	assert cmd == CMD_GET_PARAMETER
	assert stat == STATUS_CMD_OK
	return val

if __name__ == "__main__" :
	import serial
	port = serial.Serial('/dev/ttyUSB0', baudrate=115200, timeout=1)

	ans = execute(port, CMD_SIGN_ON)
	(cmd, stat, alen) = struct.unpack('ccB', ans[0:3])
	assert cmd == CMD_SIGN_ON
	assert stat == STATUS_CMD_OK
	assert len(ans) == alen + 3
	print "Device is '" + ans[3:] + "'"

	print 'HW Build %2.2X%2.2X' % (get_param(port, PARAM_BUILD_NUMBER_HIGH), get_param(port, PARAM_BUILD_NUMBER_LOW))

	print 'Top card ID is 0x%2.2X' % get_param(port, PARAM_TOPCARD_DETECT)
	print 'Hardware version is 0x%2.2X' % get_param(port, PARAM_HW_VER)
	print 'Software version is %d.%d' % (get_param(port, PARAM_SW_MAJOR),get_param(port, PARAM_SW_MINOR))

