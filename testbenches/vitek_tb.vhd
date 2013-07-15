library IEEE;
use ieee.std_logic_1164.all;

-- this entity "simulates" the VITEK board 
-- (and also the Trenz micromodule)
-- it mainly tests the VME bus access

entity vitek_tb is
end entity vitek_tb;

architecture arch1 of vitek_tb is
	component vitek_cpld_xc9536
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
			   PORT_READ : in  std_logic;
			   PORT_CLK  : in  std_logic;
			   SWITCH1   : in  std_logic_vector(3 downto 0));
	end component vitek_cpld_xc9536;

	component vitek_fpga_xc3s1000
		port(CLK              : in    std_logic;
			   UTMI_databus16_8 : out   std_logic;
			   UTMI_reset       : out   std_logic;
			   UTMI_xcvrselect  : out   std_logic;
			   UTMI_termselect  : out   std_logic;
			   UTMI_opmode1     : out   std_logic;
			   UTMI_txvalid     : out   std_logic;
			   LED_module       : out   std_logic;
			   O_NIM            : out   std_logic_vector(4 downto 1);
			   I_NIM            : in    std_logic_vector(4 downto 0);
			   EO               : out   std_logic_vector(16 downto 1);
			   EI               : in    std_logic_vector(16 downto 1);
			   A_X              : out   std_logic_vector(8 downto 1);
			   OHO_RCLK         : out   std_logic;
			   OHO_SCLK         : out   std_logic;
			   OHO_SER          : out   std_logic;
			   V_V              : out   std_logic_vector(10 downto 1);
			   D_IN             : out   std_logic_vector(5 downto 1);
			   D_OUT            : in    std_logic_vector(5 downto 1);
			   D_D              : out   std_logic;
			   D_Q              : out   std_logic;
			   D_MS             : out   std_logic;
			   D_LE             : out   std_logic;
			   D_CLK            : out   std_logic;
			   F_D              : inout std_logic_vector(31 downto 0);
			   C_F_in           : out   std_logic_vector(3 downto 1);
			   C_F_out          : in    std_logic_vector(7 downto 4);

			   I_A              : in    std_logic_vector(10 downto 1));
	end component vitek_fpga_xc3s1000;

	constant period : time := 1000 / 60 ns; -- 60MHz clock (from UTMI)
	signal clk      : std_logic;

	constant period_vme : time := 1000 / 16 ns; -- 16MHz clock (from VMEbus)
	signal clk_vme      : std_logic;

	-- CPLD signals
	signal A_CLK     : std_logic;
	signal V_DS      : std_logic_vector(1 downto 0);
	signal V_WRITE   : std_logic;
	signal V_LWORD   : std_logic;
	signal V_AS      : std_logic;
	signal DTACK     : std_logic;
	signal I_AM      : std_logic_vector(5 downto 0);
	signal I_A       : std_logic_vector(15 downto 1);
	signal C_F_in    : std_logic_vector(3 downto 1);
	signal C_F_out   : std_logic_vector(7 downto 4);
	signal B_OE      : std_logic;
	signal B_DIR     : std_logic;
	signal PORT_READ : std_logic;
	signal PORT_CLK  : std_logic;
	signal SWITCH1   : std_logic_vector(3 downto 0);

	-- FPGA signals
	signal F_D   : std_logic_vector(31 downto 0);
	signal I_NIM : std_logic_vector(4 downto 0);
	signal EI    : std_logic_vector(16 downto 1);
	signal D_IN  : std_logic_vector(5 downto 1);

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
		clk_vme <= '0';
		wait for period_vme / 2;
		clk_vme <= '1';
		wait for period_vme / 2;
	end process clock_driver_vme;

	-- instantiate CPLD
	CPLD_1 : vitek_cpld_xc9536
		port map(A_CLK     => A_CLK,
			       V_SYSCLK  => clk_vme,
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

	-- instantiate FPGA, neglect the unneeded I/O (delay, NIM, ECL)
	I_NIM <= (others => '0');
	EI    <= (others => '0');
	D_IN  <= (others => '0');
	FPGA_1 : vitek_fpga_xc3s1000
		port map(CLK              => CLK,
			       UTMI_databus16_8 => open,
			       UTMI_reset       => open,
			       UTMI_xcvrselect  => open,
			       UTMI_termselect  => open,
			       UTMI_opmode1     => open,
			       UTMI_txvalid     => open,
			       LED_module       => open,
			       O_NIM            => open,
			       I_NIM            => I_NIM,
			       EO               => open,
			       EI               => EI,
			       A_X              => open,
			       OHO_RCLK         => open,
			       OHO_SCLK         => open,
			       OHO_SER          => open,
			       V_V              => open,
			       D_IN             => D_IN,
			       D_OUT            => open,
			       D_D              => open,
			       D_Q              => open,
			       D_MS             => open,
			       D_LE             => open,
			       D_CLK            => open,
			       F_D              => F_D,
			       C_F_in           => C_F_in,
			       C_F_out          => C_F_out,
			       I_A              => I_A(10 downto 1));

-- now work on the VME bus as a master


end architecture arch1;
