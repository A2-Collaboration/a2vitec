library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vitek_fpga_xc3s1000 is
	port(
		-- signals local to the micromodule itself
		-- this is the 60 MHz clock input (selected via UTMI_databus16_8)
		CLK              : in    std_logic;
		UTMI_databus16_8 : out   std_logic; -- 1 = 30MHz, 0 = 60MHz
		UTMI_reset       : out   std_logic;
		UTMI_xcvrselect  : out   std_logic;
		UTMI_termselect  : out   std_logic;
		UTMI_opmode1     : out   std_logic;
		UTMI_txvalid     : out   std_logic;
		LED_module       : out   std_logic; -- active low

		-- the names are according to the schematic provided
		-- by Klaus Weindel
		-- general input / output
		O_NIM            : out   std_logic_vector(4 downto 1); -- NIM output
		I_NIM            : in    std_logic_vector(4 downto 0); -- NIM input
		EO               : out   std_logic_vector(16 downto 1); -- ECL output
		EI               : in    std_logic_vector(16 downto 1); -- ECL input
		A_X              : out   std_logic_vector(8 downto 1); -- AVR microprocessor
		OHO_RCLK         : out   std_logic; -- 3x7 segment display
		OHO_SCLK         : out   std_logic; -- 3x7 segment display
		OHO_SER          : out   std_logic; -- 3x7 segment display
		V_V              : out   std_logic_vector(10 downto 1); -- another VITEK card

		-- delay stuff
		D_IN             : out   std_logic_vector(5 downto 1); -- to delay input
		D_OUT            : in    std_logic_vector(5 downto 1); -- from delay ouput
		D_D              : out   std_logic;
		D_Q              : out   std_logic;
		D_MS             : out   std_logic;
		D_LE             : out   std_logic;
		D_CLK            : out   std_logic;

		-- VME / CPLD communication
		F_D              : inout std_logic_vector(15 downto 0); -- VME Data (must be tri-state!)
		C_F_in           : out   std_logic_vector(3 downto 1); -- to CPLD (= "in" port there)
		C_F_out          : in    std_logic_vector(7 downto 4); -- from CPLD (= "out" port there)
		I_A              : in    std_logic_vector(10 downto 1) -- VME address		
	);
end vitek_fpga_xc3s1000;

architecture arch1 of vitek_fpga_xc3s1000 is
	component dualportram
		generic(DATA : integer;
			      ADDR : integer);
		port(a_clk  : in  std_logic;
			   a_wr   : in  std_logic;
			   a_addr : in  std_logic_vector(ADDR - 1 downto 0);
			   a_din  : in  std_logic_vector(DATA - 1 downto 0);
			   a_dout : out std_logic_vector(DATA - 1 downto 0);
			   b_clk  : in  std_logic;
			   b_wr   : in  std_logic;
			   b_addr : in  std_logic_vector(ADDR - 1 downto 0);
			   b_din  : in  std_logic_vector(DATA - 1 downto 0);
			   b_dout : out std_logic_vector(DATA - 1 downto 0));
	end component dualportram;

	-- VME stuff: Write to/Read from dualportram (=memory), 
	-- handle CPLD (which does the VME communication)
	type vme_state_type is (s_vme_idle, s_vme_write, s_vme_read, s_vme_finish);
	signal vme_state                 : vme_state_type := s_vme_idle;
	signal vme_wr                    : std_logic;
	constant vme_addr_size           : integer        := 3; -- 2^3=8 vme registers maximum (currently)
	signal vme_addr                  : std_logic_vector(vme_addr_size - 1 downto 0);
	signal vme_din, vme_dout         : std_logic_vector(31 downto 0);
	signal fpga_start, fpga_finished : std_logic;
	signal V_WRITE                   : std_logic;

begin

	-- Configure USB chip on micromodule (UTMI USB3250), 
	-- currently only used as convenient clock source
	UTMI_databus16_8 <= '0';            -- change to 1 to get 30MHz CLK instead of 60MHz
	UTMI_reset       <= '0';
	UTMI_xcvrselect  <= '1';
	UTMI_termselect  <= '1';
	UTMI_opmode1     <= '0';
	UTMI_txvalid     <= '0';

	-- turn off the LED (active low)
	LED_module <= '1';

	-- currently unused outputs
	A_X      <= (others => '0');        -- AVR microprocessor
	OHO_RCLK <= '0';                    -- 3x7 segment display
	OHO_SCLK <= '0';                    -- 3x7 segment display
	OHO_SER  <= '0';                    -- 3x7 segment display
	V_V      <= (others => '0');        -- another VITEK card
	D_IN     <= (others => '0');
	D_D      <= '0';
	D_Q      <= '0';
	D_MS     <= '0';
	D_LE     <= '0';
	D_CLK    <= '0';

	EO   <= (others => '0');
	O_NIM <= (others => '0');

	-- the following handles the communication
	-- with the CPLD
	C_F_in <= (
			1      => fpga_finished,
			others => '0'
		);

	vme : process is
	begin
		wait until rising_edge(clk);
		-- synchronize inputs
		V_WRITE    <= C_F_out(5);
		fpga_start <= C_F_out(6);
		vme_addr   <= I_A(vme_addr_size + 1 downto 2);

		case vme_state is
			when s_vme_idle =>
				if fpga_start = '1' then
					if V_WRITE = '0' then -- WRITE is active low
						vme_state <= s_vme_write;
					else
						vme_state <= s_vme_read;
					end if;
				end if;
				-- always set some defaults
				F_D           <= (others => 'Z');
				fpga_finished <= '0';
				vme_wr        <= '0';

			when s_vme_write =>
				-- the address is already set above, 
				-- so multiplex the bytes into the 32bit wide memory
				if I_A(1) = '0' then
					-- lower two bytes swapped, keep upper two
					vme_din <= vme_dout(31 downto 16) & F_D(7 downto 0) & F_D(15 downto 8);
				else
					-- higher two bytes swapped, keep lower two
					vme_din <= F_D(7 downto 0) & F_D(15 downto 8) & vme_dout(15 downto 0);
				end if;
				vme_wr    <= '1';
				vme_state <= s_vme_finish;

			when s_vme_read =>
				-- the address is already set above, 
				-- so multiplex the 32bit wide memory to the bytes
				if I_A(1) = '0' then
					-- lower two bytes swapped
					F_D(7 downto 0)  <= vme_dout(15 downto 8);
					F_D(15 downto 8) <= vme_dout(7 downto 0);
				else
					-- higher two bytes swapped
					F_D(7 downto 0)  <= vme_dout(31 downto 24);
					F_D(15 downto 8) <= vme_dout(23 downto 16);
				end if;
				vme_state <= s_vme_finish;

			when s_vme_finish =>
				-- tell CPLD we're ready and 
				-- wait until CPLD signals the end
				fpga_finished <= '1';
				vme_wr        <= '0';
				if fpga_start = '0' then
					vme_state <= s_vme_idle;
				end if;

		end case;
	end process vme;

	-- port b can be used to handle the VME data transparently
	vme_data : component dualportram
		generic map(DATA => 32,         -- 32 bit wide 
			          ADDR => vme_addr_size -- 2^3=8 words
		)
		port map(a_clk  => clk,
			       a_wr   => vme_wr,
			       a_addr => vme_addr,
			       a_din  => vme_din,
			       a_dout => vme_dout,
			       b_clk  => clk,
			       b_wr   => '0',
			       b_addr => b"000",
			       b_din  => x"00000000",
			       b_dout => open);

end arch1;

