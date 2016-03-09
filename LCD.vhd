library IEEE;
library work;
use work.RegisterFileTypePackage.all;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity LCD is 
	Port(
		reset : in std_logic;  -- Map this Port to a Switch within your [Port Declarations / Pin Planer]  
      clock_50 : in std_logic;  -- Using the DE2 50Mhz Clk, in order to Genreate the 400Hz signal... clk_count_400hz reset count value must be set to:  <= x"0F424"
      
      lcd_rs : out std_logic;
      lcd_e : out std_logic;
      lcd_rw : out std_logic;
      lcd_on : out std_logic;
      lcd_blon : out std_logic;
      
      data_bus_0 : inout std_logic;
      data_bus_1 : inout std_logic;
      data_bus_2 : inout std_logic;
      data_bus_3 : inout std_logic;
      data_bus_4 : inout std_logic;
      data_bus_5 : inout std_logic;
      data_bus_6 : inout std_logic;
      data_bus_7 : inout std_logic;
		
		lcd_forward : in std_logic;
		
		Registers : in RegisterFileType
	);
end LCD;

architecture Driver of LCD is

	type character_string is array(0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
	
	type state_type is (hold, func_set, display_on, mode_set, print_string,
								line2, return_home, drop_lcd_e, reset1, reset2,
								reset3, display_off, display_clear);
	
	signal state, next_command         : state_type;
	
	signal lcd_display_string_0123       : character_string;
	signal lcd_display_string_4567       : character_string;
	signal lcd_display_string_89AB       : character_string;
	signal lcd_display_string_CDEF       : character_string;
	
	signal data_bus_value, next_char   : STD_LOGIC_VECTOR(7 downto 0);
	signal clk_count_400hz             : STD_LOGIC_VECTOR(19 downto 0);
	signal char_count                  : STD_LOGIC_VECTOR(4 downto 0);
	signal clk_400hz_enable,lcd_rw_int : std_logic;
	signal data_bus                    : STD_LOGIC_VECTOR(7 downto 0);	
	
	signal current_line : std_logic_vector(1 downto 0);
begin
	-- Send the current databus values to the LCD controller
	data_bus_0 <= data_bus(0);
	data_bus_1 <= data_bus(1);
	data_bus_2 <= data_bus(2);
	data_bus_3 <= data_bus(3);
	data_bus_4 <= data_bus(4);
	data_bus_5 <= data_bus(5);
	data_bus_6 <= data_bus(6);
	data_bus_7 <= data_bus(7);
	
	-- BIDIRECTIONAL TRI STATE LCD DATA BUS
	data_bus <= data_bus_value when lcd_rw_int = '0' else "ZZZZZZZZ";

	-- LCD_RW PORT is assigned to it matching SIGNAL 
	lcd_rw <= lcd_rw_int;

	lcd_display_string_0123 <= 
		 (
	-- R0 
				 x"52",x"30", x"7E", x"0" & std_logic_vector(Registers(0)(15 downto 12)), x"0" & std_logic_vector(Registers(0)(11 downto 8)), x"0" & std_logic_vector(Registers(0)(7 downto 4)), x"0" & std_logic_vector(Registers(0)(3 downto 0)), x"20",
	--	R1		 
				 x"52",x"31", x"7E", x"0" & std_logic_vector(Registers(1)(15 downto 12)), x"0" & std_logic_vector(Registers(1)(11 downto 8)), x"0" & std_logic_vector(Registers(1)(7 downto 4)), x"0" & std_logic_vector(Registers(1)(3 downto 0)), x"20",
	-- R2 
				 x"52",x"32", x"7E", x"0" & std_logic_vector(Registers(2)(15 downto 12)), x"0" & std_logic_vector(Registers(2)(11 downto 8)), x"0" & std_logic_vector(Registers(2)(7 downto 4)), x"0" & std_logic_vector(Registers(2)(3 downto 0)), x"20",
	--	R3		 
				 x"52",x"33", x"7E", x"0" & std_logic_vector(Registers(3)(15 downto 12)), x"0" & std_logic_vector(Registers(3)(11 downto 8)), x"0" & std_logic_vector(Registers(3)(7 downto 4)), x"0" & std_logic_vector(Registers(3)(3 downto 0)), x"20"	 
		);
		
	lcd_display_string_4567 <= 
		 (
	-- R4 
				 x"52",x"34", x"7E", x"0" & std_logic_vector(Registers(4)(15 downto 12)), x"0" & std_logic_vector(Registers(4)(11 downto 8)), x"0" & std_logic_vector(Registers(4)(7 downto 4)), x"0" & std_logic_vector(Registers(4)(3 downto 0)), x"20",
	--	R5		 
				 x"52",x"35", x"7E", x"0" & std_logic_vector(Registers(5)(15 downto 12)), x"0" & std_logic_vector(Registers(5)(11 downto 8)), x"0" & std_logic_vector(Registers(5)(7 downto 4)), x"0" & std_logic_vector(Registers(5)(3 downto 0)), x"20",
	-- R6 
				 x"52",x"36", x"7E", x"0" & std_logic_vector(Registers(6)(15 downto 12)), x"0" & std_logic_vector(Registers(6)(11 downto 8)), x"0" & std_logic_vector(Registers(6)(7 downto 4)), x"0" & std_logic_vector(Registers(6)(3 downto 0)), x"20",
	--	R7		 
				 x"52",x"37", x"7E", x"0" & std_logic_vector(Registers(7)(15 downto 12)), x"0" & std_logic_vector(Registers(7)(11 downto 8)), x"0" & std_logic_vector(Registers(7)(7 downto 4)), x"0" & std_logic_vector(Registers(7)(3 downto 0)), x"20"	 
		);

	lcd_display_string_89AB <= 
		 (
	-- R8 
				 x"52",x"38", x"7E", x"0" & std_logic_vector(Registers(8)(15 downto 12)), x"0" & std_logic_vector(Registers(8)(11 downto 8)), x"0" & std_logic_vector(Registers(8)(7 downto 4)), x"0" & std_logic_vector(Registers(8)(3 downto 0)), x"20",
	--	R9		 
				 x"52",x"39", x"7E", x"0" & std_logic_vector(Registers(9)(15 downto 12)), x"0" & std_logic_vector(Registers(9)(11 downto 8)), x"0" & std_logic_vector(Registers(9)(7 downto 4)), x"0" & std_logic_vector(Registers(9)(3 downto 0)), x"20",
	-- RA 
				 x"52",x"41", x"7E", x"0" & std_logic_vector(Registers(10)(15 downto 12)), x"0" & std_logic_vector(Registers(10)(11 downto 8)), x"0" & std_logic_vector(Registers(10)(7 downto 4)), x"0" & std_logic_vector(Registers(10)(3 downto 0)), x"20",
	--	RB		 
				 x"52",x"42", x"7E", x"0" & std_logic_vector(Registers(11)(15 downto 12)), x"0" & std_logic_vector(Registers(11)(11 downto 8)), x"0" & std_logic_vector(Registers(11)(7 downto 4)), x"0" & std_logic_vector(Registers(11)(3 downto 0)), x"20"	 
		);

	lcd_display_string_CDEF <= 
		 (
	-- RC 
				 x"52",x"43", x"7E", x"0" & std_logic_vector(Registers(12)(15 downto 12)), x"0" & std_logic_vector(Registers(12)(11 downto 8)), x"0" & std_logic_vector(Registers(12)(7 downto 4)), x"0" & std_logic_vector(Registers(12)(3 downto 0)), x"20",
	--	RD		 
				 x"52",x"44", x"7E", x"0" & std_logic_vector(Registers(13)(15 downto 12)), x"0" & std_logic_vector(Registers(13)(11 downto 8)), x"0" & std_logic_vector(Registers(13)(7 downto 4)), x"0" & std_logic_vector(Registers(13)(3 downto 0)), x"20",
	-- RE 
				 x"52",x"45", x"7E", x"0" & std_logic_vector(Registers(14)(15 downto 12)), x"0" & std_logic_vector(Registers(14)(11 downto 8)), x"0" & std_logic_vector(Registers(14)(7 downto 4)), x"0" & std_logic_vector(Registers(14)(3 downto 0)), x"20",
	--	RF		 
				 x"52",x"46", x"7E", x"0" & std_logic_vector(Registers(15)(15 downto 12)), x"0" & std_logic_vector(Registers(15)(11 downto 8)), x"0" & std_logic_vector(Registers(15)(7 downto 4)), x"0" & std_logic_vector(Registers(15)(3 downto 0)), x"20"	 
		);
		
	-- Process to handle switching the current LCD page
	process (lcd_forward)
	begin
		if (rising_edge(lcd_forward)) then
			current_line <= current_line + 1;
		end if;
	end process;

	-- Process to handle displaying the next character in the LCD
	process (char_count, current_line, lcd_forward, lcd_display_string_0123, lcd_display_string_4567, lcd_display_string_89AB, lcd_display_string_CDEF)
	begin
		case current_line is
			when "00" => next_char <= lcd_display_string_0123(CONV_INTEGER(char_count));
			when "01" => next_char <= lcd_display_string_4567(CONV_INTEGER(char_count));
			when "10" => next_char <= lcd_display_string_89AB(CONV_INTEGER(char_count));
			when "11" => next_char <= lcd_display_string_CDEF(CONV_INTEGER(char_count));
		end case;
	end process;
	
	-- Process to downscale the 50Mhz clock and generate a new 400Hz clock
	process(clock_50)
	begin
		if (rising_edge(clock_50)) then
			if (reset = '0') then
				clk_count_400hz <= x"00000";
				clk_400hz_enable <= '0';
			else
				if (clk_count_400hz <= x"0F424") then          -- If using the DE2 50Mhz Clock,  use clk_count_400hz <= x"0F424"  (50Mhz/400hz = 12500 converted to HEX = 0F424 )   
					clk_count_400hz <= clk_count_400hz + 1; --  In Theory for a 27Mhz Clock,  use clk_count_400hz <= x"01A5E"  (27Mhz/400hz = 6750  converted to HEX = 01A5E )                                       
					clk_400hz_enable <= '0';                --  In Theory for a 25Mhz Clock.  use clk_count_400hz <= x"0186A"  (25Mhz/400hz = 6250  converted to HEX = 0186A )
				else
					clk_count_400hz <= x"00000";
					clk_400hz_enable <= '1';
				end if;
			end if;
		end if;
	end process;
	
--======================== LCD DRIVER CORE ==============================--   
--                     STATE MACHINE WITH RESET                          -- 
--===================================================-----===============--  
process (clock_50, reset, lcd_forward)
begin
	if reset = '0' then
		state <= reset1;
		data_bus_value <= x"38"; -- RESET
		next_command <= reset2;
		lcd_e <= '1';
		lcd_rs <= '0';
		lcd_rw_int <= '0';  
	elsif rising_edge(clock_50) then
		if clk_400hz_enable = '1' then  
			-- LCD controller state machine
			case state is
			-- Set Function to 8-bit transfer and 2 line display with 5x8 Font size
			-- see Hitachi HD44780 family data sheet for LCD command and timing details
			
				-- Start the initialization sequence
				when reset1 =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"38"; -- EXTERNAL RESET
					state <= drop_lcd_e;
					next_command <= reset2;
					char_count <= "00000";  
				when reset2 =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"38"; -- EXTERNAL RESET
					state <= drop_lcd_e;
					next_command <= reset3;
				when reset3 =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"38"; -- EXTERNAL RESET
					state <= drop_lcd_e;
					next_command <= func_set;
				-- Function Set
				--==============--
				when func_set =>                
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"38";  -- Set Function to 8-bit transfer, 2 line display and a 5x8 Font size
					state <= drop_lcd_e;
					next_command <= display_off;
				-- Turn off Display
				--==============-- 
				when display_off =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"08"; -- Turns OFF the Display, Cursor OFF and Blinking Cursor Position OFF.......(0F = Display ON and Cursor ON, Blinking cursor position ON)
					state <= drop_lcd_e;
					next_command <= display_clear;
				-- Clear Display 
				--==============--
				when display_clear =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"01"; -- Clears the Display    
					state <= drop_lcd_e;
					next_command <= display_on;
				-- Turn on Display and Turn off cursor
				--===================================--
				when display_on =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"0C"; -- Turns on the Display (0E = Display ON, Cursor ON and Blinking cursor OFF) 
					state <= drop_lcd_e;
					next_command <= mode_set;
				-- Set write mode to auto increment address and move cursor to the right
				--====================================================================--
				when mode_set =>
					lcd_e <= '1';
					lcd_rs <= '0';
					lcd_rw_int <= '0';
					data_bus_value <= x"06"; -- Auto increment address and move cursor to the right
					state <= drop_lcd_e;
					next_command <= print_string; 
				-- Initialization end.
  
  
  
				--=======================================================================--                           
				--               Write ASCII hex character Data to the LCD
				--=======================================================================--
				when print_string =>          
					state <= drop_lcd_e;
					lcd_e <= '1';
					lcd_rs <= '1';
					lcd_rw_int <= '0';

					-- ASCII character to output
					-- A value starting with 0000 indicates that the next byte should be displayed as hex in the display
					if (next_char(7 downto 4) /= x"0") then
						data_bus_value <= next_char;
					else
						-- Convert 4-bit value to an ASCII hex digit
						if next_char(3 downto 0) >9 then 
							-- ASCII A...F
							data_bus_value <= x"4" & (next_char(3 downto 0)-9); 
						else 
							-- ASCII 0...9
							data_bus_value <= x"3" & next_char(3 downto 0);
						end if;
					end if;
  
					-- Loop to send out 32 characters to LCD Display (16 by 2 lines)
					if (char_count < 31) AND (next_char /= x"fe") then
						char_count <= char_count +1;                            
					else
						char_count <= "00000";
					end if;
					
					-- Jump to second line?
					if char_count = 15 then 
						next_command <= line2;
  					-- Return to first line?
					elsif (char_count = 31) or (next_char = x"fe") then
						next_command <= return_home;
					else 
						next_command <= print_string; 
					end if;
					
					-- Set write address to line 2 character 1
					--======================================--
					when line2 =>
						lcd_e <= '1';
						lcd_rs <= '0';
						lcd_rw_int <= '0';
						data_bus_value <= x"c0";
						state <= drop_lcd_e;
						next_command <= print_string;      
					-- Return write address to first character position on line 1
					--=========================================================--
					when return_home =>
						lcd_e <= '1';
						lcd_rs <= '0';
						lcd_rw_int <= '0';
						data_bus_value <= x"80";
						state <= drop_lcd_e;
						next_command <= print_string; 
					-- The next states occur at the end of each command or data transfer to the LCD
					-- Drop LCD E line - falling edge loads inst/data to LCD controller
					--============================================================================--
					when drop_lcd_e =>
						lcd_e <= '0';
						state <= hold;
					-- Hold LCD inst/data valid after falling edge of E line
					--====================================================--
					when hold =>
						state <= next_command;
						lcd_blon <= '1';
						lcd_on   <= '1';
				end case;
			end if; -- CLOSING STATEMENT FOR "IF clk_400hz_enable = '1' THEN"
		end if;-- CLOSING STATEMENT FOR "IF reset = '0' THEN" 
	end process;
end Driver;