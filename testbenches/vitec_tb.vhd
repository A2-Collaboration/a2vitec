library IEEE;
use ieee.std_logic_1164.all;

-- this entity "simulates" the VITEC board 
-- (and also the Trenz micromodule)
-- it mainly tests the VME bus access
use work.helpers_std.all;

entity vitec_tb is
end entity vitec_tb;

architecture arch1 of vitec_tb is
	component vitec_cpld_xc9536
		port(A_CLK     : out std_logic;
			   V_SYSCLK  : in  std_logic;
			   V_DS      : in  std_logic_vector(1 downto 0);
			   V_WRITE   : in  std_logic;
			   V_LWORD   : in  std_logic;
			   V_AS      : in  std_logic;
			   DTACK     : out std_logic;
			   I_AM      : in  std_logic_vector(5 downto 0);
			   I_A       : in  std_logic_vector(15 downto 11);
			   C_F_in    : in  std_logic_vector(3 downto 1);
			   C_F_out   : out std_logic_vector(7 downto 4);
			   B_OE      : out std_logic;
			   B_DIR     : out std_logic;
			   PORT_READ : out std_logic;
			   PORT_CLK  : out std_logic;
			   SWITCH1   : in  std_logic_vector(3 downto 0));
	end component vitec_cpld_xc9536;

	component vitec_fpga_xc3s1000
		port(CLK60_IN         : in    std_logic;
			   UTMI_databus16_8 : out   std_logic;
			   UTMI_reset       : out   std_logic;
			   UTMI_xcvrselect  : out   std_logic;
			   UTMI_termselect  : out   std_logic;
			   UTMI_opmode1     : out   std_logic;
			   UTMI_txvalid     : out   std_logic;
			   LED_module       : out   std_logic;
			   O_NIM            : out   std_logic_vector(4 downto 1);
			   I_NIM            : in    std_logic_vector(4 downto 1);
			   EO               : out   std_logic_vector(16 downto 1);
			   EI               : in    std_logic_vector(16 downto 1);
			   A_X              : out   std_logic_vector(8 downto 1);
			   OHO_RCLK         : out   std_logic;
			   OHO_SCLK         : out   std_logic;
			   OHO_SER          : out   std_logic;
			   V_V25            : out   std_logic_vector(8 downto 1);
			   V_V33            : out   std_logic_vector(10 downto 9);
			   D_IN             : out   std_logic_vector(5 downto 1);
			   D_OUT            : in    std_logic_vector(5 downto 1);
			   D_D              : out   std_logic;
			   D_Q              : out   std_logic;
			   D_MS             : out   std_logic;
			   D_LE             : out   std_logic;
			   D_CLK            : out   std_logic;
			   F_D              : inout std_logic_vector(15 downto 0);
			   C_F_in           : out   std_logic_vector(3 downto 1);
			   C_F_out          : in    std_logic_vector(7 downto 4);

			   I_A              : in    std_logic_vector(10 downto 1));
	end component vitec_fpga_xc3s1000;

	component SN74LVTH162245DL
		generic(INPUTS : integer);
		port(OE  : in    std_logic;
			   DIR : in    std_logic;
			   A   : inout std_logic_vector(INPUTS - 1 downto 0);
			   B   : inout std_logic_vector(INPUTS - 1 downto 0));
	end component SN74LVTH162245DL;

	component SN74LVC574APWT
		generic(INPUTS : integer);
		port(clk : in  std_logic;
			   D   : in  std_logic_vector(INPUTS - 1 downto 0);
			   Q   : out std_logic_vector(INPUTS - 1 downto 0));
	end component SN74LVC574APWT;

	component SN74LVTH125PW
		generic(INPUTS : integer);
		port(OE : in  std_logic;
			   I  : in  std_logic_vector(INPUTS - 1 downto 0);
			   O  : out std_logic_vector(INPUTS - 1 downto 0));
	end component SN74LVTH125PW;

	constant period : time := 16.67 ns; -- 60MHz clock (from UTMI)
	signal clk      : std_logic;

	constant period_vme : time := 62.5 ns; -- 16MHz clock (from VMEbus)
	signal V_SYSCLK     : std_logic;

	constant period_serial : time := 80 ns; -- 12.5MHz clock (from VMEbus)


	-- CPLD signals
	signal A_CLK          : std_logic;
	signal V_DS           : std_logic_vector(1 downto 0);
	signal V_WRITE        : std_logic;
	signal V_LWORD        : std_logic;
	signal V_AS           : std_logic;
	signal DTACK, V_DTACK : std_logic;
	signal I_AM, V_AM     : std_logic_vector(5 downto 0);
	signal I_A, V_A       : std_logic_vector(15 downto 1) := (others => '0');
	signal C_F_in         : std_logic_vector(3 downto 1);
	signal C_F_out        : std_logic_vector(7 downto 4);
	signal B_OE           : std_logic;
	signal B_DIR          : std_logic;
	signal PORT_READ      : std_logic;
	signal PORT_CLK       : std_logic;
	signal SWITCH1        : std_logic_vector(3 downto 0);

	-- FPGA signals
	signal F_D, V_D         : std_logic_vector(15 downto 0);
	signal I_NIM, O_NIM     : std_logic_vector(4 downto 1);
	signal I_NIM_n, O_NIM_n : std_logic_vector(4 downto 1);
	signal EI, EO           : std_logic_vector(16 downto 1);
	signal D_OUT            : std_logic_vector(5 downto 1);

	-- Port Mode signals, all in one
	signal PORT_TDI_TCK_TMS : std_logic_vector(3 downto 1);
	signal PORT_REG_Q       : std_logic_vector(7 downto 0);
