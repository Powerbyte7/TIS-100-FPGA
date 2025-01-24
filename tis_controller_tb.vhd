library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_controller_tb is
end entity;

architecture rtl of tis_controller_tb is
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

	-- Avalon slave signals
	signal clock_tb          : std_logic                     := '0';
	signal resetn_tb         : std_logic                     := '1';
	signal read_tb, write_tb : std_logic                     := '0';
	signal readdata_tb       : std_logic_vector(15 downto 0);
	signal writedata_tb      : std_logic_vector(15 downto 0) := (others => '0');
	signal tis_enable_tb     : std_logic                     := '1';
	signal tis_step_once_tb  : std_logic                     := '0';
	signal tis_active_tb     : std_logic;

begin
	-- Port map
	left_node: entity work.tis_controller
		port map (

			clock         => clock_tb,
			resetn        => resetn_tb,
			read          => read_tb,
			write         => write_tb,
			readdata      => readdata_tb,
			writedata     => writedata_tb,
			-- TIS signals
			tis_enable    => tis_enable_tb,
			tis_step_once => tis_step_once_tb,
			tis_active    => tis_active_tb
		);

	process
	begin

		-- Test init
		tis_enable_tb <= '1';
		assert not (tis_active_tb = '1') report "Expected tis_active low on init" severity error;
		ClockPulse(clock_tb);
		assert tis_active_tb = '1' report "Expected tis_active high afer first clock cycle" severity error;
		TisPulse(clock_tb);
		TisPulse(clock_tb);
		assert tis_active_tb = '1' report "Expected tis_active high afer two instruction cycles" severity error;

		-- Test disable
		tis_enable_tb <= '0';
		TisPulse(clock_tb);
		assert tis_active_tb = '0' report "Expected tis_active low afer disabling" severity error;

		-- Test stepping
		tis_step_once_tb <= '1';
		ClockPulse(clock_tb);
		assert tis_active_tb = '1' report "Expected tis_active high afer starting step" severity error;
		TisPulse(clock_tb);
		assert tis_active_tb = '0' report "Expected tis_active low afer finishing step" severity error;
		ClockPulse(clock_tb);
		assert tis_active_tb = '0' report "Expected tis_active low afer finishing step" severity error;
		ClockPulse(clock_tb);
		assert tis_active_tb = '0' report "Expected tis_active low afer finishing step" severity error;


		report "Testbench success!!!" severity note;
		std.env.stop;
	end process;
end architecture;
