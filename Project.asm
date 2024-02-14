#include "p16f877a.inc"
;NOTES:
;This project was visualized as a 2D project.
;The left sensor as back sensor.
;The right sensor as front sensor.
;The left(back) sensor will go first & calculate the distance, then the right(front) sensor will go and do the same.
;Compare the distances & move the motor

;References:
;Study the value of the capacitors: https://forum.arduino.cc/t/capacitors-for-a-crystal/330184

	cblock 0x20
counter, RB1_FLAG, RB2_FLAG, workingTemp, statusTemp, right_distance, left_distance, T1_HIGH
T1_LOW, counter_left, counter_right, light8LED, delay_counter
counter_last_two, distance, distance_temp, brake_flag
	endc
	org 0x00	
	goto MAIN
	org 0x04
	goto ISR
MAIN
	movlw b'10011000' ;Clear INTF & RBIF, and enable Global Interrupt Controller, External Interrupt, and RB Port Change Interrupt.
	movwf INTCON

	bsf STATUS, RP0 ;Select Bank1
	movlw 0x31 ;0011 0001
	movwf TRISB
	clrf TRISC ;Make all C ports output
	clrf TRISD ;Make all D ports output
	bcf STATUS, RP0 ;Select Bank0

	clrf PORTB
	clrf PORTC
	clrf PORTD

Program_Loop
	clrf STATUS
	movlw d'8'
	movwf light8LED ;light8LED = 8 - Maximum LED's that PORTC can fit.
	movlw d'2'
 	movwf counter_left ;Counter for left sensor to ensure entering twice to the interrupt.
	movwf counter_right	;Counter for right sensor to ensure entering twice to the interrupt.

	clrf counter
	clrf counter_last_two
	
	bcf RB1_FLAG, 0 ;Flag for the left sensor.
	bcf RB2_FLAG, 0 ;Flag for the right sensor.

left_trigger
	bsf PORTB, RB1 ;Set left trigger HIGH.
	call delay_us ;Set the trigger bit for 10us (delay).
	bcf PORTB, RB1 ;Set left trigger LOW.

	bsf RB1_FLAG, 0
leftLoop
	btfsc RB1_FLAG, 0
	goto leftLoop

right_trigger
	bsf PORTB, RB2 ;Set right trigger HIGH.
	call delay_us ;Set the trigger bit for 10us (delay).
	bcf PORTB, RB2 ;Set right trigger LOW.

	bsf RB2_FLAG, 0
rightLoop 
	btfsc RB2_FLAG, 0
	goto rightLoop

compare_distances
	movf right_distance, W
	subwf left_distance, W ;W = left_distance - right_distance
	btfsc STATUS, Z ;Testing if left_distance = right_distance
	goto center_equal
	btfss STATUS, C
	goto move_right ;Testing if left_distance < right_distance
	goto move_left ;Testing if left_distance > right_distance

move_right
	movf right_distance, W
	movwf distance_temp ;Holds the value of the right_distance to divide it by 10.
	call divide_by10

	; Turn on the motor
	bsf PORTD ,RD6 ;Set RD6 as high to move right.

	goto Program_Loop
move_left
	movf left_distance, W
	movwf distance_temp ;Holds the value of the left_distance to divide it by 10.
	call divide_by10

	; Turn on the motor
	bsf PORTD, RD7 ;Set RD7 as high to move left.

	goto Program_Loop
center_equal
	movlw d'5'
	call LED_Lookup
	movwf PORTC

	;PORTD initially is cleared, so we do not need to clear the pin's again to stop the car.
	goto Program_Loop

;Functions
divide_by10
	movlw d'10'
	subwf distance_temp, F ;distance_temp = distance_temp - W(10)
	btfsc STATUS, C ;Testing if distance_temp > 10
	incf counter, F ;Counting number of 10's in distance_temp, to know which LED's to turn ON.
	btfsc STATUS, C
	goto divide_by10
	
	incf counter, W
	subwf light8LED, F

	btfsc STATUS, Z
	goto positive_zero_case ;If light8LED - counter = 0
	btfsc STATUS, C
	goto positive_zero_case ;If light8LED >= counter
	goto negative_case ;If negative (counter > light8LED).

positive_zero_case
	call LED_Lookup
	movwf PORTC
	return

