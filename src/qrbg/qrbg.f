
\************************************* QRNG *************************************\
\*                                                                              *\
\* This is the main code section of the project, the one that merges all of the *\
\* previous subsections to build up the words that perform the Quantum Random   *\
\* Number Generation (QRNG).                                                    *\
\*                                                                              *\
\* A single bit is generated according to the following procedure:              *\
\*  1. the Laser Diode is pointed at the Beam Splitter and activated;           *\
\*  2. the ray is split into two orthogonal directions, each of which has a     *\
\*      LDR set on;                                                             *\
\*  3. the LDRs are connected through a voltage divider configuration to        *\
\*     analog inputs A0 and A1 of the ADS1115 ADC module.                       *\
\*  4. the ADC is configured in single-shot power-down mode to perform          *\
\*     an analog-to-digital value conversion of the voltage between the inputs  *\
\*  5. is such voltage is positive, it means that more photons are hitting      *\
\*     the first LDR than the other, and a 1 is generated; vice-versa, when     *\
\*     reading a negative voltage a 0 is set as final output.                   *\
\*                                                                              *\
\* To generate a new bit, the laser is turned off and then back on to repeat    *\
\* the mentioned steps. Chaining more laser pulses indeed implements a          *\
\* stream bit generation.                                                       *\
\*                                                                              *\
\********************************************************************************\

HEX

\ ------------------------------------------ TIMING ------------------------------------------ \

\ As mentioned in the TIMER section, in order to avoid wasting too many 
\ resources while the controller awaits for the ADC slave to perform a 
\ conversion (since we know that its sample rate is much lower that the
\ master's core clock), we implement a wait operation based on the 
\ BCM2711 System Timer.
\
\ The following word has the sole purpose of polling the Match Status bit
\ of the configured CS Timer Register to check if the desired time interval
\ has elapsed.
\
\ In practice, the single-shot sample rate is lowered (by increasing the timing 
\ delay) to a value that is substantially below the entire system capabilities,
\ with the idea of allowing the human eye to visualize the different stages of
\ bit generation.
\
: WAIT-FOR-NEW-SAMPLE \ ( -- )
    RESET-TIMER
    BEGIN ?TIMERMATCH UNTIL
    CLEAR-MATCH
;


\ --------------------------------------- BIT GENERATION --------------------------------------- \

\ We saw that the ADS1115 has 4 possible analog inputs (A0 to A3), and also offers
\ the possibility, through a Programmable Gate Array (PGA) to multiplex between them
\ by writing on bits 14:12 (MUX[2:0] field) of its Configuration Register.
\
\ Other than the tradional expected multiplexing choices that set the AIN_N to GND with
\ AIN_P being one of the inputs, this device conveniently has the option of digitalizing
\ the analog input between two input channels.
\
\ We therefore choose to set to 0b000 the MUX[2:0] field, which corresponds to
\   AIN_P <- A0
\   AIN_n <- A1
\ resulting in the single-shot, maximum-sps configuration of 83E3.
\
\ After changing the configuration, especially ast startup, we still need to wait for a sample
\ to be performed, which is why we also introduce the WAIT-FOR-NEW-SAMPLE subroutine
\ before actually reading the ADC Conversion Register and storing its value in a buffer variable.
\
: READ-AIN0-1 \ ( buffer -- )
    RESET-I2C
    83E3 WRITE-ADC-CONFIG
    WAIT-FOR-NEW-SAMPLE
    READ-ADC-CONVR
;

\ Since we know that, in quantum mechanics, measuring an obervable quantity destroys the created
\ superposition of states causing a permanent collapse into one of them, it is not possible to
\ just leave the laser on and continuously read the LDRs values. For this reason, each read operation
\ is sandwiched between a laser pulse.
\
: PULSE-MEASURE \ ( buffer -- )
    LASER ON
    READ-AIN0-1
    LASER OFF
;

\ As mentioned in the introduction, the ultimate mechanism in determining whether a 1 or a 0
\ has been geenrated, is associated to the sign of the read voltage, symbolizing that one reference
\ LDR is across the preferential direction of the photons for that single laser pulse.
\
: GET-BIT \ ( read_val -- bit )
    0> IF 1 ELSE 0 THEN
;

\ Finally, in the case that a stream of bits is desired to be generated, looping through 
\ pulses is sufficient to achieve just that.
\
: START-BITSTREAM \ ( buffer -- )
    BEGIN
        DUP PULSE-MEASURE
        DUP @ GET-BIT .S
    AGAIN
;


\ ------------------------------------------ INITS ------------------------------------------ \

\ Words to init the system and prepare it for the pulses and bit generation.
\ 
: CONFIG-GPIOS \ ( -- )
    GPIO-LD-SETUP
    GPIO-I2C-SETUP
;

: STARTUP \ ( -- )
    CONFIG-GPIOS
    INIT-I2C
;


\ ------------------------------------------ USAGE ------------------------------------------ \
\
\ All that being defined, a sample usage for generating a single bit starting after boot up, 
\ is represented by the following simple commands.

\ Controller and slaves are initialized.
\
STARTUP

\ The buffer variable for storing the ADC conversion is instantiated.
\
VARIABLE BUFFER 0 BUFFER !

\ A Laser pulse is triggered and the difference in the LDRs voltages is dumped onto the buffer.
\ 
BUFFER PULSE-MEASURE

\ The sign of the conversion is used to determine which bit has been generated, displaying
\ it immediately afterwards.
\
BUFFER @ GET-BIT .S
