-- altera vhdl_input_version vhdl_2008
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity tis_execution_node is
	port (
		clock, resetn  : in  std_logic;
		read, write    : in  std_logic;
		address        : in  std_logic_vector(2 downto 0);
		readdata       : out std_logic_vector(31 downto 0);
		writedata      : in  std_logic_vector(31 downto 0);
		byteenable     : in  std_logic_vector(3 downto 0);
		Q_export       : out std_logic_vector(31 downto 0);
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
		o_down_active  : out std_logic;
		-- For debugging purposes
		debug_acc      : out std_logic_vector(10 downto 0);
		debug_bak      : out std_logic_vector(10 downto 0);
		debug_pc       : out unsigned(3 downto 0)
	);
end entity;

architecture rtl of tis_execution_node is
	-- Avalon Memory
	type registers is array (0 to 7) of std_logic_vector(31 downto 0);
	signal regs : registers;

	procedure IncrementPC(
			signal pc               : inout unsigned(3 downto 0);
			signal last_instruction : in    unsigned(3 downto 0)
		) is
	begin
		if pc = last_instruction then
			pc <= (others => '0');
		else
			pc <= pc + 1;
		end if;
	end procedure;

	procedure SetPC(
			signal pc               : out unsigned(3 downto 0);
			signal last_instruction : in  unsigned(3 downto 0);
			signal value            : in  std_logic_vector(3 downto 0)
		) is
	begin
		if unsigned(value) < last_instruction then
			pc <= unsigned(value);
		else
			pc <= last_instruction;
		end if;
	end procedure;

	procedure OffsetsetPC(
			signal pc               : inout unsigned(3 downto 0);
			signal last_instruction : in    unsigned(3 downto 0);
			signal value            : in    std_logic_vector(3 downto 0)
		) is
	begin

		if signed(pc) + signed(value) >= 0 then
			if signed(pc) + signed(value) < signed(last_instruction) then
				pc <= unsigned(signed(pc) + signed(value));
			else
				pc <= last_instruction;
			end if;
		else
			pc <= (others => '0');
		end if;

	end procedure;

	-- IO State
	constant NIL   : std_logic_vector(2 downto 0) := "000";
	constant ACC   : std_logic_vector(2 downto 0) := "001";
	constant UP    : std_logic_vector(2 downto 0) := "010";
	constant DOWN  : std_logic_vector(2 downto 0) := "011";
	constant LEFT  : std_logic_vector(2 downto 0) := "100";
	constant RIGHT : std_logic_vector(2 downto 0) := "101";
	constant ANY   : std_logic_vector(2 downto 0) := "110";
	constant LAST  : std_logic_vector(2 downto 0) := "111";

	-- Jump conditions
	constant JMP : std_logic_vector(2 downto 0) := "000";
	constant JEZ : std_logic_vector(2 downto 0) := "001";
	constant JLZ : std_logic_vector(2 downto 0) := "010";
	constant JGZ : std_logic_vector(2 downto 0) := "100";
	constant JNZ : std_logic_vector(2 downto 0) := "110";

	type tis_state is (TIS_RUN, TIS_LEFT, TIS_RIGHT, TIS_UP, TIS_DOWN, TIS_FINISH);

	signal node_state    : tis_state                    := TIS_RUN; -- Write/Read direction of node
	signal node_io_value : integer range - 999 to 999   := 0;
	signal node_src_reg  : std_logic_vector(2 downto 0) := NIL;
	signal node_dst_reg  : std_logic_vector(2 downto 0) := NIL;

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
	signal current_instruction      : std_logic_vector(15 downto 0);
	signal last_instruction_address : unsigned(3 downto 0);

