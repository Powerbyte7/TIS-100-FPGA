-- altera vhdl_input_version vhdl_2008
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity tis_execution_node is
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
		i_left_active           : in  std_logic; -- W = 1, R = 0
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
		o_down_active           : out std_logic;
		-- For debugging purposes
		debug_acc               : out integer range - 999 to 999;
		debug_bak               : out integer range - 999 to 999;
		debug_pc                : out unsigned(3 downto 0)
	);
end entity;

architecture rtl of tis_execution_node is
	-- Avalon Memory
	type registers is array (0 to 7) of std_logic_vector(31 downto 0);
	signal regs : registers;

	-- CPU State
	constant NIL   : std_logic_vector(2 downto 0) := "000";
	constant ACC   : std_logic_vector(2 downto 0) := "001";
	constant UP    : std_logic_vector(2 downto 0) := "010";
	constant DOWN  : std_logic_vector(2 downto 0) := "011";
	constant LEFT  : std_logic_vector(2 downto 0) := "100";
	constant RIGHT : std_logic_vector(2 downto 0) := "101";
	constant ANY   : std_logic_vector(2 downto 0) := "110";
	constant LAST  : std_logic_vector(2 downto 0) := "111";

	type tis_state is (TIS_RUN, TIS_LEFT, TIS_RIGHT, TIS_UP, TIS_DOWN, TIS_FINISH);

	signal node_state   : tis_state                     := TIS_RUN; -- Write/Read direction of node
	signal node_src     : std_logic_vector(10 downto 0) := (others => '0');
	signal node_src_reg : std_logic_vector(2 downto 0)  := NIL;
	signal node_dst     : std_logic_vector(10 downto 0) := (others => '0');
	signal node_dst_reg : std_logic_vector(2 downto 0)  := NIL;

	signal node_io_read  : std_logic := '0';
	signal node_io_write : std_logic := '0';

	-- node_last gets set after recieving/writing using ANY
	signal node_last : std_logic_vector(2 downto 0) := NIL;

	-- Addressable CPU register
	signal node_acc : integer range - 999 to 999 := 0;
	-- Non-addressable CPU register
	signal node_bak : integer range - 999 to 999 := 0;
	-- Program Counter
	signal node_pc : unsigned(3 downto 0) := (others => '0');
	-- Instruction at current PC
	signal current_instruction : std_logic_vector(15 downto 0);

