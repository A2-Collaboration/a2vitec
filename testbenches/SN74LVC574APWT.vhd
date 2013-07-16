library ieee;
use ieee.std_logic_1164.all;

entity SN74LVC574APWT is
	generic(
		INPUTS : integer
	);
	port(
		clk : in  std_logic;
		D   : in  std_logic_vector(INPUTS - 1 downto 0);
		Q   : out std_logic_vector(INPUTS - 1 downto 0) := (others => '0')
	);
end entity SN74LVC574APWT;

architecture RTL of SN74LVC574APWT is
begin
	process is
	begin
		wait until rising_edge(clk);
		Q <= D after 10 ns;
	end process;
end architecture RTL;