begin
	Q_export  <= regs(0);
	debug_acc <= std_logic_vector(to_signed(node_acc, debug_acc'length));
	debug_bak <= std_logic_vector(to_signed(node_bak, debug_acc'length));
	debug_pc  <= node_pc;

	last_instruction_address <= unsigned(regs(0)(3 downto 0));

	memory_bus: process (clock, resetn)
	begin
		if resetn = '0' then
			regs <= (others => (others => '0'));
		elsif rising_edge(clock) then
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
	end process;

	instruction_fetch: process (node_pc, regs)
	begin
		-- Get the current intstruction by reading address in program counter
		if node_pc(0) = '0' then
			current_instruction <= regs(to_integer(node_pc(3 downto 1)))(31 downto 16);
		else
			current_instruction <= regs(to_integer(node_pc(3 downto 1)) + 1)(15 downto 0);
		end if;
	end process;

	o_left  <= std_logic_vector(to_signed(node_io_value, o_left'length));
	o_right <= std_logic_vector(to_signed(node_io_value, o_right'length));
	o_up    <= std_logic_vector(to_signed(node_io_value, o_up'length));
	o_down  <= std_logic_vector(to_signed(node_io_value, o_down'length));

	processor: process (clock, resetn)
	begin
		if resetn = '0' then
			node_state <= TIS_RUN;
			node_acc <= 0;
			node_bak <= 0;
			node_pc <= (others => '0');
			node_last <= NIL;
			node_io_value <= 0;
			node_src_reg <= NIL;
			node_io_value <= 0;
			node_dst_reg <= NIL;
			node_state <= TIS_RUN;
		elsif rising_edge(clock) then
			if tis_active = '1' then
				-- Capture ACC from previous ALU operation
				case node_state is
					when TIS_RUN =>
						-- DEBUG
						-- report "PC: " & to_string(to_integer(node_pc)) & " ACC: " & to_string(node_acc) severity note;
						-- Only proceed without ongoing I/O operation
						if (node_io_read = '0') and (node_io_write = '0') then
							-- Decode Instruction
							case current_instruction(15 downto 14) is
								when "00" => -- ADD/SUB
									node_io_read <= '0';
									node_io_write <= '0';

									-- Avoids previous register from skipping a read on a port 
									node_src_reg <= "111"; 

									if current_instruction(11) = '1' then
										-- ADD or SUB with register
										if current_instruction(2 downto 0) = NIL then
											-- Do nothing for NIL
											node_io_value <= 0;
										elsif current_instruction(2 downto 0) = ACC then
											node_io_value <= node_acc;
										elsif current_instruction(2 downto 0) = LAST then
											-- If LAST is NIL, node will read 0
											if node_last = NIL then
												node_io_value <= 0;
											else
												node_io_read <= '1';
											end if;
											node_src_reg <= node_last;
										else
											node_io_read <= '1';
											node_src_reg <= current_instruction(2 downto 0);
										end if;
									else
										-- ADD or SUB with immediate operand
										if current_instruction(10) = '1' then
											-- report "OPC: SUB " & to_string(unsigned(current_instruction(9 downto 0))) severity note;
											node_io_value <= to_integer(unsigned(current_instruction(9 downto 0)));
										else
											-- report "OPC: ADD " & to_string(unsigned(current_instruction(9 downto 0))) severity note;
											node_io_value <= to_integer(unsigned(current_instruction(9 downto 0)));
										end if;
									end if;
								when "10" => -- MOV #<imm10>, <DST>
									node_io_read <= '1';
									node_io_write <= '1';

									node_src_reg <= NIL; -- Immediate operand in SRC
									node_dst_reg <= current_instruction(13 downto 11);
									node_io_value <= to_integer(signed(current_instruction(10 downto 0)));

									-- <DST>
									if current_instruction(13 downto 11) = LAST then
										node_dst_reg <= node_last;
									end if;
								when "11" => -- MOV <SRC>, <DST>
									node_io_read <= '1';
									node_io_write <= '1';

									node_src_reg <= current_instruction(2 downto 0);
									node_dst_reg <= current_instruction(13 downto 11);

									-- <SRC>
									if current_instruction(2 downto 0) = NIL then
										node_io_value <= 0;
									elsif current_instruction(2 downto 0) = ACC then
										node_io_value <= node_acc;
									elsif current_instruction(2 downto 0) = LAST then
										-- If LAST is NIL, node will read 0
										if node_last = NIL then
											node_io_value <= 0;
										end if;
										node_src_reg <= node_last;
									end if;

									-- <DST>
									if current_instruction(13 downto 11) = LAST then
										node_dst_reg <= node_last;
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
								-- Try read on LEFT port
								o_left_active <= '1';
							end if;
						elsif node_io_write = '1' then
							if (node_dst_reg = RIGHT) or (node_dst_reg = ANY) then
								-- Try write on RIGHT port
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
								node_io_value <= to_integer(signed(i_left));
								node_io_read <= '0';
								if node_src_reg = ANY then
									node_last <= LEFT;
								end if;
							elsif (node_src_reg = RIGHT) or (node_src_reg = ANY) then
								-- Try read on RIGHT port instead
								o_right_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_right_active = '1') and ((node_dst_reg = RIGHT) or (node_dst_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
								if node_dst_reg = ANY then
									node_last <= RIGHT;
								end if;
							elsif (node_dst_reg = LEFT) or (node_dst_reg = ANY) then
								-- Try write on LEFT port instead
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
								node_io_value <= to_integer(signed(i_right));
								node_io_read <= '0';
								if node_src_reg = ANY then
									node_last <= RIGHT;
								end if;
							elsif (node_src_reg = UP) or (node_src_reg = ANY) then
								-- Try read on UP port instead
								o_up_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_left_active = '1') and ((node_dst_reg = LEFT) or (node_dst_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
								if node_dst_reg = ANY then
									node_last <= LEFT;
								end if;
							elsif (node_dst_reg = DOWN) or (node_dst_reg = ANY) then
								-- Try write on DOWN port instead
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
								node_io_value <= to_integer(signed(i_up));
								node_io_read <= '0';
								if node_src_reg = ANY then
									node_last <= UP;
								end if;
							elsif (node_src_reg = DOWN) or (node_src_reg = ANY) then
								-- Try read on DOWN port instead
								o_down_active <= '1';
							end if;
						elsif node_io_write = '1' then
							-- Check whether previous write was successful
							if (i_down_active = '1') and ((node_dst_reg = DOWN) or (node_dst_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
								if node_dst_reg = ANY then
									node_last <= DOWN;
								end if;
							elsif (node_dst_reg = UP) or (node_dst_reg = ANY) then
								-- Try write on UP port instead
								o_up_active <= '1';
							end if;
						end if;

						node_state <= TIS_FINISH;
					when TIS_FINISH =>

						if node_io_read = '1' then
							-- Mark read as done if <SRC> was ACC or NIL
							-- This lets writes to those registers take 1 cycle
							if node_src_reg = ACC or node_src_reg = NIL then
								node_io_read <= '0';

								-- Write to ACC or NIL
								if node_dst_reg = ACC and node_io_write <= '1' then
									node_io_write <= '0';
									node_acc <= node_io_value;
									IncrementPC(node_pc, last_instruction_address);
								elsif node_dst_reg = NIL and node_io_write <= '1' then
									node_io_write <= '0';
									IncrementPC(node_pc, last_instruction_address);
								end if;
							end if;

							-- Check whether previous read/write was successful
							if (i_down_active = '1') and ((node_src_reg = DOWN) or (node_src_reg = ANY)) then
								-- READ success!
								node_io_read <= '0';
								if node_src_reg = ANY then
									node_last <= DOWN;
								end if;

								-- Write to ACC or NIL
								if node_dst_reg = ACC and node_io_write = '1' then
									node_io_write <= '0';
									node_acc <= to_integer(signed(i_down));
									IncrementPC(node_pc, last_instruction_address);
								elsif node_dst_reg = NIL and node_io_write = '1' then
									node_io_write <= '0';
									IncrementPC(node_pc, last_instruction_address);
								end if;

								if current_instruction(15 downto 3) = "0110000000000" then -- JRO
									if (to_integer(node_pc) + to_integer(signed(i_down))) > to_integer(last_instruction_address) then
										-- Clamp to maximum address
										node_pc <= last_instruction_address;
									elsif (to_integer(node_pc) + to_integer(signed(i_down))) < 0 then
										-- Clamp to minimum address
										node_pc <= (others => '0');
									else
										-- Update address
										node_pc <= to_unsigned(to_integer(node_pc) + to_integer(signed(i_down)), node_pc'length);
									end if;
								elsif current_instruction(15 downto 9) = "0111000" then -- JMP
									-- Check JMP conditions
									case current_instruction(8 downto 6) is
										when JMP =>
											-- Bounds check
											SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
										when JEZ =>
											-- Condition
											if node_acc = 0 then
												-- Bounds check
												SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
											else
												IncrementPC(node_pc, last_instruction_address);
											end if;
										when JNZ =>
											-- Condition
											if not (node_acc = 0) then
												-- Bounds check
												SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
											else
												IncrementPC(node_pc, last_instruction_address);
											end if;
										when JGZ =>
											-- Condition
											if node_acc > 0 then
												-- Bounds check
												SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
											else
												IncrementPC(node_pc, last_instruction_address);
											end if;
										when JLZ =>
											-- Condition
											if node_acc < 0 then
												SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
											else
												IncrementPC(node_pc, last_instruction_address);
											end if;
										when others =>
										-- Do nothing
									end case;
								elsif current_instruction(15 downto 12) = "0000" then
									if current_instruction(10) = '1' then
										-- SUB
										node_acc <= node_acc - to_integer(signed(i_down));
										IncrementPC(node_pc, last_instruction_address);
									else
										-- ADD
										node_acc <= node_acc + to_integer(signed(i_down));
										IncrementPC(node_pc, last_instruction_address);
									end if;
								elsif current_instruction = x"4800" then
									-- NEG
									node_acc <= - node_acc;
									IncrementPC(node_pc, last_instruction_address);
								elsif current_instruction = x"4000" then
									-- SAV
									node_bak <= node_acc;
									IncrementPC(node_pc, last_instruction_address);
								elsif current_instruction = x"5000" then
									-- SWP
									node_bak <= node_acc;
									node_acc <= node_bak;
									IncrementPC(node_pc, last_instruction_address);
								else
									-- Increment PC for all other instructions
									IncrementPC(node_pc, last_instruction_address);
								end if;
							end if;
						elsif node_io_write = '1' then
							-- Write to ACC and NIL
							if node_dst_reg = ACC then
								node_io_write <= '0';
								node_acc <= node_io_value;
								IncrementPC(node_pc, last_instruction_address);
							elsif node_dst_reg = NIL then
								node_io_write <= '0';
								IncrementPC(node_pc, last_instruction_address);
							end if;

							if (i_up_active = '1') and ((node_dst_reg = UP) or (node_dst_reg = ANY)) then
								-- WRITE success!
								node_io_write <= '0';
								if node_src_reg = ANY then
									node_last <= UP;
								end if;
								-- Increment PC for all other instructions
								IncrementPC(node_pc, last_instruction_address);
							end if;
						else
							-- Update program counter
							if current_instruction(15 downto 3) = "0110000000000" then -- JRO
								if (to_integer(node_pc) + node_io_value) > to_integer(last_instruction_address) then
									-- Clamp to maximum address
									node_pc <= last_instruction_address;
								elsif (to_integer(node_pc) + node_io_value) < 0 then
									-- Clamp to minimum address
									node_pc <= (others => '0');
								else
									-- Update address
									node_pc <= to_unsigned(to_integer(node_pc) + node_io_value, node_pc'length);
								end if;
							elsif current_instruction(15 downto 9) = "0111000" then -- JMP
								-- Check JMP conditions
								case current_instruction(8 downto 6) is
									when JMP =>
										-- Bounds check
										SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
									when JEZ =>
										-- Condition
										if node_acc = 0 then
											-- Bounds check
											SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
										else
											IncrementPC(node_pc, last_instruction_address);
										end if;
									when JNZ =>
										-- Condition
										if not (node_acc = 0) then
											-- Bounds check
											SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
										else
											IncrementPC(node_pc, last_instruction_address);
										end if;
									when JGZ =>
										-- Condition
										if node_acc > 0 then
											-- Bounds check
											SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
										else
											IncrementPC(node_pc, last_instruction_address);
										end if;
									when JLZ =>
										-- Condition
										if node_acc < 0 then
											SetPC(node_pc, last_instruction_address, current_instruction(3 downto 0));
										else
											IncrementPC(node_pc, last_instruction_address);
										end if;
									when others =>
									-- Do nothing
								end case;
							elsif current_instruction(15 downto 12) = "0000" then
								if current_instruction(10) = '1' then
									-- SUB
									node_acc <= node_acc - node_io_value;
									IncrementPC(node_pc, last_instruction_address);
								else
									-- ADD
									node_acc <= node_acc + node_io_value;
									IncrementPC(node_pc, last_instruction_address);
								end if;
							elsif current_instruction = x"4800" then
								-- NEG
								node_acc <= - node_acc;
								IncrementPC(node_pc, last_instruction_address);
							elsif current_instruction = x"4000" then
								-- SAV
								node_bak <= node_acc;
								IncrementPC(node_pc, last_instruction_address);
							elsif current_instruction = x"5000" then
								-- SWP
								node_bak <= node_acc;
								node_acc <= node_bak;
								IncrementPC(node_pc, last_instruction_address);
							else
								-- Increment PC for all other instructions
								IncrementPC(node_pc, last_instruction_address);
							end if;
						end if;

						node_state <= TIS_RUN;

					-- TODO: Set node_src
				end case;
			end if; -- active
		end if; -- clk/reset
	end process;

end architecture;