negative_case
	movlw d'8'
	call LED_Lookup
	movwf PORTC
	movlw d'8'
last_two
	subwf counter, W
	call LED_Lookup_last2
	movwf PORTD
	return

delay_us
	movlw d'10'
	movwf delay_counter
delay
	decfsz delay_counter, F
	goto delay
	return

;Multiple interupt
ISR
	;Saving.
	movwf workingTemp ;save the w value
	swapf STATUS, W ;put status in w
	movwf statusTemp ;save the status

	;body - Testing which interrupt.
	btfsc INTCON, INTF
	goto ISR_EXTERNAL_BREAK
	btfsc INTCON, RBIF
	call ISR_ECHO	

	;Retreiving.
	movf workingTemp, W ;retreive the w value
	swapf statusTemp, W 
	movwf STATUS ;retrieve the STATUS value

	retfie ;Re-make GIE one

ISR_EXTERNAL_BREAK
	bcf T1CON, TMR1ON ;Stop the timer.
	
brake_loop
	movf PORTB, W
	andlw 0x01 ;Reading the RB0 status.
	movwf brake_flag
	btfss brake_flag, 0
	goto continue_the_process
	clrf PORTD ;If the brake button is pressed.
	goto brake_loop

continue_the_process
	bcf INTCON, INTF ;Clearing the flag (INTF).
	bsf INTCON, GIE
	goto Program_Loop

ISR_ECHO
	btfsc RB1_FLAG, 0
	call left_sensor_echo
	btfsc RB2_FLAG, 0
	call right_sensor_echo
	bcf INTCON, RBIF ;Clearing the flag (RBIF).
	return
left_sensor_echo
	bsf T1CON, TMR1ON ;Start TIMER1
	bcf PORTB, RB1 ;Set left trigger LOW

	decfsz counter_left
	return
	
	bcf RB1_FLAG, 0
	bcf T1CON, TMR1ON ;Stop TIMER1
	call calculate_distance ;Calculate the distance.

	movf distance, W
	movwf left_distance

	clrf distance
	clrf TMR1L ;Clearing TMR1L
	clrf TMR1H ;Clearing TMR1H

	return

right_sensor_echo
	bsf T1CON, TMR1ON ;Start TIMER1
	bcf PORTB, RB2 ;Turn off the right trigger.

	decfsz counter_right
	return

	bcf RB2_FLAG, 0
	bcf T1CON, TMR1ON ;Stop TIMER1
	call calculate_distance

	movf distance, W
	movwf right_distance

	clrf distance

	clrf TMR1L ;Clearing TMR1L
	clrf TMR1H ;Clearing TMR1H	
	
	return
;The distacne = Time / 59
calculate_distance
	call divideLow

	movlw d'4'
	addwf distance, F ;Add 4 to the distance for the last round of TMR1L.

	return
divideLow
	movlw d'59' ;RoundUp(2 / 34x10^(-3))
	subwf TMR1L, F
	incf distance, F
	btfsc STATUS, C
	goto divideLow
	goto divideHigh
divideHigh
	movlw d'1'
	subwf TMR1H, F ;TMR1H = TMR1H - 1
	btfsc STATUS, Z
	return
	goto divideLow

;LED's Lookup tables
;Lookup table for PORTC (counter <= light8LED)
LED_Lookup
	addwf PCL, F
	retlw b'00000000' ;0 LED (PORTC pin's are off).
	retlw b'10000000' ;1 LED (RC7 ON).
	retlw b'11000000' ;2 LED (RC7:RC6 ON).
	retlw b'11100000' ;3 LED (RC7:RC5 ON).
	retlw b'11110000' ;4 LED (RC7:RC4 ON).
	retlw b'11111000' ;5 LED (RC7:RC3 ON).
	retlw b'11111100' ;6 LED (RC7:RC2 ON).
	retlw b'11111110' ;7 LED (RC7:RC1 ON).
	retlw b'11111111' ;8 LED (RC7:RC0 ON).
;Lookup table for PORTD (counter > light8LED)
LED_Lookup_last2
	addwf PCL, F
	retlw b'00000010' ;9 LED (RD0 ON)
	retlw b'00000010' ;9 LED (RD0 ON)
	retlw b'00000011' ;10 LED (RD1:RD0 ON)

	END
