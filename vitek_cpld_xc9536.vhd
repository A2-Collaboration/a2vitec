library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vitek_cpld_xc9536 is
	port(
		-- the port names here follow the VITEK board 
		-- schematic from Klaus Weindel
		A_CLK     : out   std_logic;
		V_SYSCLK  : in    std_logic;    -- 16MHz VME bus clock
		V_DS      : in    std_logic_vector(1 downto 0);
		V_WRITE   : in    std_logic;
		V_LWORD   : in    std_logic;
		V_AS      : in    std_logic;
		DTACK     : in    std_logic;    -- including green LED --> inverted V_DTACK?
		I_AM      : in    std_logic_vector(5 downto 0);
		I_A       : in    std_logic_vector(15 downto 11);
		C_F       : inout std_logic_vector(7 downto 1); -- to/from FPGA
		B_OE      : in    std_logic;
		B_DIR     : in    std_logic;
		PORT_READ : in    std_logic;
		PORT_CLK  : in    std_logic;
		-- input for the address 0-f (binary coded)?
		SWITCH1   : in    std_logic_vector(3 downto 0)
	);
end vitek_cpld_xc9536;

architecture arch1 of vitek_cpld_xc9536 is
begin
end arch1;

