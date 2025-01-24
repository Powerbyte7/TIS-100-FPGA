library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tis_toplevel is
	port (
		CLOCK_50 : in  std_logic;
		KEY      : in  std_logic_vector(3 downto 0);
		LEDR     : out std_logic_vector(9 downto 0);
		SW       : in  std_logic_vector(9 downto 0)
	);
end entity;

architecture rtl of tis_toplevel is

	component tis_system is
		port (
			clk_clk                : in std_logic := 'X'; -- clk
			reset_reset_n          : in std_logic := 'X'; -- reset_n
			tis_enable_tis_enable  : in std_logic := 'X'; -- tis_enable
			tis_step_tis_step_once : in std_logic := 'X'  -- tis_step_once
		);
	end component;

	signal tis_active : std_logic;

begin
	LEDR(0) <= SW(0);
	LEDR(9) <= not KEY(1); -- Reset
	LEDR(8) <= not KEY(0); -- Step once

	u0: component tis_system
		port map (
			clk_clk                => CLOCK_50, --        clk.clk
			reset_reset_n          => KEY(1),   --      reset.reset_n
			tis_enable_tis_enable  => SW(0),    -- tis_enable.tis_enable
			tis_step_tis_step_once => not KEY(0) --   tis_step.tis_step_once
		);

end architecture;
