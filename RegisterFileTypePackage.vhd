library ieee;
use ieee.numeric_std.all;

package RegisterFileTypePackage is
	type RegisterFileType is array(15 downto 0) of unsigned(15 downto 0);
end package;