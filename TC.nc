; ************** 	DECLARE VARIABLES *********************************************************
#<y_travel_pocket> = 55				      ;y travel in or out of pocket
#<z_travel_pocket> = 50				      ;z travel to tool / from tool
#<pocket_feedrate> = 1000           ;feedrate to enter / leave pockets
#<safe_z> = -29
#<pocket_offset> =	61.2						;distance of pockets in X direction
#<pocket_one_x> = -799.490							;x position of first slot
#<pocket_y> = -74.060									;Y position of slot
#<poscket_z> = -195.196									;z position of slots
#<pocket_count> = 5
#<toolSensor_input> = 1               ;results: 0=tool, 1=notool 
#<drawbarSensor_input> = 2            ;results: 0=activated/pressurized 1=not activated
#<measure_start_z> = -100             ;tool touchoff start height
#<_seek_distance> = 100 
#<_seek_feedrate> = 500
#<_retract_distance> = 5
#<_fine_feedrate> = 100
#<manualToolchange_x> = -500          ;x position for manual toolchange
#<manualToolchange_y> = -577          ;y position for manual toolchange
#<toolsetter_x> = -58                 ;toolsetter location
#<toolsetter_y> = -34.7               ;toolsetter location

#<y_outsidePocket> = [#<pocket_y> - #<y_travel_pocket>]      ;calculate position in front of pocket
#<z_abovePocket> = [#<pocket_z> + #<z_travel_pocket>]         ;calculate position above pocket
;*********************************************************************************************

