library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

	-- Used to toggle tis_active every 6 clock cycles

entity tis_controller is
	port (
		clock, resetn : in  std_logic;
		read, write   : in  std_logic;
		readdata      : out std_logic_vector(15 downto 0);
		writedata     : in  std_logic_vector(15 downto 0);

		tis_enable    : in  std_logic; -- Signal to enable TIS
		tis_step_once : in  std_logic; -- Signal to step once despite disable
		tis_active    : out std_logic  -- Whether TIS is currently enabled
	);
end entity;

architecture rtl of tis_controller is
	type tis_state is (TIS_RUN, TIS_LEFT, TIS_RIGHT, TIS_UP, TIS_DOWN, TIS_FINISH);

	signal node_state : tis_state := TIS_RUN; -- Write/Read direction of nodes

	signal tis_step_done : std_logic := '0'; -- Used to step once
	signal active        : std_logic := '0'; -- Used to step once
begin

	readdata <= (others => '0');

	tis_active <= active;

	process (clock, resetn) is
	begin
		if resetn = '0' then
			node_state <= TIS_RUN;
			tis_step_done <= '0';
			active <= '0';
		elsif rising_edge(clock) then
			case node_state is
				when TIS_RUN =>
					node_state <= TIS_RUN;

					if tis_enable = '0' and active = '0' and tis_step_once = '1' and tis_step_done = '0' then
						-- Don't go to next state yet, need extra clock cycle to keep synced state
						node_state <= TIS_RUN;
						active <= '1';
					elsif tis_enable = '0' and active = '1' and tis_step_once = '1' and tis_step_done = '0' then
						node_state <= TIS_LEFT;
						tis_step_done <= '1';
					elsif tis_enable = '1' and active = '0' then
						-- Don't go to next state yet, need extra clock cycle to keep synced state
						node_state <= TIS_RUN;
						active <= '1';
					elsif tis_enable = '1' and active = '1' then
						node_state <= TIS_LEFT;
					elsif tis_enable = '0' then
						-- Cycle already started, complete it
						node_state <= TIS_LEFT;
					end if;

					-- Don't allow stepping while enabled
					if tis_enable = '1' then
						tis_step_done <= '1';
					end if;

				when TIS_LEFT =>
					node_state <= TIS_RIGHT;
				when TIS_RIGHT =>
					node_state <= TIS_UP;
				when TIS_UP =>
					node_state <= TIS_DOWN;
				when TIS_DOWN =>
					node_state <= TIS_FINISH;
				when TIS_FINISH =>

					-- Disable when enable flag drops
					if tis_enable = '0' then
						active <= '0';
						if tis_step_once = '0' then
							tis_step_done <= '0';
						end if;
					end if;

					node_state <= TIS_RUN;
			end case;
		end if;
	end process;
end architecture;
