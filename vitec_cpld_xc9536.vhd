library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-- Note: This only fits into the VITEC CPLD if cpldfit is called with
-- '-inputs 20' and '-pterms 40'
-- You can also use the '-exhaust' option to automatically 
-- find options where cpldfit succeeds (used Xilinx ISE ver 14.3 lin64)

-- BUGFIX: Call cpldfit with '-init high'. 
-- This ensures that the first VME access works as expected.


entity vitec_cpld_xc9536 is
	port(
		-- the port names here follow the VITEC board
		-- schematic from Klaus Weindel
		A_CLK     : out std_logic;      -- controls the VME address registers
		V_SYSCLK  : in  std_logic;      -- 16MHz VME bus clock
		V_DS      : in  std_logic_vector(1 downto 0);
		V_WRITE   : in  std_logic;
		V_LWORD   : in  std_logic;
		V_AS      : in  std_logic;
		DTACK     : out std_logic;      -- Inverted V_DTACK, i.e. DTACK is active high (also drives LED)
		I_AM      : in  std_logic_vector(5 downto 0);
		I_A       : in  std_logic_vector(15 downto 11);
		C_F_in    : in  std_logic_vector(3 downto 1); -- from FPGA
		C_F_out   : out std_logic_vector(7 downto 4); -- to FPGA
		B_OE      : out std_logic;      -- enables the VME data transceiver (active low)
		B_DIR     : out std_logic;      -- chooses direction: High = A -> B = Slave -> "Master" (slaves drives VMEbus!)
		PORT_READ : out std_logic;      -- port mode: active-low enable of the four tri-state drivers 
		PORT_CLK  : out std_logic;      -- port mode: latches 8bits of the VMEbus data on rising edge, can control JTAG of FPGA
		-- input for the address 0-f (binary coded)
		SWITCH1   : in  std_logic_vector(3 downto 0)
	);
end vitec_cpld_xc9536;

architecture arch1 of vitec_cpld_xc9536 is
	signal clk : std_logic;

	signal fpga_start           : std_logic;
	signal fpga_finished_r      : std_logic;
	signal fpga_write           : std_logic;
	constant delay_dtack_cycles : integer := 3; -- determines the delay for DTACK read cycles, in FPGA and "PORT" mode
	signal delay_dtack_counter  : integer range 0 to delay_dtack_cycles - 1;

	type state_type is (s_idle, s_check_address, s_wait_for_datastrobe, s_wait_for_fpga, s_wait_for_master, s_delay_dtack, s_finish_read);
	signal state : state_type := s_idle;

	signal V_AS_r, V_LWORD_r          : std_logic;
	signal I_AM_r                     : std_logic_vector(5 downto 0);
	signal SWITCH1_n, board_address_r : std_logic_vector(3 downto 0);
	signal V_DS_r                     : std_logic_vector(1 downto 0);
	signal port_mode_r, V_WRITE_r     : std_logic;

