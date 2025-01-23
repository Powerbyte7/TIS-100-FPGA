-- altera vhdl_input_version vhdl_2008
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity tis_stack_node is
	generic (
		buffer_length : natural := 15
	);
	port (
		clock, resetn  : in  std_logic;
		read, write    : in  std_logic;
		address        : in  std_logic_vector(0 downto 0);
		readdata       : out std_logic_vector(15 downto 0);
		writedata      : in  std_logic_vector(15 downto 0);
		-- Interrupt when data is available for reading
		irq            : out std_logic;
		-- Used to avoid early start without initialized program
		tis_active     : in  std_logic;
		-- Left conduit
		i_left         : in  integer range - 999 to 999;
		i_left_active  : in  std_logic;
		o_left         : out integer range - 999 to 999;
		o_left_active  : out std_logic;
		-- Right conduit
		i_right        : in  integer range - 999 to 999;
		i_right_active : in  std_logic;
		o_right        : out integer range - 999 to 999;
		o_right_active : out std_logic;
		-- Up conduit
		i_up           : in  integer range - 999 to 999;
		i_up_active    : in  std_logic;
		o_up           : out integer range - 999 to 999;
		o_up_active    : out std_logic;
		-- Down conduit
		i_down         : in  integer range - 999 to 999;
		i_down_active  : in  std_logic;
		o_down         : out integer range - 999 to 999;
		o_down_active  : out std_logic
	);
end entity;

architecture rtl of tis_stack_node is
	type stack is array (0 to buffer_length - 1) of integer range - 999 to 999;
	signal values : stack;

	signal node_config : std_logic_vector(15 downto 0);

	type tis_state is (TIS_RUN, TIS_LEFT, TIS_RIGHT, TIS_UP, TIS_DOWN, TIS_FINISH);

	signal node_state  : tis_state := TIS_RUN; -- Write/Read direction of node
	signal node_output : integer range - 999 to 999;

	signal tail_ptr : integer range 0 to buffer_length - 1 := 0; -- Written to (-) and read by (-) memory master
	signal head_ptr : integer range 0 to buffer_length - 1 := 0; -- Written to (+) and read by (+) other nodes
	signal count    : integer range 0 to buffer_length     := 0;

	subtype tis_integer is integer range - 999 to 999;

	pure function to_tis_integer(a : signed) return tis_integer is
	begin
		if to_integer(a) > 999 then
			return 999;
		elsif to_integer(a) < - 999 then
			return - 999;
		else
			return to_integer(a);
		end if;
	end function;
