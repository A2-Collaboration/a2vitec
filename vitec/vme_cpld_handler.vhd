library ieee;
use ieee.std_logic_1164.all;

entity vme_cpld_handler is
	generic(
		vme_addr_size : integer
	);
	port(
		clk     : in    std_logic;
		-- VME / CPLD communication
		F_D     : inout std_logic_vector(15 downto 0); -- VME Data (must be tri-state!)
		C_F_in  : out   std_logic_vector(3 downto 1); -- to CPLD (= "in" port there)
		C_F_out : in    std_logic_vector(7 downto 4); -- from CPLD (= "out" port there)
		I_A     : in    std_logic_vector(10 downto 1); -- VME address		
		-- interface to dualportram
		b_clk   : in    std_logic;
		b_wr    : in    std_logic;
		b_addr  : in    std_logic_vector(vme_addr_size - 1 downto 0);
		b_din   : in    std_logic_vector(15 downto 0);
		b_dout  : out   std_logic_vector(15 downto 0)
	);
end entity vme_cpld_handler;

architecture RTL of vme_cpld_handler is
	component dualportram
		generic(DATA : integer;
			      ADDR : integer);
		port(a_clk  : in  std_logic;
			   a_wr   : in  std_logic;
			   a_addr : in  std_logic_vector(ADDR - 1 downto 0);
			   a_din  : in  std_logic_vector(DATA - 1 downto 0);
			   a_dout : out std_logic_vector(DATA - 1 downto 0);
			   b_clk  : in  std_logic;
			   b_wr   : in  std_logic;
			   b_addr : in  std_logic_vector(ADDR - 1 downto 0);
			   b_din  : in  std_logic_vector(DATA - 1 downto 0);
			   b_dout : out std_logic_vector(DATA - 1 downto 0));
	end component dualportram;

	-- VME stuff: Write to/Read from dualportram (=memory), 
	-- handle CPLD (which does the VME communication)
	type vme_state_type is (s_vme_idle, s_vme_write, s_vme_read, s_vme_finish);
	signal vme_state                 : vme_state_type                           := s_vme_idle;
	signal vme_wr                    : std_logic;
	signal vme_addr                  : std_logic_vector(vme_addr_size downto 1) := (others => '0');
	signal vme_din, vme_dout         : std_logic_vector(15 downto 0);
	signal fpga_start, fpga_finished : std_logic;
	signal V_WRITE                   : std_logic;
begin
	-- the following handles the communication
	-- with the CPLD
	C_F_in <= (
			1      => fpga_finished,
			others => '0'
		);

	vme : process is
	begin
		wait until rising_edge(clk);
		-- synchronize inputs
		V_WRITE    <= C_F_out(4);
		fpga_start <= C_F_out(5);
		vme_addr   <= I_A(vme_addr_size downto 1);

		case vme_state is
			when s_vme_idle =>
				if fpga_start = '1' then
					if V_WRITE = '0' then -- WRITE is active low
						vme_state <= s_vme_write;
					else
						vme_state <= s_vme_read;
					end if;
				end if;
				-- always set some defaults
				F_D           <= (others => 'Z');
				fpga_finished <= '0';
				vme_wr        <= '0';

			when s_vme_write =>
				-- the address is already set above, 
				-- so read the VMEbus data into the memory
				vme_din   <= F_D;
				vme_wr    <= '1';
				vme_state <= s_vme_finish;

			when s_vme_read =>
				-- the address is already set above, 
				-- so output the memory data to the VMEbus
				F_D       <= vme_dout;
				vme_state <= s_vme_finish;

			when s_vme_finish =>
				-- tell CPLD we're ready and 
				-- wait until CPLD signals the end
				fpga_finished <= '1';
				vme_wr        <= '0';
				if fpga_start = '0' then
					vme_state <= s_vme_idle;
				end if;

		end case;
	end process vme;

	vme_data : component dualportram
		generic map(DATA => 16,         -- 16 bit wide 
			          ADDR => vme_addr_size -- 
		)
		port map(a_clk  => clk,
			       a_wr   => vme_wr,
			       a_addr => vme_addr,
			       a_din  => vme_din,
			       a_dout => vme_dout,
			       b_clk  => b_clk,
			       b_wr   => b_wr,
			       b_addr => b_addr,
			       b_din  => b_din,
			       b_dout => b_dout);

end architecture RTL;
