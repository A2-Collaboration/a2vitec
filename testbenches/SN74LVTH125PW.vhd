library ieee;
use ieee.std_logic_1164.all;

entity SN74LVTH125PW is
	generic(
		INPUTS : integer
	);
	port(
		OE  : in    std_logic;
		I   : in  std_logic_vector(INPUTS - 1 downto 0);
		O   : out std_logic_vector(INPUTS - 1 downto 0)
	);
end entity SN74LVTH125PW;

architecture RTL of SN74LVTH125PW is
begin
	process(OE, I) is
	begin
		if OE = '1' then
			O <= (others => 'Z');
		elsif OE = '0' then
			O <= I;
		end if;
	end process;
end architecture RTL;