begin
	Q_export  <= regs(0);
	debug_acc <= node_acc;
	debug_bak <= node_bak;
	debug_pc  <= node_pc;

	memory_bus: process (clock, resetn)
	begin
		if resetn = '0' then
			regs <= (others => (others => '0'));
		elsif rising_edge(clock) then
			if chipselect = '1' then
				if read = '1' then
					readdata <= regs(to_integer(unsigned(address)));
				elsif write = '1' then
					for i in 0 to 3 loop
						if byteenable(i) = '1' then
							regs(to_integer(unsigned(address)))(i * 8 + 7 downto i * 8) <= writedata(i * 8 + 7 downto i * 8);
						end if;
					end loop;
				end if;
			end if;
		end if;
	end process;

	instruction_fetch: process (node_pc, regs)
	begin
		-- Get the current intstruction by reading address in program counter
		if node_pc(0) = '1' then
			current_instruction <= regs(to_integer(node_pc(3 downto 1)) + 1)(15 downto 0);
		elsif node_pc(0) = '0' then
			current_instruction <= regs(to_integer(node_pc(3 downto 1)))(31 downto 16);
		end if;
	end process;

	o_left  <= node_dst;
	o_right <= node_dst;
	o_up    <= node_dst;
	o_down  <= node_dst;

	processor: process (clock, resetn)
	begin
		if resetn = '0' then
			node_state <= TIS_RUN;
			node_acc <= 0;
			node_bak <= 0;
			node_pc <= (others => '0');
			node_last <= NIL;
			node_src <= (others => '0');
			node_src_reg <= NIL;
			node_dst <= (others => '0');
			node_dst_reg <= NIL;
			node_state <= TIS_RUN;
		elsif rising_edge(clock) then
			if tis_active = '1' then
				-- Capture ACC from previous ALU operation
				case node_state is
					when TIS_RUN =>
						-- DEBUG
						report "PC: " & to_string(to_integer(node_pc)) & " ACC: " & to_string(node_acc) severity note;

						-- Only proceed without ongoing I/O operation
						if (node_io_read = '0') and (node_io_write = '0') then
							-- Decode Instruction
							case current_instruction(15 downto 14) is
								when "00" => -- ADD/SUB
									if current_instruction(11) = '1' then
										-- ADD or SUB with register
										if current_instruction(2 downto 0) = NIL then
											-- Do nothing for NIL
											node_io_read <= '0';
											node_io_write <= '0';
										elsif current_instruction(2 downto 0) = LAST then
											-- If LAST is 000, node will never complete reading
											node_io_read <= '1';
											node_io_write <= '0';
											node_src_reg <= node_last;
										else
											node_io_read <= '1';
											node_io_write <= '0';
											node_src_reg <= current_instruction(2 downto 0);
										end if;
									else
										-- ADD or SUB with immediate operand
										if current_instruction(10) = '1' then
											report "OPC: SUB " & to_string(unsigned(current_instruction(9 downto 0))) severity note;
											node_io_read <= '0';
											node_io_write <= '0';
											node_acc <= node_acc - to_integer(unsigned(current_instruction(9 downto 0)));
											node_pc <= node_pc + 1;
										else
											report "OPC: ADD " & to_string(unsigned(current_instruction(9 downto 0))) severity note;
											node_io_read <= '0';
											node_io_write <= '0';
											node_acc <= node_acc + to_integer(unsigned(current_instruction(9 downto 0)));
											node_pc <= node_pc + 1;
										end if;
									end if;
								when "10" => -- MOV with immediate operand
									if current_instruction(13 downto 11) = NIL then
										-- Do nothing for NIL
										node_io_read <= '0';
										node_io_write <= '0';
									elsif current_instruction(13 downto 11) = ACC then
										node_io_read <= '0';
										node_io_write <= '0';
										node_acc <= to_integer(signed(current_instruction(10 downto 0)));
									elsif current_instruction(13 downto 11) = LAST then
										-- If LAST is 000, node will never complete writing
										node_io_read <= '0';
										node_io_write <= '1';
										node_dst_reg <= node_last;
										node_dst <= current_instruction(10 downto 0);
									else
										node_io_read <= '0';
										node_io_write <= '1';
										node_dst_reg <= current_instruction(13 downto 11);
										node_dst <= current_instruction(10 downto 0);
									end if;
								when "11" => -- MOV with <SRC>
									if current_instruction(2 downto 0) = NIL then
										node_io_read <= '1';
										node_io_write <= '1';
										node_src <= (others => '0');
									elsif current_instruction(2 downto 0) = LAST then
										node_io_read <= '1';
										node_io_write <= '1';
										-- If LAST is 000, node will never complete reading
										node_src_reg <= node_last;
									end if;
								when others =>
							end case;
						end if; -- IO_NONE check

						node_state <= TIS_LEFT;
					when TIS_LEFT => -- Read LEFT, Write RIGHT
						-- Default
						o_left_active <= '0';
						o_right_active <= '0';
						o_up_active <= '0';
						o_down_active <= '0';

						-- Signal willingness to write/read
						if node_io_read = '1' then
							if (node_src_reg = LEFT) or (node_src_reg = ANY) then
								o_left_active <= '1';
							end if;
						elsif node_io_write = '1' then
							if (node_src_reg = RIGHT) or (node_src_reg = ANY) then
								o_right_active <= '1';
							end if;
						end if;

						node_state <= TIS_RIGHT;
					when TIS_RIGHT => -- Read RIGHT, Write LEFT
						-- Default
						o_left_active <= '0';
						o_right_active <= '0';
						o_up_active <= '0';
						o_down_active <= '0';

						-- Signal willingness to write/read
						if node_io_read = '1' then
							-- Check whether previous read was successful
							if (i_left_active = '1') and ((node_src_reg = LEFT) or (node_src_reg = ANY)) then
								-- READ success!
								node_src <= i_left;
								node_io_read <= '0';
							elsif (node_src_reg = RIGHT) or (node_src_reg = ANY) then
								o_right_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_right_active = '1') and ((node_src_reg = RIGHT) or (node_src_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
							elsif (node_dst_reg = LEFT) or (node_dst_reg = ANY) then
								o_left_active <= '1';
							end if;
						end if;

						node_state <= TIS_UP;
					when TIS_UP => -- Read UP, Write DOWN
						-- Default
						o_left_active <= '0';
						o_right_active <= '0';
						o_up_active <= '0';
						o_down_active <= '0';

						-- Signal willingness to write/read
						if node_io_read = '1' then
							-- Check whether previous read was successful
							if (i_right_active = '1') and ((node_src_reg = RIGHT) or (node_src_reg = ANY)) then
								-- READ success!
								node_src <= i_right;
								node_io_read <= '0';
							elsif (node_src_reg = UP) or (node_src_reg = ANY) then
								o_up_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_left_active = '1') and ((node_src_reg = LEFT) or (node_src_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
							elsif (node_dst_reg = DOWN) or (node_dst_reg = ANY) then
								o_down_active <= '1';
							end if;
						end if;

						node_state <= TIS_DOWN;
					when TIS_DOWN => -- Read DOWN, Write UP
						-- Default
						o_left_active <= '0';
						o_right_active <= '0';
						o_up_active <= '0';
						o_down_active <= '0';

						-- Signal willingness to write/read
						if node_io_read = '1' then
							-- Check whether previous read was successful
							if (i_up_active = '1') and ((node_src_reg = UP) or (node_src_reg = ANY)) then
								-- READ success!
								node_src <= i_up;
								node_io_read <= '0';
							elsif (node_src_reg = DOWN) or (node_src_reg = ANY) then
								o_down_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_down_active = '1') and ((node_src_reg = DOWN) or (node_src_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
							elsif (node_dst_reg = UP) or (node_dst_reg = ANY) then
								o_up_active <= '1';
							end if;
						end if;

						node_state <= TIS_FINISH;
					when TIS_FINISH =>

						-- Check whether previous read/write was successful
						if node_io_read = '1' then
							if (i_down_active = '1') and ((node_src_reg = DOWN) or (node_src_reg = ANY)) then
								-- READ success!
								node_src <= i_up;
								node_io_read <= '0';
							end if;
						elsif node_io_read = '1' then
							if (i_up_active = '1') and ((node_src_reg = UP) or (node_src_reg = ANY)) then
								-- READ success!
								node_io_write <= '0';
							end if;
						end if;

						node_state <= TIS_RUN;

					-- TODO: Set node_src
				end case;
			end if; -- active
		end if; -- clk/reset
	end process;

	-- Set last active
end architecture;