begin
	-- Falling edge of V_AS (address strobe) indicates
	-- valid I_A and I_AM. Thus latch-in those signals at the
	-- SN74LVC574 using the "clock" A_CLK
	-- this only happens if we're idle (supporting "address pipelining", see VME Spec)
	A_CLK <= '1' when V_AS = '0' and state = s_idle else '0';

	-- communicate with the FPGA about the VME stuff
	fpga_finished_r <= C_F_in(1) when rising_edge(clk);

	C_F_out <= (
			4      => fpga_write,       -- high if we should output something on databus (read cycle)
			5      => fpga_start,       -- high if FPGA can start working now
			others => '0'               -- others are unused
		);

	-- the switch is active low and rather constant, so 
	-- don't register that input (saves resources) but invert it :)
	SWITCH1_n <= not SWITCH1;

	-- use the 16MHz VME bus clock for synchronized logic
	clk <= V_SYSCLK;

	fsm : process is
	begin
		wait until rising_edge(clk);

		case state is
			when s_idle =>
				V_AS_r    <= V_AS;
				V_LWORD_r <= V_LWORD;
				-- do nothing and stay idle unless:
				-- 1) address strobe is asserted (active low)
				-- 2) LWORD is high (maximum double byte access with 16 data lines)
				if V_AS_r = '0' and V_LWORD_r = '1' then
					-- go to the check address state, giving the latch enough time
					-- to propagate I_AM and I_A
					board_address_r <= I_A(15 downto 12);
					port_mode_r     <= I_A(11);
					I_AM_r          <= I_AM;
					state           <= s_check_address;
				end if;
				-- always set some default values
				DTACK      <= '0';      -- inverted, i.e. set this signal high to assert V_DTACK on VMEbus (= active low)
				B_OE       <= '1';      -- disable the transceiver for the 16 VMEbus data lines
				B_DIR      <= '0';      -- listen on VMEbus (high-Z on B-Port = VMEbus side)
				fpga_start <= '0';      -- tell the FPGA to idle
				fpga_write <= '0';      -- active low, but FPGA checks this only when fpga_start = '1'
				PORT_READ  <= '1';      -- active-low enable, thus the tri-state is high-Z by default on the VME databus
				PORT_CLK   <= '0';      -- nothing happens on the port clock, or reset it from previous port mode access :)

			when s_check_address =>
				-- check if the master wants to talk to us:
				-- 1) the address modifier says Short IO (privileged or unprivileged = x"2d" or x"29")
				-- 2) the "board address" (determined by the switch) matches
				-- 3) data_strobe is high, thus double byte access requested
				if (I_AM_r = b"101101" or I_AM_r = b"101001") and board_address_r = SWITCH1_n then
					state <= s_wait_for_datastrobe;
				else
					-- the master didn't mean us, return to idle
					state <= s_idle;
				end if;

			when s_wait_for_datastrobe =>
				V_DS_r    <= V_DS;
				V_WRITE_r <= V_WRITE;
				if V_DS_r(0) = '0' and V_DS_r(1) = '0' and port_mode_r = '0' then
					-- the FPGA may drive the VME bus now (or read it)
					-- only double byte transfers are currently supported
					-- single byte write attempts will trigger a timeout
					-- since DTACK is never asserted
					B_OE       <= '0';
					B_DIR      <= V_WRITE_r;
					fpga_write <= V_WRITE_r;
					fpga_start <= '1';
					state      <= s_wait_for_fpga;
				elsif (V_DS_r(0) = '0' or V_DS_r(1) = '0') and port_mode_r = '1' then
					-- the port mode can access the 3 bits V_D(3 downto 1) 
					-- connected to PORT_TDI (3), PORT_TCK (2), PORT_TMS (1), see schematic
					-- is should be completely independent from the FPGA, 
					-- also "supports" single byte transfers (not really tested)

					-- as in FPGA mode, when the master wants to read something (V_WRITE = '1'), 
					-- the slave (=the VITEC) should drive the bus
					if V_WRITE_r = '1' then
						-- we simply put the status of the FF onto the bus
						-- and acknowledge with a delayed DTACK
						PORT_READ           <= '0';
						state               <= s_delay_dtack;
						delay_dtack_counter <= delay_dtack_cycles - 1;
					else
						-- the data should be valid, so clock it in
						-- PORT_CLK will be reset in s_idle
						PORT_CLK            <= '1';
						-- we delay the DTACK by only one clock cycle (=62.5 ns),
						-- VME Spec says we should give the master at least 30ns afer DS
						state               <= s_delay_dtack;
						delay_dtack_counter <= 0;
					end if;
				else
					-- Could be that this was an Address-Only cycle,
					-- or previous cycle not finished yet.
					-- Then go through the previous states again
					-- (thus works as a two clock cycles delay or timeout for non-double byte transfers)
					state <= s_idle;
				end if;

			when s_wait_for_fpga =>
				if fpga_finished_r = '1' then
					if fpga_write = '1' then
						-- the slave is driving the bus, so delay the DTACK a bit
						-- to ensure that the data has propagated befor it's 
						-- read by the master
						state               <= s_delay_dtack;
						delay_dtack_counter <= delay_dtack_cycles - 1;
					else
						DTACK <= '1';
						state <= s_wait_for_master;
					end if;
				end if;

			when s_delay_dtack =>
				-- this state is used by FPGA and PORT mode
				if delay_dtack_counter = 0 then
					DTACK <= '1';
					state <= s_wait_for_master;
				else
					delay_dtack_counter <= delay_dtack_counter - 1;
				end if;

			when s_wait_for_master =>
				V_DS_r <= V_DS;
				-- wait until master has seen the DTACK
				if V_DS_r(0) = '1' and V_DS_r(1) = '1' then
					-- be conservative and release the DTACK only in the idle state
					-- but turn the transceivers to High-Z on both sides already now 
					B_OE       <= '1';
					PORT_READ  <= '1';
					fpga_start <= '0';
					if fpga_write = '1' then
						state <= s_finish_read;
					else
						state <= s_idle;
					end if;
				end if;

			when s_finish_read =>
				B_DIR <= '0';
				state <= s_idle;

		end case;
	end process fsm;

end arch1;
