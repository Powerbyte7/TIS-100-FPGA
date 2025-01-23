-- altera vhdl_input_version vhdl_2008
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.numeric_std.all;

entity tis_node is
	port (
		clock, resetn           : in  std_logic;
		read, write, chipselect : in  std_logic;
		address                 : in  std_logic_vector(15 downto 0);
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
end entity;

architecture rtl of tis_node is
	-- Avalon Memory
	type registers is array (0 to 7) of std_logic_vector(31 downto 0);
	signal regs : registers;

	-- Addressable CPU register
	signal acc : integer range - 999 to 999 := 0;
	-- Non-addressable CPU register
	signal bak : integer range - 999 to 999 := 0;
	-- Program Counter
	signal pc : unsigned(3 downto 0) := (others => '0');
	-- Reading and writing to NONE freezes the node
	type node is (NONE, LEFT, RIGHT, UP, DOWN);
	-- last_node gets set every read/write
	signal last_node : node := NONE;

    signal current_instruction : std_logic_vector(15 downto 0);
begin
	Q_export <= regs(0);

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

	processor: process (clock, resetn)
	begin
		if resetn = '1' then
			acc <= 0;
			bak <= 0;
			pc <= (others => '0');
			last_node <= NONE;
			o_left_active <= '0';
			o_right_active <= '0';
			o_up_active <= '0';
			o_down_active <= '0';
		elsif rising_edge(clock) then
			if tis_active then
                -- Get the current intstruction by reading address in program counter
                if pc(0) = '0' then
				    current_instruction <= regs(to_integer(pc(3 downto 1)))(15 downto 0);
                elsif pc(0) = '1' then
				    current_instruction <= regs(to_integer(pc(3 downto 1)))(31 downto 16);
                end if;
			end if;
		end if;
	end process;
end architecture;
