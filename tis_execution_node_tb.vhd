library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_execution_node_tb is
end entity;

architecture rtl of tis_execution_node_tb is
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
	signal i_left_tb        : integer range -999 to 999 := 0;
	signal i_left_active_tb : std_logic                     := '0';
	signal o_left_tb        : integer range -999 to 999;
	signal o_left_active_tb : std_logic;
	-- Right conduit
	signal i_right_tb        : integer range -999 to 999 := 0;
	signal i_right_active_tb : std_logic                     := '0';
	signal o_right_tb        : integer range -999 to 999;
	signal o_right_active_tb : std_logic;
	-- Up conduit
	signal i_up_tb        : integer range -999 to 999 := 0;
	signal i_up_active_tb : std_logic                     := '0';
	signal o_up_tb        : integer range -999 to 999;
	signal o_up_active_tb : std_logic;
	-- Down conduit
	signal i_down_tb        : integer range -999 to 999 := 0;
	signal i_down_active_tb : std_logic                     := '0';
	signal o_down_tb        : integer range -999 to 999;
	signal o_down_active_tb : std_logic;
	signal acc_tb           : integer range - 999 to 999;
	signal bak_tb           : integer range - 999 to 999;
	signal pc_tb            : unsigned(3 downto 0);
begin
	-- Port map
	left_node: entity work.tis_execution_node
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
			o_down_active  => o_down_active_tb,
			debug_acc      => acc_tb,
			debug_bak      => bak_tb,
			debug_pc       => pc_tb
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
		writedata_tb <= x"0000" & x"0008";
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
		-- 6 JEZ 8 (31 downto 16)
		address_tb <= std_logic_vector(to_unsigned(3, address_tb'length));
		writedata_tb <= x"7188" & x"8AE8";
		ClockPulse(clock_tb);

		-- 7 MOV 123, ACC (15 downto 0)
		-- 8 MOV 456, ACC (31 downto 16)
		address_tb <= std_logic_vector(to_unsigned(4, address_tb'length));
		writedata_tb <= x"89C8" & x"887B";
		ClockPulse(clock_tb);

		-- Stop writing, start reading
		write_tb <= '0';
		read_tb <= '1';
		address_tb <= std_logic_vector(to_unsigned(0, address_tb'length));

		-- Validate memory state
		ClockPulse(clock_tb);
		assert readdata_tb = x"0000" & x"0008" report "(0) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(1, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"05A5" & x"01A5" report "(1) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(2, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"0C00" & x"0806" report "(2) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(3, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"7188" & x"8AE8" report "(3) Failed to validate memory" severity error;
		address_tb <= std_logic_vector(to_unsigned(4, address_tb'length));

		ClockPulse(clock_tb);
		assert readdata_tb = x"89C8" & x"887B" report "(4) Failed to validate memory" severity error;
		wait for 1 ns;

		tis_active_tb <= '1';
		assert pc_tb = "0000" report "INIT: Expecting PC = 0, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- NOP
		assert acc_tb = 0 report "INIT: Expecting ACC = 0, got " & to_string(acc_tb);
		assert bak_tb = 0 report "INIT: Expecting BAK = 0, got " & to_string(bak_tb);

		assert pc_tb = "0001" report "NOP: Expecting PC = 1, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- ADD 421
		assert acc_tb = 421 report "ADD 421: Expecting ACC = 421, got " & to_string(acc_tb);
		assert bak_tb = 0 report "ADD 421: Expecting BAK = 0, got " & to_string(bak_tb);

		assert pc_tb = "0010" report "ADD 421: Expecting PC = 2, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- SUB 421
		assert acc_tb = 0 report "SUB 421: Expecting ACC = 0, got " & to_string(acc_tb);
		assert bak_tb = 0 report "SUB 421: Expecting BAK = 0, got " & to_string(bak_tb);

		-- Simulate lack of input
		TisPulse(clock_tb); -- ADD ANY
		TisPulse(clock_tb); -- ADD ANY
		TisPulse(clock_tb); -- ADD ANY

		-- Set input on left
		i_left_active_tb <= '1';
		i_left_tb <= 619;
		assert pc_tb = "0011" report "SUB 421: Expecting PC = 3, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- ADD ANY
		assert acc_tb = 619 report "ADD ANY: Expecting ACC = 619, got " & to_string(acc_tb);
		assert bak_tb = 0 report "ADD ANY: Expecting BAK = 0, got " & to_string(bak_tb);

		assert pc_tb = "0100" report "SUB NIL: Expecting PC = 4, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- SUB NIL
		assert acc_tb = 619 report "SUB NIL: Expecting ACC = 619, got " & to_string(acc_tb);
		assert bak_tb = 0 report "SUB NIL: Expecting BAK = 0, got " & to_string(bak_tb);

		assert pc_tb = "0101" report "MOV 744, ACC: Expecting PC = 5, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- MOV 744, ACC
		assert acc_tb = 744 report "MOV 744, ACC: Expecting ACC = 744, got " & to_string(acc_tb);
		assert bak_tb = 0 report "MOV 744, ACC: Expecting BAK = 0, got " & to_string(bak_tb);

		assert pc_tb = "0110" report "JNZ 8: Expecting PC = 6, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- JNZ 8
		assert acc_tb = 744 report "JNZ 8: Expecting ACC = 744, got " & to_string(acc_tb);
		assert bak_tb = 0 report "JNZ 8: Expecting BAK = 0, got " & to_string(bak_tb);

		-- JNZ 8 should have jumped over insturction 7 here
		assert pc_tb = "1000" report "MOV 456, ACC: Expecting PC = 8, got " & to_string(to_integer(pc_tb));
		TisPulse(clock_tb); -- MOV 456, ACC
		assert acc_tb = 456 report "MOV 456, ACC: Expecting ACC = 456, got " & to_string(acc_tb);
		assert bak_tb = 0 report "MOV 456, ACC: Expecting BAK = 0, got " & to_string(bak_tb);

		TisPulse(clock_tb); -- MOV 456, ACC
		assert acc_tb = 456 report "Expecting ACC = 456, got " & to_string(acc_tb);

		report "Testbench success!!!" severity note;
		std.env.stop;
	end process;
end architecture;
