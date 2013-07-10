library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

 entity bottom is
    Port ( 
	 	-- the following output assignments are required so that
		-- the GT3200 USB phy generates a 30 MHz clock
		utmi_databus16_8  : out bit;
		utmi_reset			: out bit;
		utmi_xcvrselect	: out bit;
		utmi_termselect	: out bit;
		utmi_opmode1		: out bit;
		utmi_txvalid		: out bit;
		
		-- this is the 30 MHz clock input (clkout is the utmi name)
		utmi_clkout			: in std_logic;

		
		-- b2b connectors
		i						: in  bit_vector (0 to 58);
		o						: out bit_vector (0 to 58);
		 

		-- led	on micromodule
	 	mm_led : out std_logic	 


		);
	end bottom;

architecture Behavioral of bottom is
signal counter : integer range 0 to 16777215;

begin

o <= i;

--configure utmi for 30MHz clock
utmi_databus16_8 	<= '1';
utmi_reset			<= '0';
utmi_xcvrselect	<= '1';
utmi_termselect	<= '1';
utmi_opmode1		<= '0';
utmi_txvalid		<= '0';

mm_led <= '1' when (counter < 8388608) and (i(9)= '1') else '0'; 

process (utmi_clkout)
begin
	if rising_edge(utmi_clkout) then
		counter <= counter + 1;
	end if;
end process;
	


end Behavioral;
