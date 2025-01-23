library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_node is
	port (
		clk            : in  std_logic;
		reset          : in  std_logic;

		output         : out std_logic_vector(10 downto 0);

		i_left_active  : in  std_logic;
		o_left_active  : out std_logic;

		i_right_active : in  std_logic;
		o_right_active : out std_logic;

		i_up_active    : in  std_logic;
		o_up_active    : out std_logic;

		i_down_active  : in  std_logic;
		o_down_active  : out std_logic
	);
end entity;

architecture rtl of tis_node is
	-- Addressable CPU register
	signal acc : integer range - 999 to 999 := 0;
	-- Non-addressable CPU register
	signal bak : integer range - 999 to 999 := 0;
	-- Program Counter
	signal pc : unsigned(3 downto 0) := 0;

	-- L -> 11
	-- R -> 01
	-- U -> 10
	-- D -> 00
	type node is (NONE, LEFT, RIGHT, UP, DOWN);
	-- Gets set every read and write
	signal last_node : node := NONE;
begin
	process (reset, clk) is
	begin
		if reset = '1' then
			acc <= 0;
			bak <= 0;
			pc <= 0;
			last_node <= NONE;
			o_left_active <= '0';
			o_right_active <= '0';
			o_up_active <= '0';
			o_down_active <= '0';
		elsif rising_edge(clk) then

		end if;
	end process;
end architecture;
