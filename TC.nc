; ************** 	DECLARE VARIABLES *********************************************************
#<y_travel_pocket> = 55				; Verfahrweg in Tasche / aus Tasche heraus
#<z_travel_pocket> = 50				; Z Verfahrweg auf das tool / vom tool weg
#<safe_z> = -29
#<pocket_offset> =	61.2						; abstand der slots in X richtung
#<pocket_one_x> = -799.490							; Koordinaten des ersten slots
#<pocket_y> = -74.060									; Y Koordinaten der slots
#<pocket_z> = -195.196									; Z Koordinaten der slots
#<pocket_count> = 5
#<toolSensor_input> = 1               ; 0=tool, 1=notool 
#<drawbarSensor_input> = 2            ; 0=activated/pressurized 1=not activated
#<measure_start_z> = -100
#<_seek_distance> = 100 
#<_seek_feedrate> = 500
#<_retract_distance> = 5
#<_fine_feedrate> = 100
#<manualToolchange_x> = -318
#<manualToolchange_y> = -577
#<toolsetter_x> = -58
#<toolsetter_y> = -34.7
#<pocket_feedrate> = 1000
#<y_outsidePocket> = [#<pocket_y> - #<y_travel_pocket>]
#<z_abovePocket> = [#<pocket_z> + #<z_travel_pocket>]
;*********************************************************************************************