begin
	clock_driver : process
	begin
		clk <= '0';
		wait for period / 2;
		clk <= '1';
		wait for period / 2;
	end process clock_driver;

	clock_driver_vme : process
	begin
		V_SYSCLK <= '0';
		wait for period_vme / 2;
		V_SYSCLK <= '1';
		wait for period_vme / 2;
	end process clock_driver_vme;

	-- instantiate CPLD
	V_DTACK <= not DTACK;               -- there's a not in the schematics!
	CPLD_1 : vitec_cpld_xc9536
		port map(A_CLK     => A_CLK,
			       V_SYSCLK  => V_SYSCLK,
			       V_DS      => V_DS,
			       V_WRITE   => V_WRITE,
			       V_LWORD   => V_LWORD,
			       V_AS      => V_AS,
			       DTACK     => DTACK,
			       I_AM      => I_AM,
			       I_A       => I_A(15 downto 11),
			       C_F_in    => C_F_in,
			       C_F_out   => C_F_out,
			       B_OE      => B_OE,
			       B_DIR     => B_DIR,
			       PORT_READ => PORT_READ,
			       PORT_CLK  => PORT_CLK,
			       SWITCH1   => SWITCH1);

	-- instantiate FPGA, neglect the unneeded I/O (delay, AVC µC)
	-- Note that the NIM seems to be inverted, 
	-- don't know where that happens in the schematic
	I_NIM_n <= not I_NIM;
	O_NIM   <= not O_NIM_n;
	D_OUT   <= (others => '0');
	FPGA_1 : vitec_fpga_xc3s1000
		port map(CLK60_IN         => CLK,
			       UTMI_databus16_8 => open,
			       UTMI_reset       => open,
			       UTMI_xcvrselect  => open,
			       UTMI_termselect  => open,
			       UTMI_opmode1     => open,
			       UTMI_txvalid     => open,
			       LED_module       => open,
			       O_NIM            => O_NIM_n,
			       I_NIM            => I_NIM_n,
			       EO               => EO,
			       EI               => EI,
			       A_X              => open,
			       OHO_RCLK         => open,
			       OHO_SCLK         => open,
			       OHO_SER          => open,
			       V_V25            => open,
			       V_V33            => open,
			       D_IN             => open,
			       D_OUT            => D_OUT,
			       D_D              => open,
			       D_Q              => open,
			       D_MS             => open,
			       D_LE             => open,
			       D_CLK            => open,
			       F_D              => F_D,
			       C_F_in           => C_F_in,
			       C_F_out          => C_F_out,
			       I_A              => I_A(10 downto 1));

	-- instantiate some more ICs (to make tests more realistic)
	VME_transceiver_1 : component SN74LVTH162245DL
		generic map(INPUTS => 16)
		port map(OE  => B_OE,
			       DIR => B_DIR,
			       A   => F_D,
			       B   => V_D);

	VME_A_1 : component SN74LVC574APWT
		generic map(INPUTS => 15)
		port map(clk => A_CLK,
			       D   => V_A,
			       Q   => I_A);
	VME_AM_1 : component SN74LVC574APWT
		generic map(INPUTS => 6)
		port map(clk => A_CLK,
			       D   => V_AM,
			       Q   => I_AM);

	PORT_REG_1 : component SN74LVC574APWT
		generic map(INPUTS => 8)
		port map(clk => PORT_CLK,
			       D   => V_D(7 downto 0),
			       Q   => PORT_REG_Q);

	PORT_TDI_TCK_TMS <= PORT_REG_Q(3 downto 1);
	PORT_DRV_1 : component SN74LVTH125PW
		generic map(INPUTS => 3)        -- the TDO has no connection to Q
		port map(OE => PORT_READ,
			       I  => PORT_TDI_TCK_TMS,
			       O  => V_D(3 downto 1));

	-- now work on the VME bus as a master
	simu : process is
		constant test_word1       : std_logic_vector(15 downto 0) := x"dead";
		constant test_word2       : std_logic_vector(15 downto 0) := x"beef";
		constant test_ecl_in      : std_logic_vector(15 downto 0) := x"abcd";
		constant test_ecl_out     : std_logic_vector(15 downto 0) := x"dcba";
		constant test_nim_in      : std_logic_vector(3 downto 0)  := x"a";
		constant test_nim_out     : std_logic_vector(3 downto 0)  := x"c"; -- should be even to keep ack = O_NIM(1) low
		constant test_port        : std_logic_vector(2 downto 0)  := b"101";
		-- note that over the serial line the least significant bit is sent first!
		constant test_serial      : std_logic_vector(35 downto 1) := b"1" & bit_reverse(x"deadbeef") & b"01";
		variable test_serial_real : std_logic_vector(31 downto 0);
		variable t0, t1           : time;
	begin
		-- after some setup time, set default values
		wait for 2 * period_vme + 5 ns;
		V_AM    <= (others => '0');
		V_A     <= (others => '0');
		V_LWORD <= '1';
		V_AS    <= '1';
		V_DS    <= (others => '1');
		V_WRITE <= '1';
		V_D     <= (others => '0');
		SWITCH1 <= (others => '1');     -- SWITCH1 seems to be active low (pullup) 
		I_NIM   <= (others => '0');
		EI      <= (others => '0');

		--------------------------------------
		-- assert and release address strobe
		-- this is an address-only cycle
		t0 := now;
		report "Testing address-only cycle" severity note;
		wait for 5 ns;
		V_AS <= '0';
		wait for 50 ns;
		V_AS <= '1';
		wait for 50 ns;
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- simulate a read cycle with address pipelining
		t0 := now;
		report "Testing read cycle" severity note;
		-- set correct address
		V_AM    <= b"101101";
		V_A     <= (others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- check received data and...
		assert V_D = x"0000" report "##### Received data is not zero, that's weird" severity error;
		-- state immediately another address propagation
		-- very short "wait"s here just for testing
		V_AS <= '1';
		wait for 5 ns;
		V_AM    <= (others => '0');
		V_A     <= (others => '0');
		V_LWORD <= '0';
		wait for 5 ns;
		V_AS <= '0';
		wait for 5 ns;
		V_AS <= '1';
		-- acknowledge the data
		V_DS <= (others => '1');
		-- play with V_WRITE for testing
		wait for 5 ns;
		V_WRITE <= '0';
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		----------------------------------------
		-- simulate a write cycle with address pipelining 1
		t0 := now;
		report "Testing write cycle 1" severity note;
		-- set desired address
		V_AM    <= b"101001";
		V_A     <= (4 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= test_word1;
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack, immediately change the data for testing
		wait until V_DTACK = '0';
		V_D     <= x"ffff";
		V_WRITE <= '1';
		-- state immediately another address propagation
		-- very short "wait"s here just for testing
		V_AS    <= '1';
		wait for 5 ns;
		V_AM    <= (others => '0');
		V_A     <= (others => '0');
		V_LWORD <= '0';
		wait for 5 ns;
		V_AS <= '0';
		wait for 5 ns;
		V_AS <= '1';
		-- acknowledge the data
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------
		-- simulate a write cycle with address pipelining 2
		t0 := now;
		report "Testing write cycle 2" severity note;
		-- set desired address
		V_AM    <= b"101001";
		V_A     <= (4 => '1', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= test_word2;
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack, immediately change the data for testing
		wait until V_DTACK = '0';
		V_D     <= x"ffff";
		V_WRITE <= '1';
		-- state immediately another address propagation
		-- very short "wait"s here just for testing
		V_AS    <= '1';
		wait for 5 ns;
		V_AM    <= (others => '0');
		V_A     <= (others => '0');
		V_LWORD <= '0';
		wait for 5 ns;
		V_AS <= '0';
		wait for 5 ns;
		V_AS <= '1';
		-- acknowledge the data
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-----------------------------
		-- test with wrong address
		t0 := now;
		report "Testing with wrong board address" severity note;
		-- set correct address
		V_AM    <= b"101101";
		V_A     <= (15 => '1', 2 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 5 ns;
		V_AS <= '0';
		V_DS <= (others => '0');
		-- DTACK should stay high here
		for i in 1 to 30 loop
			assert V_DTACK = '1' report "##### DTACK went low!" severity error;
			wait for 5 ns;
		end loop;
		V_AS <= '1';
		V_DS <= (others => '1');
		-- wait a bit longer
		t1   := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		------------------------------------------
		-- Reading back the previously written data 2
		t0 := now;
		report "Reading back data 2" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101101";
		V_A     <= (4 => '1', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data and...
		assert V_D = test_word2 report "##### Received data 2 is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Reading back the previously written data 1
		t0 := now;
		report "Reading back data 1" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (4 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data and...
		assert V_D = test_word1 report "##### Received data 1 is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test the ECL in (address 00)
		t0 := now;
		report "Testing ECL in" severity note;
		-- set the input
		EI <= test_ecl_in;
		wait for 50 ns;
		-- read it over VME 
		V_AM    <= b"101001";
		V_A     <= (2 => '0', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D = test_ecl_in report "##### Received ECL data is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		EI <= (others => '0');
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test the ECL out (address 01)
		t0 := now;
		report "Testing ECL out" severity note;
		-- set desired address
		V_AM    <= b"101001";
		V_A     <= (2 => '0', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= test_ecl_out;
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack
		wait until V_DTACK = '0';
		-- acknowledge the transfer
		V_AS <= '1';
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- see if it's at the output
		assert EO = test_ecl_out report "##### Set ECL output is incorrect" severity error;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test the NIM in (address 10)
		t0 := now;
		report "Testing NIM in" severity note;
		-- set the input
		I_NIM <= test_nim_in;
		wait for 50 ns;
		-- read it over VME 
		V_AM    <= b"101001";
		V_A     <= (2 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D(3 downto 0) = test_nim_in report "##### Received NIM data is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		EI <= (others => '0');
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test the NIM out (address 11)
		t0 := now;
		report "Testing NIM out" severity note;
		-- set desired address 
		V_AM    <= b"101001";
		V_A     <= (2 => '1', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= x"000" & test_nim_out;
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack
		wait until V_DTACK = '0';
		-- acknowledge the transfer
		V_AS <= '1';
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- see if it's at the output, note that the NIM I/O is inverted at the output
		assert O_NIM = test_nim_out report "##### Set NIM output is incorrect" severity error;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test a PORT write (V_A(11) = '1')
		t0 := now;
		report "Writing something to PORT" severity note;
		-- set desired address 
		V_AM    <= b"101001";
		V_A     <= (11 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= x"000" & test_port & b"0";
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack
		wait until V_DTACK = '0';
		-- acknowledge the transfer
		V_AS <= '1';
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- see if it's at the register (the scope of the testbench ;)
		assert PORT_TDI_TCK_TMS = test_port report "##### PORT write failed" severity error;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test a PORT read (V_A(11) = '1')
		t0 := now;
		report "Reading it back from PORT" severity note;
		wait for 50 ns;
		-- read it over VME
		V_AM    <= b"101001";
		V_A     <= (11 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D(3 downto 1) = test_port report "##### PORT read failed" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Test the trigger/interrupt and the serial ID receiver
		-- send the interrupt
		t0 := now;
		report "Sending an interrupt" severity note;
		I_NIM <= (others => '0');
		wait for 50 ns;
		I_NIM(1) <= '1';
		wait for 200 ns;                -- interrupt must be at least 80ns high
		I_NIM(1) <= '0';
		wait for 1 us;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Checking the trigger (read status register)
		t0 := now;
		report "Checking the interrupt" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (3 => '1', 2 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D(15) = '1' report "##### Interrupt was not received" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Set ACK signal high (readout of other modules started)
		t0 := now;
		report "Send ACK signal strobe to O_NIM(1)" severity note;
		-- set desired address 
		V_AM    <= b"101001";
		V_A     <= (2 => '1', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= x"000" & b"0001";
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack
		wait until V_DTACK = '0';
		-- acknowledge the transfer
		V_AS <= '1';
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- see if it's at the output
		assert O_NIM = b"0001" report "##### Could not set NIM output to high" severity error;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Send the serial ID
		t0               := now;
		test_serial_real := bit_reverse(test_serial(34 downto 3));
		report "Sending the serial ID 0x" & slv2hex(test_serial_real) & " (LSB first)" severity note;
		wait for 50 ns;
		for i in test_serial'range loop
			I_NIM(2) <= test_serial(i);
			wait for period_serial;
		end loop;
		I_NIM(2) <= '0';
		-- wait a bit longer
		t1       := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Checking the event ID status (read status register)
		t0 := now;
		report "Checking the Event ID status: something received?" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (3 => '1', 2 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- id received since last ACK, start/stop bit there, parity ok, no error flag
		assert V_D(4 downto 0) = b"11010" report "##### Event ID status not as expected (parity wrong?)" severity error;
		report "Got the following: " & slv2hex(V_D) severity note;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Reading the serial id over VME (lower)
		t0 := now;
		report "Reading serial ID over VME (lower)" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (3 => '1', 2 => '0', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D = test_serial_real(15 downto 0) report "##### Lower word of serial ID is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Reading the serial id over VME (upper)
		t0 := now;
		report "Reading serial ID over VME (upper)" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (3 => '1', 2 => '0', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D = test_serial_real(31 downto 16) report "##### Upper word of serial ID is incorrect" severity error;
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		--------------------------------------
		-- Set ACK signal low (readout of other modules finished)
		t0 := now;
		report "Set ACK low" severity note;
		V_AM    <= b"101001";
		V_A     <= (2 => '1', 1 => '1', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '0';
		-- tell the address
		wait for 30 ns;
		V_AS <= '0';
		-- set the data
		V_D  <= x"000" & b"0000";
		wait for 30 ns;
		V_DS <= (others => '0');
		-- wait for data ack
		wait until V_DTACK = '0';
		-- acknowledge the transfer
		V_AS <= '1';
		V_DS <= (others => '1');
		wait until V_DTACK = '1';
		-- see if it's at the output
		assert O_NIM = b"0000" report "##### Could not set NIM output to low" severity error;
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;

		-------------------------------------------
		-- Checking the event ID status (read status register)
		t0 := now;
		report "Checking the Event ID status: IRQ reset?" severity note;
		-- set correct address
		V_AS    <= '1';
		V_AM    <= b"101001";
		V_A     <= (3 => '1', 2 => '1', 1 => '0', others => '0');
		V_LWORD <= '1';
		V_WRITE <= '1';
		V_D     <= (others => 'Z');
		wait for 30 ns;
		-- assert address strobe to tell the address
		V_AS <= '0';
		-- assert data strobe to request the data
		V_DS <= (others => '0');
		-- wait until data is present
		wait until V_DTACK = '0';
		-- immediately negate address strobe
		V_AS <= '1';
		-- check received data
		assert V_D(15) = '0' report "##### Interrupt was not reset by ACK" severity error;
		assert V_D(4) = '0' report "##### Serial ID Received was not reset by ACK" severity error;
		
		-- acknowledge the data
		V_DS <= (others => '1');
		-- and wait for slave to release the data lines
		wait until V_DTACK = '1';
		-- wait a bit longer
		t1 := now - t0;
		report "Done, took " & time'image(t1) severity note;
		wait for 500 ns;		


		--------------------------------------
		-- write something else on the bus
		V_WRITE <= '0';
		V_D     <= x"ffff";
		report "REALLY DONE" severity note;
		wait;

	end process simu;

end architecture arch1;