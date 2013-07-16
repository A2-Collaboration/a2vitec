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
  -- add A,B to sensitivity list, 
  -- otherwise simulation fails
	process(OE, DIR, A, B) is
	begin
		if OE = '1' then
			A <= (others => 'Z');
			B <= (others => 'Z');
		elsif OE = '0' then
			if DIR = '0' then
				A <= B;
				B <= (others => 'Z');
			elsif DIR = '1' then
				B <= A;
				A <= (others => 'Z');
			end if;
		end if;
	end process;
end architecture RTL;
