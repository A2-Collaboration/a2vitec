library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram_updater is
	port(
		clk        : in  std_logic;
		-- NIM / ECL raw inputs
		O_NIM      : out std_logic_vector(4 downto 1); -- NIM output
		I_NIM      : in  std_logic_vector(4 downto 1); -- NIM input
		EO         : out std_logic_vector(16 downto 1); -- ECL output
		EI         : in  std_logic_vector(16 downto 1); -- ECL input

		-- ram interface which is constantly updated
		b_wr       : out std_logic;
		b_addr     : out std_logic_vector(2 downto 0);
		b_din      : out std_logic_vector(15 downto 0);
		b_dout     : in  std_logic_vector(15 downto 0);

		-- event id stuff
		EVENTID_IN : in  std_logic_vector(31 downto 0);
		DEBUG_IN   : in  std_logic_vector(31 downto 0)
	);
end entity ram_updater;

architecture RTL of ram_updater is
	signal state : unsigned(2 downto 0) := (others => '0');

	signal eventid_upper_reg : std_logic_vector(31 downto 16);
	signal debug_reg         : std_logic_vector(31 downto 0);
begin
	-- we simply map the ECL and NIM outputs and inputs into the ram
	-- we did not combine the NIM outputs since this complicates ensuring 
	-- the "atomic" VME read/writes
	-- this is not the most flexible approach, but it's good start
	-- if there are some scalers to be implemented,
	-- they should have there own VME access (I guess)

	b_addr <= std_logic_vector(state);

	io_1 : process is
	begin
		wait until rising_edge(clk);
		-- we always cycle through the addresses
		-- that results in an update cycle of 4*clockcycle = 80ns,
		-- which is much faster than the VMEbus reads/writes
		state <= state + 1;

		-- precise timing is needed here, and don't get confused who is writing what from where :)
		-- reading from memory needs waiting one cycle after setting the address, thus previous address is relevant
		-- writing to memory needs setting the data ahead, thus next address is relevant

		case state is
			when b"000" =>
				-- previous address is b"111", next address is b"001"
				-- just pull down wr again
				b_wr  <= '0';

			when b"001" =>
				-- previous address is b"000", next address is b"010"
				-- read NIM input into memory
				b_wr  <= '1';
				b_din <= x"000" & I_NIM;

			when b"010" =>
				-- previous address is b"001", next address is b"011"  
				-- output ECL from memory
				EO   <= b_dout;
				b_wr <= '0';

			when b"011" =>
				-- previous address is b"010", next address is b"100"
				-- latch now the 32bit words from the eventid, since they might change
				-- during the next four states, thus we write the latched data into the RAM
				debug_reg         <= DEBUG_IN;
				eventid_upper_reg <= EVENTID_IN(31 downto 16); -- only upper half is needed 
				-- write lower eventid now (next address is b"100")
				b_wr              <= '1';
				b_din             <= EVENTID_IN(15 downto 0);

			when b"100" =>
				-- previous address is b"011", next address is b"101"
				-- output NIM from memory
				O_NIM <= b_dout(3 downto 0);
				-- write upper eventid
				b_wr  <= '1';
				b_din <= eventid_upper_reg;

			when b"101" =>
				-- previous address is b"100", next address is b"110"
				-- write lower debug word
				b_wr  <= '1';
				b_din <= debug_reg(15 downto 0);

			when b"110" =>
				-- previous address is b"101", next address is b"111"  
				-- write upper debug word
				b_wr  <= '1';
				b_din <= debug_reg(31 downto 16);

			when b"111" =>
				-- previous address is b"110", next address is b"000"
				-- write ECL input into memory
				b_wr  <= '1';
				b_din <= EI;

			when others => null;
		end case;
	end process io_1;

end architecture RTL;
