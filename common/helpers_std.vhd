-- this package should contain useful functions 
-- for "any" kind of entity

library ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

package helpers_std is

	--function declarations
	function and_all(arg : std_logic_vector) return std_logic;
	function or_all(arg : std_logic_vector) return std_logic;
	function all_zero(arg : std_logic_vector) return std_logic;
	function xor_all(arg : std_logic_vector) return std_logic;

	function get_bit_position(arg : std_logic_vector) return integer;

	function is_time_reached(timer : integer; time : integer; period : integer) return std_logic;

	function MAX(x : integer; y : integer) return integer;

	function Log2(input : integer) return integer;
	function count_ones(input : std_logic_vector) return integer;

end package helpers_std;

package body helpers_std is
	function and_all(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '1';
	begin
		tmp := '1';
		for i in arg'range loop
			tmp := tmp and arg(i);
		end loop;                       -- i
		return tmp;
	end function and_all;

	function or_all(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '1';
	begin
		tmp := '0';
		for i in arg'range loop
			tmp := tmp or arg(i);
		end loop;                       -- i
		return tmp;
	end function or_all;

	function all_zero(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '1';
	begin
		for i in arg'range loop
			tmp := not arg(i);
			exit when tmp = '0';
		end loop;                       -- i
		return tmp;
	end function all_zero;

	function xor_all(arg : std_logic_vector) return std_logic is
		variable tmp : std_logic := '0';
	begin
		tmp := '0';
		for i in arg'range loop
			tmp := tmp xor arg(i);
		end loop;                       -- i
		return tmp;
	end function xor_all;

	function get_bit_position(arg : std_logic_vector) return integer is
		variable tmp : integer := 0;
	begin
		tmp := 0;
		for i in arg'range loop
			if arg(i) = '1' then
				return i;
			end if;
		--exit when arg(i) = '1';
		end loop;                       -- i
		return 0;
	end get_bit_position;

	function is_time_reached(timer : integer; time : integer; period : integer) return std_logic is
		variable i : integer range 0 to 1  := 0;
		variable t : unsigned(27 downto 0) := to_unsigned(timer, 28);
	begin
		i := 0;
		if period = 10 then
			case time is
				when 1300000000 => if t(27) = '1' then
						i := 1;
					end if;
				when 640000 => if t(16) = '1' then
						i := 1;
					end if;
				when 80000 => if t(13) = '1' then
						i := 1;
					end if;
				when 10000 => if t(10) = '1' then
						i := 1;
					end if;
				when 1200 => if t(7) = '1' then
						i := 1;
					end if;
				when others => if timer >= time / period then
						i := 1;
					end if;
			end case;
		elsif period = 40 then
			case time is
				when 1300000000 => if t(25) = '1' then
						i := 1;
					end if;
				when 640000 => if t(14) = '1' then
						i := 1;
					end if;
				when 80000 => if t(11) = '1' then
						i := 1;
					end if;
				when 10000 => if t(8) = '1' then
						i := 1;
					end if;
				when 1200 => if t(5) = '1' then
						i := 1;
					end if;
				when others => if timer >= time / period then
						i := 1;
					end if;
			end case;
		else
			if timer = time / period then
				i := 1;
			end if;
		end if;
		if i = 1 then
			return '1';
		else
			return '0';
		end if;
	end is_time_reached;

	function MAX(x : integer; y : integer) return integer is
	begin
		if x > y then
			return x;
		else
			return y;
		end if;
	end MAX;

	function Log2(input : integer) return integer is
		variable temp, log : integer;
	begin
		temp := input;
		log  := 0;
		while (temp /= 0) loop
			temp := temp / 2;
			log  := log + 1;
		end loop;
		return log;
	end function log2;

	function count_ones(input : std_logic_vector) return integer is
		variable temp : unsigned(input'range);
	begin
		temp := (others => '0');
		for i in input'range loop
			temp := temp + unsigned(input(i));
		end loop;
		return to_integer(temp);
	end function count_ones;

end package body helpers_std;