;************** 	VALIDATION ****************************************************************
o100 if [#<_selected_tool> LT 0]            ;wenn neues tool groesser als 0
  (debug, Selected Tool: #<_selected_tool> is out of range. Tool change aborted. Program paused.)
  M0
  M99
o100 elseif [#<_selected_tool> EQ #<_current_tool>]
  (debug, Current tool selected. Tool change bypassed.)
  M99
o100 elseif [#<_selected_tool> EQ 99]
  (debug, Probe selected)
  M99  
o100 endif
(debug, valid Tool change. Lets proceed!)
;************** 	END VALIDATION *****************************************************************

;************** BEGIN SETUP *********************************************************************
M5																												;Turn off spindle and coolant
M9
G90  																											;Activate absolute distance mode

;Set tool locations
#<x_new_tool> = [[[#<_selected_tool> - 1] * #<pocket_offset> ] + #<pocket_one_x>]
(debug, new Tool X set to #<x_new_tool>)
;(debug, Berechnung: selected tool  #<_selected_tool> - 1 mal pocketoffset #<pocket_offset> + pocketoneX #<pocket_one_x>)

#<x_current_tool> = [[[#<_current_tool> - 1] * #<pocket_offset> ] + #<pocket_one_x>]
(debug, current Tool X set to #<x_current_tool>)

G53 G0 Z[#<safe_z>]																				
  (debug, Moved to safe clearance)
; *************** END SETUP ****************

; ************** BEGIN UNLOAD **************

o200 if [#<_current_tool> GT #<pocket_count>]                                       ;Unload only if we have a tool in the spindle. Else skip to load
(debug, manual toolchange necessary)
    G53 G0 X[#<manualToolchange_x>] 
    G53 G0 Y[#<manualToolchange_y>]
    (debug, preparing manual toolchange)
    M0
    G4 P1
    M64 P1
    G4 P3
    M65 P1
    G4 P1
    M64 P0
    G4 P3
    M65 P0
    (debug, waiting for user input to proceed)
    M0 
o200 else
  M66 P[#<toolSensor_input>] L0                                       ;check if we really have a physical tool in the spindle
  ;(debug, Read tool status: #5399) 
  
  o210 if [#5399 EQ 1]                                                  ;nur wenn wir auch wirklich ein tool geladen haben
    (debug, We have no tool in the spindle but a valid tool is set. ABORT)
    ;M99 
  o210 elseif  [#5399 EQ 0]
    (debug, We have a tool in the spindle. Lets proceed)    
  o210 endif

    G53 G0 X[#<x_current_tool>] 
    G53 G0 Y[#<y_outsidePocket>] 
    G53 G0 Z[#<pocket_z>]  ;fahre vor den slot
    G53 G1 Y[#<pocket_y>]  F[#<pocket_feedrate>]						          	;fahre in den slot
    G4 P0
    M64 P1                                                             ;release tool
    (debug, activate AIR IN)
    G4 P1                                                               ;wait a second for pressure to build up
    M66 P[#<drawbarSensor_input>] L0                                       ;sensorstatus auslesen (0=tool, 1=notool)
    (debug, Read drawbar sensor input: #5399) 	
      o220 if [#5399 EQ 1]   
        (debug, something is wrong - drawbar not activated. ABORT)
        ;M99
      o220 elseif [#5399 EQ 0]
        (debug, drawbar actuated. Lets proceed) 
      o220 endif																						
    G53 G0 Z[#<z_abovePocket>] ;F[#<pocket_feedrate>]										;spindel nach oben fahren - weg vom tool
    G4 P0
    M65 P1																										;ventil wird geschlossen
		(debug, shut off AIR IN)
o200 endif 
; *************** END UNLOAD ***************

; *************** BEGIN LOAD ***************
    (debug, We start loading tool #<_selected_tool>)
o300 if [#<_selected_tool> GT 0]                             ;dont load if tool0 was called.

  G53 G0 X[#<x_new_tool>] Y[#<pocket_y>] Z[#<z_abovePocket>]
    (debug, Move over pocket #<_selected_tool>)
  G4 P0
    (debug, activate AIR IN)
  M64 P1 																										;spannzange oeffnen
  G4 P0.5
  G53 G1 Z[#<pocket_z>] F[#<pocket_feedrate>] 	
  G4 P0.5
  M65 P1 																										;spannzange schliessen / ventil schliessen
    (debug, shut off AIR IN)
  G4 P0.5
    (debug, activate AIR RETURN)
  M64 P0																										;air return aktivieren fuer 5 sek
  G4 P2
    (debug, shut off AIR RETURN)
  M65 P0
  M66 P[#<toolSensor_input>] L0                                       ;sensorstatus auslesen (0=tool, 1=notool)
    (debug, Read drawbar sensor input: #5399) 

      o310 if [#5399 EQ 1]   
        (debug, Something is wrong - tool not loaded. ABORT)
        ;M99
      o310 elseif [#5399 EQ 0]
        (debug, We have a tool in the spindle. Lets proceed) 
      o310 endif	

  G53 G1 Y[#<y_outsidePocket>] F[#<pocket_feedrate>]     ;fahre aus der tasche heraus

o300 endif

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
    (debug, Z Offset Calculated in G54: #<_z_offset>)
  o610 elseif [#5220 EQ 2]
    #<_z_offset> = [#5213 + #5243]
    (debug, Z Offset Calculated in G55: #<_z_offset>)
  o610 elseif [#5220 EQ 3]
    #<_z_offset> = [#5213 + #5263]
    (debug, Z Offset Calculated in G56: #<_z_offset>)
  o610 elseif [#5220 EQ 4]
    #<_z_offset> = [#5213 + #5283]
    (debug, Z Offset Calculated in G57: #<_z_offset>)
  o610 elseif [#5220 EQ 5]
    #<_z_offset> = [#5213 + #5303]
    (debug, Z Offset Calculated in G58: #<_z_offset>)
  o610 elseif [#5220 EQ 6]
    #<_z_offset> = [#5213 + #5323]
    (debug, Z Offset Calculated in G59: #<_z_offset>)
  o610 elseif [#5220 EQ 7]
    #<_z_offset> = [#5213 + #5343]
    (debug, Z Offset Calculated in G59.1: #<_z_offset>)
  o610 elseif [#5220 EQ 8]
    #<_z_offset> = [#5213 + #5363]
    (debug, Z Offset Calculated in G59.2: #<_z_offset>)
  o610 elseif [#5220 EQ 9]
    #<_z_offset> = [#5213 + #5383]
    (debug, Z Offset Calculated in G59.3: #<_z_offset>)
  o610 endif

  G53 G90 G0 Z[#<safe_z>]
  (debug, Move to Z safe)
  G53 G0 X[#<toolsetter_x>] Y[#<toolsetter_y>]
  (debug, Move to tool setter XY)
  G53 G0 Z[#<measure_start_z>]
  (debug, Down to Z seek start)
  G38.2 G91 Z[#<_seek_distance> * -1] F[#<_seek_feedrate>]
  (debug, Probe Z down seek mode)
  G0 G91 Z[#<_retract_distance>]
  (debug, Retract from tool setter)
  G38.2 G91 Z[[#<_retract_distance> + 1] * -1] F[#<_fine_feedrate>]
  (debug, Probe Z down set mode)
  G53 G0 G90 Z[#<safe_z>]
  (debug, Triggered Work Z: #5063)

  #<_adjust_z> = [#5063 + #<_z_offset>]
  (debug, Triggered Mach Z: #<_adjust_z>)
  G4 P0
    (debug, Ref Mach Pos: 0, Work Z before G43.1: #<_z>)
    G43.1 Z[#<_adjust_z>]
    (debug, Ref Mach Pos: 0, Work Z after G43.1: #<_z>)
  $TLR
  (debug, TLR set)
o600 else
  (debug, Tool 0 ... measurement disabled)
o600 endif
; ************* END MEASURE ****************

G53 G0 Z[#<safe_z>]		
