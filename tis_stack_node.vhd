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
		i_left         : in  std_logic_vector(10 downto 0);
		i_left_active  : in  std_logic := '0';
		o_left         : out std_logic_vector(10 downto 0);
		o_left_active  : out std_logic;
		-- Right conduit
		i_right        : in  std_logic_vector(10 downto 0);
		i_right_active : in  std_logic := '0';
		o_right        : out std_logic_vector(10 downto 0);
		o_right_active : out std_logic;
		-- Up conduit
		i_up           : in  std_logic_vector(10 downto 0);
		i_up_active    : in  std_logic := '0';
		o_up           : out std_logic_vector(10 downto 0);
		o_up_active    : out std_logic;
		-- Down conduit
		i_down         : in  std_logic_vector(10 downto 0);
		i_down_active  : in  std_logic := '0';
		o_down         : out std_logic_vector(10 downto 0);
		o_down_active  : out std_logic
	);
end entity;

architecture rtl of tis_stack_node is
	type stack is array (0 to buffer_length - 1) of integer range - 999 to 999;
	signal values : stack;

	signal node_config : std_logic_vector(15 downto 0);

	type tis_state is (TIS_RUN, TIS_LEFT, TIS_RIGHT, TIS_UP, TIS_DOWN, TIS_FINISH);

	signal node_state  : tis_state := TIS_RUN; -- Write/Read direction of node
	signal node_output : std_logic_vector(10 downto 0);

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

	pure function IncrementPTR(
			signal ptr : in integer range 0 to buffer_length - 1
		) return integer is
	begin
		if ptr = (buffer_length - 1) then
			return 0;
		else
			return ptr + 1;
		end if;
	end function;

	pure function DecrementPTR(
			signal ptr : in integer range 0 to buffer_length - 1
		) return integer is
	begin
		if ptr = 0 then
			return buffer_length - 1;
		else
			return ptr - 1;
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
						readdata <= std_logic_vector(to_signed(values(IncrementPTR(tail_ptr)), readdata'length));
						tail_ptr <= IncrementPTR(tail_ptr);
						count <= count - 1;
					end if;
				else
					readdata <= node_config;
				end if;
			elsif write then
				if address = "1" then
					if count < buffer_length then
						values(tail_ptr) <= to_tis_integer(signed(writedata));
						tail_ptr <= DecrementPTR(tail_ptr);
						count <= count + 1;
					end if;
				else
					node_config <= writedata;
				end if;
			end if;

			if tis_active then
				-- Update state
				case node_state is
					when TIS_RUN =>
						node_state <= TIS_LEFT;
					when TIS_LEFT =>
						node_state <= TIS_RIGHT;
					when TIS_RIGHT =>
						node_state <= TIS_UP;
					when TIS_UP =>
						node_state <= TIS_DOWN;
					when TIS_DOWN =>
						node_state <= TIS_FINISH;
					when TIS_FINISH =>
						node_state <= TIS_RUN;
				end case;

				-- Default I/O state
				o_left_active <= '0';
				o_right_active <= '0';
				o_up_active <= '0';
				o_down_active <= '0';
				node_output <= std_logic_vector(to_signed(values(head_ptr), node_output'length));

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
								values(head_ptr) <= to_tis_integer(signed(i_left));
								-- Read/Write
								o_left_active <= '1';
								o_right_active <= '1';

							elsif o_left_active = '1' and i_left_active = '1' then
								-- Read value from LEFT
								values(IncrementPTR(head_ptr)) <= to_tis_integer(signed(i_left));
								head_ptr <= IncrementPTR(tail_ptr);
								count <= count + 1;
								-- Read if buffer can take another value
								if count < (buffer_length - 1) then
									-- Read from RIGHT
									o_right_active <= '1';
								end if;
								-- Write to LEFT
								o_left_active <= '1';

							elsif o_right_active = '1' and i_right_active = '1' then
								-- Written value to RIGHT
								head_ptr <= DecrementPTR(head_ptr);
								count <= count - 1;
								-- Check if any values are left in buffer
								if count > 1 then
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
						when TIS_UP =>
							-- Check previous I/O result
							if o_left_active = '1' and i_left_active = '1' and o_right_active = '1' and i_right_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								assert not (count = 0 or count = buffer_length) report "The assumption was wrong!" severity failure;
								-- Store value
								values(head_ptr) <= to_tis_integer(signed(i_right));
								-- Read/Write
								o_down_active <= '1';
								o_up_active <= '1';

							elsif o_right_active = '1' and i_right_active = '1' then
								-- Read value from RIGHT
								values(IncrementPTR(head_ptr)) <= to_tis_integer(signed(i_right));
								head_ptr <= IncrementPTR(head_ptr);
								count <= count + 1;
								-- Read if buffer can take another value
								if count < (buffer_length - 1) then
									-- Read from UP
									o_up_active <= '1';
								end if;
								-- Write to DOWN
								o_down_active <= '1';

							elsif o_left_active = '1' and i_left_active = '1' then
								-- Written value to LEFT
								head_ptr <= DecrementPTR(head_ptr);
								count <= count - 1;
								-- Check if any values are left in buffer
								if count > 1 then
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

						when TIS_DOWN =>
							-- Check previous I/O result
							if o_up_active = '1' and i_up_active = '1' and o_down_active = '1' and i_down_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								assert not (count = 0 or count = buffer_length) report "The assumption was wrong!" severity failure;
								-- Store value
								values(head_ptr) <= to_tis_integer(signed(i_up));
								-- Read/Write
								o_up_active <= '1';
								o_down_active <= '1';

							elsif o_up_active = '1' and i_up_active = '1' then
								-- Read value from UP
								values(IncrementPTR(head_ptr)) <= to_tis_integer(signed(i_up));
								head_ptr <= IncrementPTR(head_ptr);
								count <= count + 1;
								-- Read if buffer can take another value
								if count < (buffer_length - 1) then
									-- Read from DOWN
									o_down_active <= '1';
								end if;
								-- Write to UP
								o_up_active <= '1';

							elsif o_down_active = '1' and i_down_active = '1' then
								-- Written value to DOWN
								head_ptr <= DecrementPTR(head_ptr);
								count <= count - 1;
								-- Check if any values are left in buffer
								if count > 1 then
									-- Write to UP
									o_up_active <= '1';
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

						when TIS_FINISH =>
							-- Check previous I/O result
							if o_down_active = '1' and i_down_active = '1' and o_up_active = '1' and i_up_active = '1' then
								-- We already know read and write are possible here
								-- tail_ptr, head_ptr and count stay the same after a simultaneous read/write
								values(head_ptr) <= to_tis_integer(signed(i_down));
							elsif o_down_active = '1' and i_down_active = '1' then
								-- Read value from DOWN
								values(IncrementPTR(head_ptr)) <= to_tis_integer(signed(i_down));
								head_ptr <= IncrementPTR(head_ptr);
								count <= count + 1;
							elsif o_up_active = '1' and i_up_active = '1' then
								-- Written value to UP
								head_ptr <= DecrementPTR(head_ptr);
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
