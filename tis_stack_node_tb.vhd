library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_stack_node_tb is
end entity;

architecture rtl of tis_stack_node_tb is
	signal clock_tb     : std_logic := 0;
	signal resetn_tb    : std_logic := 1;
	signal read_tb      : std_logic := 0;
	signal write_tb     : std_logic := 0;
	signal address_tb   : std_logic_vector(0 downto 0);
	signal readdata_tb  : std_logic_vector(15 downto 0);
	signal writedata_tb : std_logic_vector(15 downto 0);
	-- Interrupt when data is available for reading
	signal irq_tb : std_logic;
	-- Used to avoid early start without initialized program
	signal tis_active_tb : std_logic := 0;
	-- Left conduit
	signal i_left_tb        : integer range - 999 to 999 := 0;
	signal i_left_active_tb : std_logic := 0;
	signal o_left_tb        : integer range - 999 to 999;
	signal o_left_active_tb : std_logic;
	-- Right conduit
	signal i_right_tb        : integer range - 999 to 999 := 0;
	signal i_right_active_tb : std_logic := 0;
	signal o_right_tb        : integer range - 999 to 999;
	signal o_right_active_tb : std_logic;
	-- Up conduit
	signal i_up_tb        : integer range - 999 to 999 := 0;
	signal i_up_active_tb : std_logic := 0;
	signal o_up_tb        : integer range - 999 to 999;
	signal o_up_active_tb : std_logic;
	-- Down conduit
	signal i_down_tb        : integer range - 999 to 999 := 0;
	signal i_down_active_tb : std_logic := 0;
	signal o_down_tb        : integer range - 999 to 999;
	signal o_down_active_tb : std_logic;

    -- Signle rising edge
	procedure ClockPulse(signal clk : inout std_logic) is
	begin
		wait for 1 ns;
		clk <= '0';
		wait for 1 ns;
		clk <= '1';
		wait for 1 ns;
	end procedure;

	-- Full TIS I/O Cycle
	procedure TisPulse(signal clk : inout std_logic) is
	begin
		-- Each cycle needs 6 rising edges
		for i in 1 to 6 loop
			wait for 1 ns;
			clk <= '0';
			wait for 1 ns;
			clk <= '1';
		end loop;

		wait for 1 ns;
	end procedure;
begin

	stack1: entity work.tis_stack_node
		generic map (
			buffer_length => 15
		)
		port map (
			clock          => clock_tb,
			resetn         => resetn_tb,
			read           => read_tb,
			write          => write_tb,
			address        => address_tb,
			readdata       => readdata_tb,
			writedata      => writedata_tb,
			irq            => irq_tb,
			tis_active     => tis_active_tb,
			i_left         => i_left_tb,
			i_left_active  => i_left_active_tb,
			o_left         => o_left_tb,
			o_left_active  => o_left_active_tb,
			i_right        => i_right_tb,
			i_right_active => i_right_active_tb,
			o_right        => o_right_tb,
			o_right_active => o_right_active_tb,
			i_up           => i_up_tb,
			i_up_active    => i_up_active_tb,
			o_up           => o_up_tb,
			o_up_active    => o_up_active_tb,
			i_down         => i_down_tb,
			i_down_active  => i_down_active_tb,
			o_down         => o_down_tb,
			o_down_active  => o_down_active_tb
		);


    
end architecture;
