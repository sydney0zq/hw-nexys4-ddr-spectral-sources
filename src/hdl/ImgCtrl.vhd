----------------------------------------------------------------------------------
-- Description: The module performs three concurent loops:
--   acquisition  loops:
--     stores 1024 samples at 48KSPS in TimeBlkMemForFft, indexed by intAddraTime 
--     (synchronized with the FftBlock)
--   FFT unload loop:
--     unloads time samples from the fft core
--     (synchronized by the  FftBlock)
--   display loop
--     displays the time samples and the frequency samples on the VGA display 
--     ( synchronized by the VGA ctrl)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

use work.DisplayDefinition.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ImgCtrl is
    Port ( ck100MHz : in STD_LOGIC;
     -- time domain data signals       
           enaTime : in STD_LOGIC;  --enable 
           weaTime : in STD_LOGIC;  --write enable
           addraTime : in STD_LOGIC_VECTOR (10 downto 0); --address
           dinaTime : in STD_LOGIC_VECTOR (7 downto 0);   --data in
     -- frequency domain data signals
--         enaFreq : in STD_LOGIC;
           weaFreq : in STD_LOGIC;
           addraFreq : in STD_LOGIC_VECTOR (10 downto 0);
           dinaFreq : in STD_LOGIC_VECTOR (7 downto 0);
     -- video signals
           ckVideo : in STD_LOGIC;
           flgActiveVideo: in std_logic;  -- active video flag
           adrHor: in integer range 0 to cstHorSize - 1; -- pixel counter
           adrVer: in integer range 0 to cstVerSize - 1; -- lines counter
		   red : out  STD_LOGIC_VECTOR (3 downto 0);
           green : out  STD_LOGIC_VECTOR (3 downto 0);
           blue : out  STD_LOGIC_VECTOR (3 downto 0));
end ImgCtrl;

