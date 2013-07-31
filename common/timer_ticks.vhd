library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- this entity pulls tick high for one clk cycle every "ticks" cycles
-- example: ticks = 2                  => tick is high every other cycle
--          ticks = 100, clk is 100MHz => tick is high every microsecond (1MHz frequency) 
--                                        for 10ns (synced to clk!) 

entity timer_ticks is
	generic(
		ticks : integer
	);
	port(
		clk  : in  std_logic;
		tick : out std_logic
	);
end entity timer_ticks;

architecture RTL of timer_ticks is
	signal counter : integer range 0 to ticks - 1;
begin
	process
	begin
		wait until rising_edge(CLK);
		if counter = 0 then
			tick    <= '1';
			counter <= ticks - 1;
		else
			tick    <= '0';
			counter <= counter - 1;
		end if;
	end process;
end architecture RTL;