;************** 	VALIDATION ****************************************************************
o100 if [#<_selected_tool> LT 0]            ;if selected tool is negative... not sure if that is even possible
  (debug, Selected Tool: #<_selected_tool> is out of range. Tool change aborted. Program paused.)
  M0
  M99
o100 elseif [#<_selected_tool> EQ #<_current_tool>]
  (debug, Current tool selected. Tool change bypassed.)
  M99
;o100 elseif [#<_selected_tool> EQ 99]
;  (debug, Probe selected)
;  M99  
o100 endif
(debug, valid Tool change. Lets proceed!)
;************** 	END VALIDATION *****************************************************************

;************** BEGIN SETUP *********************************************************************

M5																												;Turn off spindle and coolant
M9
G90  																											;Activate absolute distance mode
;calculate tool locations
#<x_new_tool> = [[[#<_selected_tool> - 1] * #<pocket_offset> ] + #<pocket_one_x>]
#<x_current_tool> = [[[#<_current_tool> - 1] * #<pocket_offset> ] + #<pocket_one_x>]
G53 G0 Z[#<safe_z>]	
;*************** END SETUP ****************

; ************** BEGIN UNLOAD **************
M66 P[#<toolSensor_input>] L0                                       ;check if we really have a physical tool in the spindle
o200 if [#5399 EQ 1]                                                ;nur wenn wir auch wirklich ein tool geladen haben
  (debug, There is no tool in the spindle but we are trying to unload.... ABORT)
  M0
  M99 
o200 elseif  [#5399 EQ 0]
  (debug, Tool in spindle validated. Lets proceed)    
o200 endif

o300 if [#<_current_tool> GT #<pocket_count>]                   
    (debug, We have a tool without slot - manual unload necessary)
    G53 G0 X[#<manualToolchange_x>] Y[#<manualToolchange_y>]
    (debug, Confirm to start manual unloading)
    M0
    G4 P1
    M64 P1
    G4 P3
    M65 P1
    (debug, Tool unloaded. Confirm to proceed)
    M0 
o300 else           
  (debug, Unloading tool with pocket)
    G53 G0 X[#<x_current_tool>] 
    G53 G0 Y[#<y_outsidePocket>] 
    G53 G0 Z[#<pocket_z>]  
    G53 G1 Y[#<pocket_y>]  F[#<pocket_feedrate>]						          	;move into pocket
    G4 P0
    M64 P1                                                             ;release tool
    (debug, activate AIR IN)
    G4 P1                                                               ;wait a second for pressure to build up
    M66 P[#<drawbarSensor_input>] L0                                       ;read sensor status (0=tool, 1=notool)
    (debug, Read drawbar sensor input: #5399) 	
      o320 if [#5399 EQ 1]   
        (debug, something is wrong - drawbar not activated. ABORT)
        ;M99
      o320 elseif [#5399 EQ 0]
        (debug, drawbar actuated. Lets proceed) 
      o320 endif																						
    G53 G0 Z[#<z_abovePocket>] ;F[#<pocket_feedrate>]										;move spindle up - away from tool
    G4 P0
    M65 P1																										;close valve
		(debug, shut off AIR IN)
o300 endif 
; *************** END UNLOAD ***************

; *************** BEGIN LOAD ***************
o400 if [#<_selected_tool> EQ 0]  
    (debug, Tool 0 selected - spindle remains empty. Do Nothing)
o400 elseif [#<_selected_tool> GT #<pocket_count>]   
	  G53 G0 Z[#<safe_z>]		                
    (debug, manual tool load necessary)
    G53 G0 X[#<manualToolchange_x>] 
    G53 G0 Y[#<manualToolchange_y>]
    (debug, Confirm to start manual loading)
    M0
    G4 P1
    M64 P1
    G4 P3
    M65 P1
    G4 P1
    M64 P0
    G4 P3
    M65 P0
    (debug, Tool loaded. Confirm to proceed.)
    M0 
o400 else
	(debug, loading a tool with a pocket)
  G53 G0 X[#<x_new_tool>] Y[#<pocket_y>] 
  G53 G0 Z[#<z_abovePocket>]
  (debug, Move over pocket #<_selected_tool>)
  G4 P0
  (debug, activate AIR IN)
  M64 P1 																										;open drawbar
  G4 P1
  G53 G1 Z[#<pocket_z>] F[#<pocket_feedrate>] 	
  G4 P1
  M65 P1 																										;close drawbar
  (debug, shut off AIR IN)
  G4 P0.5
  (debug, activate AIR RETURN)
  M64 P0																										;activate air return for x sec
  G4 P3
  (debug, shut off AIR RETURN)
  M65 P0
  M66 P[#<toolSensor_input>] L0                                       ;read sensor status (0=tool, 1=notool)
  (debug, Read drawbar sensor input: #5399) 
      o410 if [#5399 EQ 1]   
        (debug, Something is wrong - tool check failed. ABORT)
        M99
      o410 elseif [#5399 EQ 0]
        (debug, We have a tool in the spindle. Lets proceed) 
      o410 endif	
  G53 G1 Y[#<y_outsidePocket>] F[#<pocket_feedrate>]                  ;leave pocket

o400 endif

M61 Q[#<_selected_tool>]
G4 P0
  (debug, Successfully loaded tool #<_current_tool>)
; *************** END LOAD *****************

;####################start measure#################

G53 G0 Z[#<safe_z>]		

o600 if [#<_selected_tool> NE 0]
  ;  we have a tool.
  ; Remove any G43.1 Z offset
  G43.1 Z0
  (debug, G43.1 Z offset removed)
  o610 if [#5220 EQ 1]
    #<_z_offset> = [#5213 + #5223]
  o610 elseif [#5220 EQ 2]
    #<_z_offset> = [#5213 + #5243]
  o610 elseif [#5220 EQ 3]
    #<_z_offset> = [#5213 + #5263]
  o610 elseif [#5220 EQ 4]
    #<_z_offset> = [#5213 + #5283]
  o610 elseif [#5220 EQ 5]
    #<_z_offset> = [#5213 + #5303]
  o610 elseif [#5220 EQ 6]
    #<_z_offset> = [#5213 + #5323]
  o610 elseif [#5220 EQ 7]
    #<_z_offset> = [#5213 + #5343]
  o610 elseif [#5220 EQ 8]
    #<_z_offset> = [#5213 + #5363]
  o610 elseif [#5220 EQ 9]
    #<_z_offset> = [#5213 + #5383]
  o610 endif

  G53 G90 G0 Z[#<safe_z>]
  G53 G0 X[#<toolsetter_x>] Y[#<toolsetter_y>]
  G53 G0 Z[#<measure_start_z>]
  G38.2 G91 Z[#<_seek_distance> * -1] F[#<_seek_feedrate>]
  G0 G91 Z[#<_retract_distance>]
  G38.2 G91 Z[[#<_retract_distance> + 1] * -1] F[#<_fine_feedrate>]
  G53 G0 G90 Z[#<safe_z>]
  #<_adjust_z> = [#5063 + #<_z_offset>]
  G4 P0
    G43.1 Z[#<_adjust_z>]
  $TLR
  (debug, TLR set)
o600 else
  (debug, Tool 0 ... measurement disabled)
o600 endif
; ************* END MEASURE ****************

G53 G0 Z[#<safe_z>]		