architecture Behavioral of ImgCtrl is

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT blk_mem_gen_0
  PORT (
    clka : IN STD_LOGIC;
    ena : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;
ATTRIBUTE SYN_BLACK_BOX : BOOLEAN;
ATTRIBUTE SYN_BLACK_BOX OF blk_mem_gen_0 : COMPONENT IS TRUE;
ATTRIBUTE BLACK_BOX_PAD_PIN : STRING;
ATTRIBUTE BLACK_BOX_PAD_PIN OF blk_mem_gen_0 : COMPONENT IS "clka,ena,wea[0:0],addra[10:0],dina[7:0],clkb,enb,addrb[10:0],doutb[7:0]";

-- COMP_TAG_END ------ End COMPONENT Declaration ------------

  signal sampleDisplayTime: STD_LOGIC_VECTOR (7 downto 0);  -- time domain sample for display
  signal sampleDisplayFreq: STD_LOGIC_VECTOR (7 downto 0);  -- freq domain sample for display

  --1280x1024 signal vecadrHor: std_logic_vector(10 downto 0); -- pixel counter (vector)
  signal vecadrHor: std_logic_vector(10 downto 0); -- pixel counter (vector)
  signal vecadrVer: std_logic_vector(9 downto 0); -- lines counter (vector)

  signal intRed: STD_LOGIC_VECTOR (3 downto 0); 
  signal intGreen: STD_LOGIC_VECTOR (3 downto 0); 
  signal intBlue: STD_LOGIC_VECTOR (3 downto 0); 
 
begin

    -- read in advance for compensating the synchronous BRAM delay
    vecadrHor <= conv_std_logic_vector(0, 11) when adrHor = cstHorSize - 1 else
                                conv_std_logic_vector(adrHor + 1, 11); 
    vecadrVer <= conv_std_logic_vector(adrVer, 10);

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
    TimeBlkMemForDisplay: blk_mem_gen_0
  PORT MAP (
    clka => ck100MHz,
    ena => enaTime, -- active while counting
    wea(0) => weaTime,  -- wea is std_logic_vector(0 downto 0) ...
    addra => addraTime,
    dina => dinaTime,
    clkb => ckVideo,  -- Video clock 
    enb => '1',
    addrb => vecadrHor,
    doutb => sampleDisplayTime
  );
-- INST_TAG_END ------ End INSTANTIATION Template ---------

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
FreqBlkMemForDisplay: blk_mem_gen_0
  PORT MAP (
    clka => ck100MHz,
    ena => '1', -- always active 
    wea(0) => weaFreq,  -- wea is std_logic_vector(0 downto 0) ...
    addra => addraFreq,
    dina =>dinaFreq, -- selected byte!!!

    clkb => ckVideo,  -- Video clock 
    enb => '1',
    addrb => "000" & vecadrHor(10 downto 3),
    --addrb => "000" & vecadrHor(9 downto 3), -- divide by 8. Display 640/8 = 80 points. Point = 96Khz/512 = 187.5Hz
    doutb => sampleDisplayFreq
  );

-- INST_TAG_END ------ End INSTANTIATION Template ---------

  intRed <= "1111" when adrVer <= cstVerAf/2 and 
                        adrVer >= cstVerAf/4 - conv_integer(sampleDisplayTime) else "0000";
  intGreen <= "1111" when --adrVer >= cstVerAf/2 and 
                         adrVer >= cstVerAf*63/64 - conv_integer("0" & sampleDisplayFreq(7) & sampleDisplayFreq(6 downto 0)) else "0000";
  intBlue <= "1111" when --adrVer >= cstVerAf/2 and 
                        -- frequency range (lower half of the VGA display)
                        adrVer >= cstVerAf*63/64 - conv_integer("0" & sampleDisplayFreq(7) & sampleDisplayFreq(6 downto 0)) and 
                        -- a frequency marker every 10 bins 
                        --(adrHor/8 = 0 or adrHor/8 = 10 or adrHor/8 = 20 or adrHor/8 = 30 or adrHor/8 = 40 or adrHor/8 = 50 or adrHor/8 = 60 or adrHor/8 = 70)
                        (adrHor/8 = 0 or adrHor/8 = 10 or adrHor/8 = 20 or adrHor/8 = 30 or adrHor/8 = 40 or adrHor/8 = 50 or adrHor/8 = 60 or adrHor/8 = 70 or adrHor/8 = 80 or adrHor/8 = 90 or adrHor/8 = 100 or adrHor/8 = 110 or adrHor/8 = 120 or adrHor/8 = 130 or adrHor/8 = 140 or adrHor/8 = 150)
        else "1111" when
                -- time range (upper half of the VGA display)
                adrVer >= cstVerAf*31/64 and -- - conv_integer(sampleDisplayTime) and 
                adrVer < cstVerAf*32/64 and 
                -- a marker every 48 time samples
                ((adrHor = 1*48) or 
                 (adrHor = 2*48) or 
                 (adrHor = 3*48) or 
                 (adrHor = 4*48) or 
                 (adrHor = 5*48) or 
                 (adrHor = 6*48) or 
                 (adrHor = 7*48) or 
                 (adrHor = 8*48) or 
                 ((adrHor >=  9*48) and 
                  (adrHor <= 10*48)) or 
                 (adrHor = 11*48) or 
                 (adrHor = 12*48) or
                 (adrHor = 13*48) or 
                 (adrHor = 14*48) or 
                 (adrHor = 15*48) or 
                 (adrHor = 16*48) or 
                 (adrHor = 17*48) or 
                 (adrHor = 18*48) or 
                ((adrHor >=  19*48) and 
                 (adrHor <= 20*48)) or 
                 (adrHor = 21*48) or 
                 (adrHor = 22*48) or 
                 (adrHor = 23*48) or 
                 (adrHor = 24*48) or 
                 (adrHor = 25*48) or
                 (adrHor = 26*48))  

        else "0000";

  red <= intRed when flgActiveVideo = '1' else "0000";
  green <= intGreen when flgActiveVideo = '1' else "0000";
  blue <= intBlue when flgActiveVideo = '1' else "0000";

end Behavioral;

