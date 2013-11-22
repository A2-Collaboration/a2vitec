library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_updater is
	port(
		clk                  : in  std_logic;
		-- NIM / ECL raw inputs
		O_NIM                : out std_logic_vector(4 downto 1); -- NIM output
		I_NIM                : in  std_logic_vector(4 downto 1); -- NIM input
		EO                   : out std_logic_vector(16 downto 1); -- ECL output
		EI                   : in  std_logic_vector(16 downto 1); -- ECL input

		-- ram interface which is constantly updated
		b_wr                 : out std_logic;
		b_addr               : out std_logic_vector(3 downto 0);
		b_din                : out std_logic_vector(15 downto 0);
		b_dout               : in  std_logic_vector(15 downto 0);

		-- event id stuff
		EVENTID_IN           : in  std_logic_vector(31 downto 0);
		EVENTID_STATUS_IN    : in  std_logic_vector(4 downto 0);

		-- bitpattern stuff
		BITPATTERN_IN        : in  std_logic_vector(31 downto 0);
		BITPATTERN_STATUS_IN : in  std_logic_vector(4 downto 0)
	);
end entity ram_updater;

architecture RTL of ram_updater is
	signal state : unsigned(3 downto 0) := (others => '0');

	-- signals needed to handle the IRQ/ACK signals
	signal eventid_in_reg                            : std_logic_vector(31 downto 0);
	signal eventid_upper_reg                         : std_logic_vector(31 downto 16);
	signal eventid_status_in_reg, eventid_status_reg : std_logic_vector(4 downto 0);

	signal bitpattern_in_reg                               : std_logic_vector(31 downto 0);
	signal bitpattern_full_reg                             : std_logic_vector(31 downto 0);
	signal bitpattern_status_in_reg, bitpattern_status_reg : std_logic_vector(4 downto 0);

	signal ack_sig, ack_sig_prev   : std_logic;
	signal irq, irq_prev, irq_edge : std_logic := '0';

begin
	-- ack signal used to buffer its state in the ram
	O_NIM(1) <= ack_sig;

	-- we did not combine the NIM outputs since this complicates ensuring 
	-- the "atomic" VME read/writes
	-- this is not the most flexible approach, but it's good start (maybe a multiplexer is better?)

	b_addr <= std_logic_vector(state);

	io_1 : process is
	begin
		wait until rising_edge(clk);
		-- we always cycle through the addresses
		-- that results in an update cycle of 16*clockcycle = 160ns,
		-- which is much faster than the VMEbus reads/writes
		state <= state + 1;

		EVENTID_IN_reg        <= EVENTID_IN;
		EVENTID_STATUS_IN_reg <= EVENTID_STATUS_IN;

		BITPATTERN_IN_reg        <= BITPATTERN_IN;
		BITPATTERN_STATUS_IN_reg <= BITPATTERN_STATUS_IN;

		-- precise timing is needed here, and don't get confused who is writing what from where :)
		-- reading from memory needs waiting one cycle after setting the address, thus previous address is relevant
		-- writing to memory needs setting the data ahead, thus next address is relevant
		case state is
			when b"0000" =>
				-- previous address is b"1111", next address is b"0001"
				-- just pull down wr again
				b_wr <= '0';

			when b"0001" =>
				-- previous address is b"0000", next address is b"0010"
				-- read NIM input into memory
				b_wr  <= '1';
				b_din <= x"000" & I_NIM;

			when b"0010" =>
				-- previous address is b"0001", next address is b"0011"  
				-- output ECL from memory
				EO   <= b_dout;
				b_wr <= '0';

			when b"0011" =>
				-- previous address is b"0010", next address is b"0100"
				-- latch now the 32bit words from the eventid receiver, since they might change
				-- during the next four states, thus we write the latched data into the RAM
				eventid_status_reg    <= EVENTID_STATUS_IN_reg;
				eventid_upper_reg     <= EVENTID_IN_reg(31 downto 16); -- only upper half is needed
				-- do the same with the bitpattern reg, but we need both halfs (written later!)
				bitpattern_status_reg <= BITPATTERN_STATUS_IN_reg;
				bitpattern_full_reg   <= BITPATTERN_IN_reg; -- full reg is needed!  
				-- write lower eventid now (next address is b"100")
				b_wr                  <= '1';
				b_din                 <= EVENTID_IN_reg(15 downto 0);
				-- use the upper bit b_din(15) as a edge detection on irq signal
				irq                   <= I_NIM(1);
				irq_prev              <= irq;
				ack_sig_prev          <= ack_sig;
				if irq = '1' and irq_prev = '0' then
					-- with 160ns period, a rising edge detected
					irq_edge <= '1';
				elsif ack_sig_prev = '1' and ack_sig = '0' then
					-- falling edge on ack (again 160ns period, much faster than VME)
					-- clear the interrupt edge detected bit again
					irq_edge <= '0';
				end if;

			when b"0100" =>
				-- previous address is b"0011", next address is b"0101"
				-- output NIM from memory,
				-- but lowest bit is stored in signal [directly connected to O_NIM(1)]
				O_NIM(4 downto 2) <= b_dout(3 downto 1);
				ack_sig           <= b_dout(0);
				-- write upper eventid
				b_wr              <= '1';
				b_din             <= eventid_upper_reg;

			when b"0101" =>
				-- previous address is b"0100", next address is b"0110"
				-- write lower status word and 
				b_wr  <= '1';
				b_din <= irq_edge & b"00" & bitpattern_status_reg & b"000" & eventid_status_reg;

			when b"0110" =>
				-- previous address is b"0101", next address is b"0111"  
				-- write firmware information:
				-- upper 8 bits are the type. currently there's only "aa" (general purpose)
				-- lower 8 bits give firmware revision, this is revision 1
				b_wr  <= '1';
				b_din <= x"aa04";

			when b"0111" =>
				-- previous address is b"0110", next address is b"1000"
				-- write lower part of bitpattern
				b_wr  <= '1';
				b_din <= bitpattern_full_reg(15 downto 0);

			when b"1000" =>
				-- previous address is b"0111", next address is b"1001"
				-- write upper part of bitpattern
				b_wr  <= '1';
				b_din <= bitpattern_full_reg(31 downto 16);

			-- some unused states here, when => others takes care of it 

			when b"1111" =>
				-- write ECL input into memory
				b_wr  <= '1';
				b_din <= EI;

			when others => null;
		end case;
	end process io_1;

end architecture RTL;
