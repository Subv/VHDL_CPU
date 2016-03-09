library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.RegisterFileTypePackage.all;

entity CPU is 
	Port(
		clk : in std_logic;
		output : out unsigned(15 downto 0);
		
		lcd_forward : in std_logic;
		
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
      data_bus_7 : inout std_logic
	);
end CPU;

architecture CPU_Arch of CPU is
	component LCD
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
	end component;
	
	signal fetched_instruction : unsigned(15 downto 0) := "1111111111111110";

	signal Registers : RegisterFileType := (others => "0000000000000000");
	
	signal ProgramCounter : unsigned(7 downto 0) := "00000000";
	
	type ProgramStorage is array(255 downto 0) of unsigned(15 downto 0);
	constant Program : ProgramStorage := (
		0 => "0110000000000000",
		1 => "1011100000000000",
		others => "1111111111111110"
	);
	
	signal FirstOperand : unsigned(3 downto 0) := "0000";
	signal SecondOperand : unsigned(6 downto 0) := "0000000";
	signal Opcode : unsigned(4 downto 0) := "11111";
	
	shared variable MultResult : unsigned(31 downto 0) := "00000000000000000000000000000000";
	
	signal Halted : std_logic := '0';
	
	signal CmpOp : unsigned(1 downto 0) := "00";
	
	-- CMP results
	signal CmpLessThan : std_logic := '0';
	signal CmpGreaterThan : std_logic := '0';
	signal CmpEqual : std_logic := '0';
	
	type RAMType is array(255 downto 0) of unsigned(15 downto 0);
	signal RAM : RAMType;
begin

-- Instantiate the LCD controller
LCD_Controller : LCD port map(reset, clock_50, lcd_rs, lcd_e, lcd_rw, lcd_on, lcd_blon, 
										data_bus_0, data_bus_1, data_bus_2, data_bus_3, data_bus_4, 
										data_bus_5, data_bus_6, data_bus_7, lcd_forward, Registers);

process(clk, Registers, Halted)
	begin
		if (rising_edge(clk) and Halted = '0') then
			-- Fetch
			fetched_instruction <= Program(to_integer(ProgramCounter));
			-- Increment PC in Fetch stage
			ProgramCounter <= ProgramCounter + 1;
			
			-- Decode
			Opcode <= fetched_instruction(15 downto 11);
			FirstOperand <= fetched_instruction(10 downto 7);
			SecondOperand <= fetched_instruction(6 downto 0);
			CmpOp <= fetched_instruction(8 downto 7);
			
			-- Execute
			case Opcode is
				when "00000" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) + Registers(to_integer(SecondOperand));
				when "00010" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(SecondOperand));
				when "00011" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) - Registers(to_integer(SecondOperand));
				when "00100" => MultResult := Registers(to_integer(FirstOperand)) * Registers(to_integer(SecondOperand)); Registers(to_integer(FirstOperand)) <= MultResult(15 downto 0);
				when "00101" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) + ("000000000" & SecondOperand);
				when "00110" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) - ("000000000" & SecondOperand);
				when "00111" => Registers(to_integer(FirstOperand)) <= ("000000000" & SecondOperand);
				when "01000" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) srl to_integer(Registers(to_integer(SecondOperand)));
				when "01001" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) sll to_integer(Registers(to_integer(SecondOperand)));
				when "01010" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) srl to_integer(("000000000" & SecondOperand));
				when "01011" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) sll to_integer(("000000000" & SecondOperand));
				when "01100" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) + 1;
				when "01101" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) - 1;
				when "01110" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) xor Registers(to_integer(SecondOperand));
				when "01111" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) or Registers(to_integer(SecondOperand));
				when "10000" => Registers(to_integer(FirstOperand)) <= Registers(to_integer(FirstOperand)) and Registers(to_integer(SecondOperand));
				when "10001" => Registers(to_integer(FirstOperand)) <= not Registers(to_integer(FirstOperand));
				when "10010" => Registers(to_integer(FirstOperand)) <= RAM(to_integer("0" & SecondOperand));
				when "10011" => RAM(to_integer("0" & SecondOperand)) <= Registers(to_integer(FirstOperand));
				when "10100" => Registers(to_integer(FirstOperand)) <= RAM(to_integer(unsigned(Registers(to_integer(SecondOperand))(7 downto 0))));
				when "10101" => RAM(to_integer(unsigned(Registers(to_integer(SecondOperand))(7 downto 0)))) <= Registers(to_integer(FirstOperand));
				when "10110" => 
					case CmpOp is
						when "00" => 
							ProgramCounter <= Registers(to_integer(FirstOperand))(7 downto 0);
							-- Flush the pipeline
							FirstOperand <= "0000";
							SecondOperand <= "0000000";
							Opcode <= "11111";
							fetched_instruction <= "1111111111111110";
						when "01" =>
							if (CmpLessThan = '1') then
								ProgramCounter <= Registers(to_integer(FirstOperand))(7 downto 0);
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;
						when "10" =>
							if (CmpGreaterThan = '1') then
								ProgramCounter <= Registers(to_integer(FirstOperand))(7 downto 0);
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;
						when "11" =>
							if (CmpEqual = '1') then
								ProgramCounter <= Registers(to_integer(FirstOperand))(7 downto 0);
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;						
					end case;
				when "10111" => 
					case CmpOp is
						when "00" => 
							ProgramCounter <= "0" & SecondOperand;
							-- Flush the pipeline
							FirstOperand <= "0000";
							SecondOperand <= "0000000";
							Opcode <= "11111";
							fetched_instruction <= "1111111111111110";
						when "01" =>
							if (CmpLessThan = '1') then
								ProgramCounter <= "0" & SecondOperand;
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;
						when "10" =>
							if (CmpGreaterThan = '1') then
								ProgramCounter <= "0" & SecondOperand;
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;
						when "11" =>
							if (CmpEqual = '1') then
								ProgramCounter <= "0" & SecondOperand;
								-- Flush the pipeline
								FirstOperand <= "0000";
								SecondOperand <= "0000000";
								Opcode <= "11111";
								fetched_instruction <= "1111111111111110";
							end if;						
					end case;
				when "11000" => 
					if (to_integer(Registers(to_integer(FirstOperand))) < to_integer(Registers(to_integer(SecondOperand)))) then
						CmpLessThan <= '1';
					else
						CmpLessThan <= '0';
					end if;
					
					if (to_integer(Registers(to_integer(FirstOperand))) > to_integer(Registers(to_integer(SecondOperand)))) then
						CmpGreaterThan <= '1';
					else
						CmpGreaterThan <= '0';
					end if;
					
					if (to_integer(Registers(to_integer(FirstOperand))) = to_integer(Registers(to_integer(SecondOperand)))) then
						CmpEqual <= '1';
					else
						CmpEqual <= '0';
					end if;
				when "11001" => 
					if (to_integer(Registers(to_integer(FirstOperand))) < to_integer("000000000" & SecondOperand)) then
						CmpLessThan <= '1';
					else
						CmpLessThan <= '0';
					end if;
					
					if (to_integer(Registers(to_integer(FirstOperand))) > to_integer("000000000" & SecondOperand)) then
						CmpGreaterThan <= '1';
					else
						CmpGreaterThan <= '0';
					end if;
					
					if (to_integer(Registers(to_integer(FirstOperand))) = to_integer("000000000" & SecondOperand)) then
						CmpEqual <= '1';
					else
						CmpEqual <= '0';
					end if;
				when others => 
					if (SecondOperand = "1111111") then
						Halted <= '1';
					end if;
			end case;
		end if;
		
		output <= Registers(0);
	end process;
end CPU_Arch;