begin
	o_left  <= node_output;
	o_right <= node_output;
	o_up    <= node_output;
	o_down  <= node_output;

	-- Interrupt when data is available for reading
	irq <= '0' when count = 0 else '1';

	process (clock, resetn)
	begin
		if not resetn then
			o_left_active <= '0';
			o_right_active <= '0';
			o_up_active <= '0';
			o_down_active <= '0';
			node_state <= TIS_RUN;
			node_config <= (others => '0');
			count <= 0;
			tail_ptr <= 0;
			head_ptr <= 0;
			readdata <= (others => '1');
			for i in 0 to buffer_length - 1 loop
				values(i) <= 0;
			end loop;
		elsif rising_edge(clock) then
			if read then
				if address = "1" then
					if count = 0 then
						readdata <= (others => '1');
					else
						readdata <= std_logic_vector(to_signed(values(tail_ptr), readdata'length));
						tail_ptr <= (tail_ptr + 1) mod buffer_length;
						count <= count - 1;
					end if;
				else
					readdata <= node_config;
				end if;
			elsif write then
				if address = "1" then
					if count < buffer_length then
						values(tail_ptr) <= to_tis_integer(signed(writedata));
						tail_ptr <= (tail_ptr - 1 + buffer_length) mod buffer_length;
						count <= count + 1;
					end if;
				else
					node_config <= writedata;
				end if;
			end if;

			if tis_active then
				-- Update state
				with node_state select node_state <=
					TIS_RUN    when TIS_FINISH,
					TIS_LEFT   when TIS_RUN,
					TIS_RIGHT  when TIS_LEFT,
					TIS_DOWN   when TIS_RIGHT,
					TIS_UP     when TIS_DOWN,
					TIS_FINISH when TIS_UP;

				-- Default I/O state
				o_left_active <= '0';
				o_right_active <= '0';
				o_up_active <= '0';
				o_down_active <= '0';
				node_output <= values(head_ptr);

				-- Stack I/O inactive when memory map I/O is ongoing
				if read = '0' and write = '0' then
					case node_state is
						when TIS_RUN =>
						-- Do nothing
						when TIS_LEFT =>
							-- Read if buffer can take another value
							if node_config(1) = '1' and count < buffer_length then
								o_left_active <= '1';
							end if;
							-- Write if a value is still left in buffer
							if node_config(0) = '1' and count > 0 then
								o_right_active <= '1';
							end if;
						when TIS_RIGHT =>
							-- Check previous I/O result
							if o_left_active = '1' and i_left_active = '1' and o_right_active = '1' and i_right_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								assert not (count = 0 or count = buffer_length) report "The assumption was wrong!" severity failure;
								-- Store value
								values(head_ptr) <= i_left;
								-- Read/Write
								o_left_active <= '1';
								o_right_active <= '1';

							elsif o_left_active = '1' and i_left_active = '1' then
								-- Read value from LEFT
								values((head_ptr + 1) mod buffer_length) <= i_left;
								head_ptr <= (head_ptr + 1) mod buffer_length;
								count <= count + 1;
								-- Read if buffer can take another value
								if not (count = buffer_length - 1) then
									-- Read from RIGHT
									o_right_active <= '1';
								end if;
								-- Write to LEFT
								o_left_active <= '1';

							elsif o_right_active = '1' and i_right_active = '1' then
								-- Written value to RIGHT
								head_ptr <= (head_ptr - 1 + buffer_length) mod buffer_length;
								count <= count - 1;
								-- Check if any values are left in buffer
								if not (count = 0) then
									-- Write to LEFT
									o_left_active <= '1';
								end if;
								-- Read from RIGHT
								o_right_active <= '1';

							else -- No previous I/O

								-- Write if a value is still left in buffer
								if not (count = 0) then
									-- Write to LEFT
									o_left_active <= '1';
								end if;

								-- Read if buffer can take another value
								if not (count = buffer_length) then
									-- Read from RIGHT
									o_right_active <= '1';
								end if;
							end if;
						when TIS_DOWN =>
							-- Check previous I/O result
							if o_right_active = '1' and i_right_active = '1' and o_down_active = '1' and i_down_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								assert not (count = 0 or count = buffer_length) report "The assumption was wrong!" severity failure;
								-- Store value
								values(head_ptr) <= i_right;
								-- Read/Write
								o_right_active <= '1';
								o_down_active <= '1';

							elsif o_right_active = '1' and i_right_active = '1' then
								-- Read value from RIGHT
								values((head_ptr + 1) mod buffer_length) <= i_right;
								head_ptr <= (head_ptr + 1) mod buffer_length;
								count <= count + 1;
								-- Read if buffer can take another value
								if not (count = buffer_length - 1) then
									-- Read from DOWN
									o_down_active <= '1';
								end if;
								-- Write to RIGHT
								o_right_active <= '1';

							elsif o_down_active = '1' and i_down_active = '1' then
								-- Written value to DOWN
								head_ptr <= (head_ptr - 1 + buffer_length) mod buffer_length;
								count <= count - 1;
								-- Check if any values are left in buffer
								if not (count = 0) then
									-- Write to RIGHT
									o_right_active <= '1';
								end if;
								-- Read from DOWN
								o_down_active <= '1';

							else -- No previous I/O

								-- Write if a value is still left in buffer
								if not (count = 0) then
									-- Write to RIGHT
									o_right_active <= '1';
								end if;

								-- Read if buffer can take another value
								if not (count = buffer_length) then
									-- Read from DOWN
									o_down_active <= '1';
								end if;
							end if;

						when TIS_UP =>
							-- Check previous I/O result
							if o_down_active = '1' and i_down_active = '1' and o_up_active = '1' and i_up_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								assert not (count = 0 or count = buffer_length) report "The assumption was wrong!" severity failure;
								-- Store value
								values(head_ptr) <= i_down;
								-- Read/Write
								o_down_active <= '1';
								o_up_active <= '1';

							elsif o_down_active = '1' and i_down_active = '1' then
								-- Read value from DOWN
								values((head_ptr + 1) mod buffer_length) <= i_down;
								head_ptr <= (head_ptr + 1) mod buffer_length;
								count <= count + 1;
								-- Read if buffer can take another value
								if not (count = buffer_length - 1) then
									-- Read from UP
									o_up_active <= '1';
								end if;
								-- Write to DOWN
								o_down_active <= '1';

							elsif o_up_active = '1' and i_up_active = '1' then
								-- Written value to UP
								head_ptr <= (head_ptr - 1 + buffer_length) mod buffer_length;
								count <= count - 1;
								-- Check if any values are left in buffer
								if not (count = 0) then
									-- Write to DOWN
									o_down_active <= '1';
								end if;
								-- Read from UP
								o_up_active <= '1';

							else -- No previous I/O

								-- Write if a value is still left in buffer
								if not (count = 0) then
									-- Write to DOWN
									o_down_active <= '1';
								end if;

								-- Read if buffer can take another value
								if not (count = buffer_length) then
									-- Read from UP
									o_up_active <= '1';
								end if;
							end if;

						when TIS_FINISH =>
							-- Check previous I/O result
							if o_down_active = '1' and i_down_active = '1' and o_up_active = '1' and i_up_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								values(head_ptr) <= i_down;
							elsif o_down_active = '1' and i_down_active = '1' then
								-- Read value from DOWN
								values((head_ptr + 1) mod buffer_length) <= i_down;
								head_ptr <= (head_ptr + 1) mod buffer_length;
								count <= count + 1;
							elsif o_up_active = '1' and i_up_active = '1' then
								-- Written value to UP
								head_ptr <= (head_ptr - 1 + buffer_length) mod buffer_length;
								count <= count - 1;
							else
								-- Do nothing
							end if;

						-- Read last operation
					end case;
				end if;
			end if;
		end if;
	end process;
end architecture;
