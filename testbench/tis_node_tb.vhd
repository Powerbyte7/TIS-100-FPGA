library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_node_tb is
end entity;

architecture rtl of tis_node_tb is
	component tis_node is
		port (
			clock, resetn           : in  std_logic;
			read, write, chipselect : in  std_logic;
			address                 : in  std_logic_vector(2 downto 0);
			readdata                : out std_logic_vector(31 downto 0);
			writedata               : in  std_logic_vector(31 downto 0);
			byteenable              : in  std_logic_vector(3 downto 0);
			Q_export                : out std_logic_vector(31 downto 0);
			-- Used to avoid early start without initialized program
			tis_active              : in  std_logic;
			-- Left conduit
			i_left                  : in  std_logic_vector(10 downto 0);
			i_left_active           : in  std_logic;
			o_left                  : out std_logic_vector(10 downto 0);
			o_left_active           : out std_logic;
			-- Right conduit
			i_right                 : in  std_logic_vector(10 downto 0);
			i_right_active          : in  std_logic;
			o_right                 : out std_logic_vector(10 downto 0);
			o_right_active          : out std_logic;
			-- Up conduit
			i_up                    : in  std_logic_vector(10 downto 0);
			i_up_active             : in  std_logic;
			o_up                    : out std_logic_vector(10 downto 0);
			o_up_active             : out std_logic;
			-- Down conduit
			i_down                  : in  std_logic_vector(10 downto 0);
			i_down_active           : in  std_logic;
			o_down                  : out std_logic_vector(10 downto 0);
			o_down_active           : out std_logic
		);
	end component;

	procedure ClockPulse(signal clk : inout std_logic) is
	begin
		wait for 1 ns;
		clk <= '0';
		wait for 1 ns;
		clk <= '1';
		wait for 1 ns;
	end procedure;

	-- Avalon slave signals
	signal clock_tb                         : std_logic;
	signal resetn_tb                        : std_logic;
	signal read_tb, write_tb, chipselect_tb : std_logic;
	signal address_tb                       : std_logic_vector(2 downto 0);
	signal readdata_tb                      : std_logic_vector(31 downto 0);
	signal writedata_tb                     : std_logic_vector(31 downto 0);
	signal byteenable_tb                    : std_logic_vector(3 downto 0);
	signal Q_export_tb                      : std_logic_vector(31 downto 0);

	-- TIS signals
	signal tis_active_tb : std_logic;
	-- Left conduit
	signal i_left_tb        : std_logic_vector(10 downto 0) := (others => '0');
	signal i_left_active_tb : std_logic                     := '0';
	signal o_left_tb        : std_logic_vector(10 downto 0);
	signal o_left_active_tb : std_logic;
	-- Right conduit
	signal i_right_tb        : std_logic_vector(10 downto 0) := (others => '0');
	signal i_right_active_tb : std_logic                     := '0';
	signal o_right_tb        : std_logic_vector(10 downto 0);
	signal o_right_active_tb : std_logic;
	-- Up conduit
	signal i_up_tb        : std_logic_vector(10 downto 0) := (others => '0');
	signal i_up_active_tb : std_logic                     := '0';
	signal o_up_tb        : std_logic_vector(10 downto 0);
	signal o_up_active_tb : std_logic;
	-- Down conduit
	signal i_down_tb        : std_logic_vector(10 downto 0) := (others => '0');
	signal i_down_active_tb : std_logic                     := '0';
	signal o_down_tb        : std_logic_vector(10 downto 0);
	signal o_down_active_tb : std_logic;
begin
	-- Port map
	left_node: tis_node
		port map (

			clock          => clock_tb,
			resetn         => resetn_tb,
			read           => read_tb,
			write          => write_tb,
			chipselect     => chipselect_tb,
			address        => address_tb,
			readdata       => readdata_tb,
			writedata      => writedata_tb,
			byteenable     => byteenable_tb,
			Q_export       => Q_export_tb,
			-- TIS signals
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

	process
	begin
		-- Initialize signals
		chipselect_tb <= '1';
		clock_tb <= '0';
		resetn_tb <= '1'; -- High by default
		byteenable_tb <= (others => '1');
		read_tb <= '0';
		write_tb <= '0';
		writedata_tb <= (others => '0');
		tis_active_tb <= '0';
		ClockPulse(clock_tb);

		-- Node Header (15 downto 0)
		-- 0 NOP (31 downto 16), (Prefix number is PC)
		write_tb <= '1';
		address_tb <= std_logic_vector(to_unsigned(0, address_tb'length));
		writedata_tb <= x"0000" & x"0006";
		ClockPulse(clock_tb);

		-- 1 ADD 421 (15 downto 0)
		-- 2 SUB 421 (31 downto 16)
		address_tb <= std_logic_vector(to_unsigned(1, address_tb'length));
		writedata_tb <= x"05A5" & x"01A5";
		ClockPulse(clock_tb);

		-- 3 ADD ANY (15 downto 0)
		-- 4 SUB NIL (31 downto 16)
		address_tb <= std_logic_vector(to_unsigned(2, address_tb'length));
		writedata_tb <= x"0C00" & x"0806";
		ClockPulse(clock_tb);

		-- 5 MOV 744, ACC (15 downto 0)
		-- 6 JEZ 2 (31 downto 16)
		address_tb <= std_logic_vector(to_unsigned(3, address_tb'length));
		writedata_tb <= x"0C00" & x"0806";
		ClockPulse(clock_tb);

		-- Stop writing, start reading
		write_tb <= '0';
		read_tb <= '1';
		address_tb <= std_logic_vector(to_unsigned(0, address_tb'length));
		
		-- Validate memory state
		ClockPulse(clock_tb);
		assert readdata_tb = x"0000" & x"0006" report "(0) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(1, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"05A5" & x"01A5" report "(1) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(2, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"0C00" & x"0806" report "(2) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(3, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"0C00" & x"0806" report "(3) Failed to validate memory" severity error;

		report "Testbench success!!!" severity note;
		std.env.stop;
	end process;
end architecture;
