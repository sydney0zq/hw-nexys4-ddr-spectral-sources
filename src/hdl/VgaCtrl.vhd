----------------------------------------------------------------------------------
-- Description: 
--  the component is a VGA controller:
--      generates the HS and VS synchro signals 
--      geerates the adrHor and adrVer pixel and line counters
--      generates flgActiveVideo during the active area of the VGA image
-- Dependencies: 
--  DisplayDefinition package including VGA timing constants
--
-- Simplified block diagram of a VGA controller
    -- https://ws1.sinaimg.cn/large/006tNc79gy1fgp52oz4t8j30yv0jldhr.jpg
-- Timing diagram of a horizontal scan
    -- https://ws2.sinaimg.cn/large/006tNc79gy1fgp595w6xdj30i70j575s.jpg
-- Timing diagram of a vertical scan
    -- https://ws4.sinaimg.cn/large/006tNc79gy1fgp59yk07fj30mp0egjse.jpg
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.DisplayDefinition.all;

entity VgaCtrl is
    Port ( ckVideo : in  STD_LOGIC; -- clock 
           adrHor: out integer range 0 to cstHorSize - 1; -- pixel counter
           adrVer: out integer range 0 to cstVerSize - 1; -- lines counter
		   flgActiveVideo: out std_logic; -- active video flag
           -- The hsync and vsync signals are connected to the VGA port to control 
           -- the horizontal and vertical scans of the monitor. The two signals are
           -- decoded from the internal counters, whose outputs are the pixel_x and
           -- pixel_y signals.
           HS : out  STD_LOGIC;
           VS : out  STD_LOGIC);
end VgaCtrl;

architecture Behavioral of VgaCtrl is
 
  signal cntHor: integer range 0 to cstHorSize - 1; -- pixel counter
  signal cntVer: integer range 0 to cstVerSize - 1; -- lines counter
  
  signal inHS: std_logic; -- internal Hor Sync
  signal inVS: std_logic; -- internal Ver Sync
  
  signal inAl, inAf: std_logic; -- internal Active -Line -Frame

begin

  HorCounter: process(ckVideo)
  begin
    if ckVideo'event and ckVideo = '1' then
	   if cntHor = cstHorSize - 1 then
		  cntHor <= 0;
		else
		  cntHor <= cntHor + 1;
		end if;
	 end if;
  end process;

  HorSync: process(ckVideo)
  begin
    if ckVideo'event and ckVideo = '1' then
	   if cntHor = cstHorAl + cstHorFp - 1 then
		  inHS <= '0';
	   elsif cntHor = cstHorAl + cstHorFp + cstHorPw - 1 then
		  inHS <= '1';
		end if;
	 end if;
  end process;

  ActiveLine: process(ckVideo)
  begin
    if ckVideo'event and ckVideo = '1' then
	   if cntHor = cstHorSize - 1 then
		  inAl <= '1';
	   elsif cntHor = cstHorAl - 1 then
		  inAl <= '0';
		end if;
	 end if;
  end process;

  VerCounter: process(inHS)
  begin
    if inHS'event and inHS = '1' then
	   if cntVer = cstVerSize - 1 then
		  cntVer <= 0;
		else
		  cntVer <= cntVer + 1;
		end if;
	 end if;
  end process;

  VerSync: process(inHS)
  begin
    if inHS'event and inHS = '1' then
	   if cntVer = cstVerAf + cstVerFp - 1 then
		  inVS <= '0';
	   elsif cntVer = cstVerAf + cstVerFp + cstVerPw - 1 then
		  inVS <= '1';
		end if;
	 end if;
  end process;
  
  ActiveFrame: process(inHS)
  begin
    if inHS'event and inHS = '1' then
	   if cntVer = cstVerSize - 1 then
		  inAf <= '1';
	   elsif cntVer = cstVerAf - 1 then
		  inAf <= '0';
		end if;
	 end if;
  end process;

  VS <= inVS;
  HS <= inHS;
  
  flgActiveVideo <= inAl and inAf;
  
  adrHor <= cntHor;
  adrVer <= cntVer;

end Behavioral;

