library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity vitek_cpld_xc9536 is
	port(
		-- the port names here follow the VITEK board 
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
		PORT_READ : in  std_logic;
		PORT_CLK  : in  std_logic;
		-- input for the address 0-f (binary coded)
		SWITCH1   : in  std_logic_vector(3 downto 0)
	);
end vitek_cpld_xc9536;

architecture arch1 of vitek_cpld_xc9536 is
	signal clk                       : std_logic;
	signal board_address             : std_logic_vector(3 downto 0);
	signal fpga_start, fpga_finished : std_logic;

	type state_type is (s_idle, s_check_address, s_wait_for_datastrobe, s_wait_for_fpga, s_wait_for_master);
	signal state : state_type := s_idle;

begin
	-- Falling edge of V_AS (address strobe) indicates
	-- valid I_A and I_AM. Thus latch-in those signals at the
	-- SN74LVC574 using the "clock" A_CLK
	-- this only happens if we're idle (supporting "address pipelining", see VME Spec)
	A_CLK <= '1' when V_AS = '0' and state = s_idle else '0';

	-- communicate with the FPGA about the VME stuff
	fpga_finished <= C_F_in(1);

	C_F_out <= (
			4      => V_DS(1),          -- high if odd byte requested (needed for consistent single byte writes!)
			5      => V_WRITE,          -- high if we should output something on databus (read cycle)
			6      => fpga_start,       -- high if FPGA can start working now
			others => '0'               -- others are unused
		);

	-- use the 16MHz VME bus clock for synchronized logic
	clk <= V_SYSCLK;

	-- I_A(15) not in use currently
	board_address <= I_A(14 downto 11);

	fsm : process is
	begin
		wait until rising_edge(clk);

		case state is
			when s_idle =>
				-- do nothing and stay idle unless:
				-- 1) address strobe is asserted (active low)
				-- 2) LWORD is high (maximum double byte access with 16 data lines)
				if V_AS = '0' and V_LWORD = '1' then
					-- go to the check address state, giving the latch enough time 
					-- to propagate I_AM and I_A 
					state <= s_check_address;
				end if;
				-- always set some default values
				DTACK      <= '0';      -- inverted, i.e. set this signal high to assert V_DTACK on VMEbus (=low)
				B_OE       <= '0';      -- enable the transceiver for the 16 VMEbus data lines
				B_DIR      <= '0';      -- listen on VMEbus (high-Z on B-Port = VMEbus side)
				fpga_start <= '0';      -- tell the FPGA to idle 

			when s_check_address =>
				-- check if the master wants to talk to us:
				-- 1) the address modifier says Short IO (privileged or unprivileged = x"2d" or x"29")
				-- 2) the "board address" (determined by the switch) matches 
				-- 3) data_strobe is high, thus double byte access requested
				if (I_AM = b"101101" or I_AM = b"101001") and board_address = SWITCH1 then
					state <= s_wait_for_datastrobe;
				else
					-- the master didn't mean us, return to idle
					state <= s_idle;
				end if;

			when s_wait_for_datastrobe =>
				-- single byte transfers and double byte transfers 
				-- should be supported
				if V_DS(0) = '0' or V_DS(1) = '0' then
					-- we may drive the VME bus now (or read it)
					B_DIR      <= V_WRITE;
					fpga_start <= '1';
					state      <= s_wait_for_fpga;
				else
					-- Could be that this was an Address-Only cycle,
					-- or previous cycle not finished yet. 
					-- Then go through the previous states again 
					-- (thus works as a two clock cycles delay)
					state <= s_idle;
				end if;

			when s_wait_for_fpga =>
				if fpga_finished = '1' then
					DTACK <= '1';
					state <= s_wait_for_master;
				end if;

			when s_wait_for_master =>
				-- wait until master has seen the DTACK
				if V_DS(0) = '1' and V_DS(1) = '1' then
					-- be conservative and release the DTACK only in the idle state
					-- but turn the transceiver to High-Z now
					B_DIR      <= '0';
					fpga_start <= '0';
					state      <= s_idle;
				end if;
		end case;
	end process fsm;

end arch1;

