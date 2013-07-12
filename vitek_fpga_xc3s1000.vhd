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
		A_X              : inout std_logic_vector(8 downto 1); -- AVR microprocessor
		OHO_RCLK         : out   std_logic; -- 3x7 segment display
		OHO_SCLK         : out   std_logic; -- 3x7 segment display
		OHO_SER          : out   std_logic; -- 3x7 segment display
		V_V              : inout std_logic_vector(10 downto 1); -- another VITEK card

		-- delay stuff
		D_IN             : out   std_logic_vector(5 downto 1); -- to delay input
		D_OUT            : in    std_logic_vector(5 downto 1); -- from delay ouput
		D_D              : out   std_logic;
		D_Q              : out   std_logic;
		D_MS             : out   std_logic;
		D_LE             : out   std_logic;
		D_CLK            : out   std_logic;

		-- VME / CPLD communication
		F_D              : inout std_logic_vector(31 downto 0); -- VME Data
		C_F              : inout std_logic_vector(7 downto 1); -- to CPLD
		I_A              : in    std_logic_vector(10 downto 1) -- VME address		
	);
end vitek_fpga_xc3s1000;

architecture arch1 of vitek_fpga_xc3s1000 is
begin

	-- Configure USB chip on micromodule (UTMI USB3250), 
	-- currently only used as convenient clock source
	UTMI_databus16_8 <= '0';            -- change to 1 to get 30MHz CLK instead of 60MHz
	UTMI_reset       <= '0';
	UTMI_xcvrselect  <= '1';
	UTMI_termselect  <= '1';
	UTMI_opmode1     <= '0';
	UTMI_txvalid     <= '0';

	-- turn off the LED
	LED_module <= '1';
end arch1;

