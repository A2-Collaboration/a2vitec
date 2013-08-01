library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.helpers_std.all;

entity eventid_recv is
	port(
		CLK               : in  std_logic; -- must be 100 MHz!
		TIMER_TICK_1US_IN : in  std_logic; -- 1 micro second tick, synchronous to CLK

		-- Module inputs
		SERIAL_IN         : in  std_logic; -- serial raw in, externally clock'ed at 12.5 MHz
		EXT_TRG_IN        : in  std_logic; -- external trigger in, ~10us later
		-- the external trigger id is sent on SERIAL_IN

		EVENTID_OUT  : out std_logic_vector(31 downto 0); 
		DEBUG_OUT    : out std_logic_vector(31 downto 0)
	);
end entity;

--A2 trigger format of SERIAL_IN
--Startbit		: "1"
--Trig.nr.		: 32bit (but only ~20bit used at the moment)
--Paritybit		: "0" or "1" 
--Stopbit/Controlbit: "1"
--Parity check over trig Nr and parity bit



architecture arch1 of eventid_recv is

	-- 500 us ticks
	-- time until trigger id can be received;
	constant timeoutcnt_Max : integer                           := 500;
	signal timeoutcnt       : integer range 0 to timeoutcnt_Max := timeoutcnt_Max;
	signal timer_tick_1us   : std_logic;

	signal shift_reg : std_logic_vector(34 downto 0);
	signal bitcnt    : integer range 0 to shift_reg'length;

	signal reg_SERIAL_IN : std_logic;
	signal done          : std_logic;

	signal data_eventid_reg : std_logic_vector(31 downto 0);
	signal data_status_reg  : std_logic_vector(4 downto 0);

	signal timeout_seen : std_logic := '0';

	signal trg_sync     : std_logic;
	signal trg_sync_old : std_logic;

	type state_t is (IDLE, WAIT_FOR_STARTBIT, WAIT1, WAIT2, WAIT3, READ_BIT, WAIT5, WAIT6, WAIT7, WAIT8, NO_TRG_ID_RECV, FINISH);
	signal state : state_t := IDLE;

begin

	timer_tick_1us <= TIMER_TICK_1US_IN;

	trg_sync <= EXT_TRG_IN when rising_edge(CLK);
	trg_sync_old   <= trg_sync when rising_edge(CLK);
	reg_SERIAL_IN  <= SERIAL_IN when rising_edge(CLK);

	-- since CLK runs at 100 MHz, we sample at 12.5MHz due to 8 WAIT states
	PROC_FSM : process
	begin
		wait until rising_edge(CLK);
		case state is
			when IDLE =>
				done <= '1';
				-- detect rising edge of trigger, if the trigger is high for a long time
				if trg_sync = '1' and trg_sync_old = '0' then
					timeout_seen <= '0';
					done         <= '0';
					timeoutcnt   <= timeoutcnt_Max;
					state        <= WAIT_FOR_STARTBIT;
				end if;

			when WAIT_FOR_STARTBIT =>
				if reg_SERIAL_IN = '1' then
					bitcnt <= shift_reg'length;
					state  <= WAIT1;
				elsif timeoutcnt = 0 then
					state <= NO_TRG_ID_RECV;
				elsif timer_tick_1us = '1' then
					timeoutcnt <= timeoutcnt - 1;
				end if;

			when WAIT1 =>
				state <= WAIT2;
			when WAIT2 =>
				state <= WAIT3;
			when WAIT3 =>
				state <= READ_BIT;

			when READ_BIT =>            -- actually WAIT4, but we read here, in the middle of
				-- the serial line communication
				bitcnt    <= bitcnt - 1;
				-- we fill the shift_reg LSB first since this way the trg id arrives
				shift_reg <= reg_SERIAL_IN & shift_reg(shift_reg'high downto 1);
				state     <= WAIT5;

			when WAIT5 =>
				-- check if we're done reading
				if bitcnt = 0 then
					state <= FINISH;
				else
					state <= WAIT6;
				end if;

			when WAIT6 =>
				state <= WAIT7;
			when WAIT7 =>
				state <= WAIT8;
			when WAIT8 =>
				state <= WAIT1;

			when NO_TRG_ID_RECV =>
				-- we received no id after a trigger within the timeout, so
				-- set bogus trigger id and no control bit (forces error flag set!)
				shift_reg    <= b"00" & x"ffffffff" & b"1";
				state        <= FINISH;
				timeout_seen <= '1';

			when FINISH =>
				-- wait until serial line is idle again
				if reg_SERIAL_IN = '0' then
					state <= IDLE;
				end if;
				done <= '1';
		end case;

	end process;

	PROC_REG_INFO : process
	begin
		wait until rising_edge(CLK);
		data_status_reg  <= (others => '0');
		data_eventid_reg <= (others => '0');
		if done = '1' then
			data_eventid_reg <= shift_reg(32 downto 1);

			data_status_reg(1) <= shift_reg(0);
			data_status_reg(2) <= xor_all(shift_reg(33 downto 1));
			data_status_reg(3) <= shift_reg(34);
			data_status_reg(4) <= timeout_seen;

			-- check if start and control bit is 1 and parity is okay
			if shift_reg(34) = '1' and shift_reg(0) = '1' and xor_all(shift_reg(33 downto 1)) = '0' then
				-- set error flag low
				data_status_reg(0) <= '0';
			else
			  -- set error flag high
				data_status_reg(0) <= '1';
			end if;
		end if;
	end process;

	DEBUG_OUT <= x"00000" & b"0" & std_logic_vector(to_unsigned(bitcnt, 6)) & data_status_reg; 
	EVENTID_OUT <= data_eventid_reg;

end architecture;
