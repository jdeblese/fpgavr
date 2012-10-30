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

entity fsm_stktx is
	Port (
		uart_strobe : out std_logic;
		uart_data   : out std_logic_vector(7 downto 0);
		uart_busy   : in  std_logic;
		buffer_addr   : in  std_logic_vector(10 downto 0);
		buffer_data   : in  std_logic_vector(7 downto 0);
		buffer_wren	  : in  std_logic;
		strobe : in  std_logic;
		busy   : out std_logic;
		clk : in  STD_LOGIC;
		rst : in  STD_LOGIC);
end fsm_stktx;

architecture Behavioral of fsm_stktx is
	signal ADDRA : std_logic_vector(13 downto 0);
	signal DATAA : std_logic_vector(31 downto 0);
	signal ADDRB : std_logic_vector(13 downto 0);
	signal DATAB : std_logic_vector(31 downto 0);

	signal readaddr : std_logic_vector(10 downto 0);
	signal readdata : std_logic_vector(7 downto 0);

	signal data : std_logic_vector(7 downto 0);
	signal datamux : std_logic_vector(1 downto 0);
	signal datalen : std_logic_vector(15 downto 0);
	signal databyte : std_logic_vector(16 downto 0);

	signal cksum : std_logic_vector(7 downto 0);
	signal cksum_en : std_logic;

	signal active : std_logic;

	signal tick : std_logic_vector(1 downto 0);

begin

	-- Algorith
	-- While waiting for a strobe, dispatch writes an STK packet
	--   into the buffer, prefixing it with its sequence number and length
	-- On strobe, this fsm starts transmitting a packet, reading
	--   the packet lenth and data as needed
	-- Busy is asserted during a transmit

	busy <= active;
	uart_data <= data;

	calcsum : process(rst, clk)
		variable old : std_logic_vector(1 downto 0);
	begin
		if rst = '1' then
			cksum <= (others => '0');
		elsif rising_edge(clk) then
			if active = '0' then
				cksum <= (others => '0');
			elsif old = "01" and tick = "10" and datamux /= "11" then
				cksum <= data xor cksum;
			end if;
			old := tick;
		end if;
	end process;

	-- UART data mux
	with datamux select
		data <= MESSAGE_START when "00",
		        TOKEN         when "01",
		        readdata      when "10",
		        cksum         when others;

	-- Data mux driver
	process(databyte,datalen)
	begin
		if databyte = "0" & X"0000" then
			datamux <= "00";  -- message start
			readaddr <= (others => '0');
		elsif databyte = "0" & X"0001" then
			datamux <= "10";  -- sequence number
			readaddr <= "000" & X"00";
		elsif databyte = "0" & X"0002" then
			datamux <= "10";  -- message size msb
			readaddr <= "000" & X"01";
		elsif databyte = "0" & X"0003" then
			datamux <= "10";  -- message size lsb
			readaddr <= "000" & X"02";
		elsif databyte = "0" & X"0004" then
			datamux <= "01";  -- token
			readaddr <= (others => '0');
		elsif databyte = X"5" + datalen then
			datamux <= "11";  -- checksum
			readaddr <= (others => '0');
		else
			datamux <= "10";  -- message body
			readaddr <= ("111" & X"FE") + databyte(10 downto 0);
		end if;
	end process;

	-- Wait for strobe
	-- Zero the byte counter
	-- Loop
	--   Set the data source
	--   Stobe the transmitter
	--   Wait for busy to end
	--   Increment the byte counter

	process(rst,clk)
	begin
		if rst = '1' then
			datalen <= (others => '0');
		elsif rising_edge(clk) then
			if tick = "10" and databyte = "0" & X"0002" then
				datalen(15 downto 8) <= readdata;
			elsif tick = "10" and databyte = "0" & X"0003" then
				datalen(7 downto 0) <= readdata;
			end if;
		end if;
	end process;

	process(rst,clk)
	begin
		if rst = '1' then
			databyte <= (others => '0');
			active <= '0';
			uart_strobe <= '0';
			tick <= "00";
		elsif falling_edge(clk) then
			uart_strobe <= '0';

			if active = '0' and strobe = '1' then
				active <= '1';
				databyte <= (others => '1');
				tick <= "00";
			elsif active = '1' then
				if tick = "00" then  -- Increment the byte counter, setting the output data
					if databyte = X"5" + datalen then
						active <= '0';
					else
						databyte <= databyte + "1";
						tick <= "01";
					end if;
				elsif tick = "01" then  -- Strobe the UART
					uart_strobe <= '1';
					tick <= "10";
				elsif tick = "10" then  -- Wait for the UART to go busy
					if uart_busy = '1' then
						tick <= "11";
					end if;
				elsif tick = "11" then  -- Wait for the UART to finish
					if uart_busy = '0' then
						tick <= "00";
					end if;
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
		-- Port A, read_only
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
		ENB => buffer_wren, -- 1-bit input: enable input
		WEB => "1111",      -- 4-bit input: byte-wide write enable input, must all be 1 or odd bytes won't be written
		DIB => DATAB,       -- 32-bit input: data input
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);

	ADDRA <= readaddr & "000";
	readdata <= DATAA(7 downto 0);

	ADDRB <= buffer_addr & "000";
	DATAB <= X"000000" & buffer_data;

end Behavioral;
