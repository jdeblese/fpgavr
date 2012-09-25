library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity readfsm is
	Port (
		rs232_rx : in std_logic;
		ringaddr : in std_logic_vector(11 downto 0);
		ringdata : out std_logic_vector(7 downto 0);
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

	signal ringptr : std_logic_vector(11 downto 0);
	signal ring_wr : std_logic;

	signal ADDRA : std_logic_vector(14 downto 0);
	signal DATAA : std_logic_vector(32 downto 0);
	signal ADDRB : std_logic_vector(14 downto 0);
	signal DATAB : std_logic_vector(32 downto 0);

begin
	urx : uartrx port map (rx => rs232_rx, strobe=>rxstrobe, data=>rxdata, ferror=>rxerror, clk=>clk, rst=>rst);

	bootram : RAMB16BWER
	generic map (
		DATA_WIDTH_A => 8,
		DATA_WIDTH_B => 8,
		DOA_REG => 0,
		DOB_REG => 0,
		EN_RSTRAM_A => TRUE,
		EN_RSTRAM_B => TRUE,
		-- GB Bootstrap Rom
		INIT_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
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
		WEB => "0001",      -- 4-bit input: byte-wide write enable input
		DIB => DATAB,       -- 32-bit input: data input
		DIPB => "0000",     -- 4-bit input: parity input
		REGCEB => '0',      -- 1-bit input: register clock enable input
		RSTB => '0'         -- 1-bit input: register set/reset input
	);

	ADDRA <= ringaddr & "000";
	ADDRB <= ringptr & "000";
	DATAB <= X"000000" & rxdata;
	ringdata <= DATAA(7 downto 0);

	store : process(rst,clk)
	begin
		if rst = '1' then
			ring_wr <= '0';
			ringptr <= (others => '0');
		elsif rising_edge(clk) then
			ring_wr <= '0';
			if rxstrobe = '1' then
				ring_wr <= '1';
				ringptr <= ringptr + "1";
			end if;
		end if;
	end process;

end Behavioral;
