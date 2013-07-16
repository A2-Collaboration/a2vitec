library ieee;
use ieee.std_logic_1164.all;

entity SN74LVTH162245DL is
	generic(
		INPUTS : integer
	);
	port(
		OE  : in    std_logic;
		DIR : in    std_logic;
		A   : inout std_logic_vector(INPUTS - 1 downto 0);
		B   : inout std_logic_vector(INPUTS - 1 downto 0)
	);
end entity SN74LVTH162245DL;

architecture RTL of SN74LVTH162245DL is
begin
	process(OE, DIR) is
	begin
		if OE = '1' then
			A <= (others => 'Z');
			B <= (others => 'Z');
		else
			if DIR = '0' then
				A <= B;
				B <= (others => 'Z');
			else
				B <= A;
				A <= (others => 'Z');
			end if;
		end if;
	end process;
end architecture RTL;
