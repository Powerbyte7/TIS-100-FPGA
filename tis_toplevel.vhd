library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_toplevel is
	port (
		CLOCK_50 : in std_logic;
		KEY      : in std_logic_vector(3 downto 0)
	);
end entity;

architecture rtl of tis_toplevel is
	component tis_system is
		port (
			clk_clk       : in std_logic := 'X'; -- clk
			reset_reset_n : in std_logic := 'X'  -- reset_n
		);
	end component;

begin
	u0: component tis_system
		port map (
			clk_clk       => CLOCK_50, --   clk.clk
			reset_reset_n => KEY(0) -- reset.reset_n
		);
end architecture;
