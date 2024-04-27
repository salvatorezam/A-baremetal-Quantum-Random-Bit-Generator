
\*********************************** TIMER ************************************\
\*                                                                            *\
\* The BCM2711 chip is endowed with an internal System Timer that can be      *\
\* accessed with the appropriate registers.                                   *\
\*                                                                            *\
\* From the reference: the System Timer peripheral provides four 32-bit timer *\
\* channels and a single 64-bit free running counter. Each channel has an     *\          
\* output compare register, which is compared against the 32 least            *\
\* significant bits of the free running counter values. When the two values   *\
\* match, the system timer peripheral generates a signal to indicate a match  *\
\* for the appropriate channel. The match signal is then fed into the         *\
\* interrupt controller. The interrupt service routine then reads the output  *\
\* compare register and adds the appropriate offset for the next timer tick.  *\
\*                                                                            *\
\* The free running counter is driven by the timer clock and stopped whenever *\
\* the processor is stopped in debug mode.                                    *\
\*                                                                            *\
\******************************************************************************\

HEX

\ ------------------------------------------ CONSTANTS ------------------------------------------ \
\
\ This section is used to define utility constants referencing the addresses of the registers that 
\ will be used for interfacing the BCM2711 SSystem Timer.
\

\ From the reference, the physical base address for system timers has
\ an offset of 0x3000 with the main peripheral base.
\
BASE_ADDRESS 3000 +  CONSTANT SYSTEM_TIMER_BASE

\ The System Timer Control/Status register is used to record and clear timer
\ comparator matches. The system timer match bits are routed to the
\ interrupt controller where htey can generate an interrupt.
\
\ The match bits are 4 in total on W1C mode, with bits 31:4 of the register
\ being reserved. Of the available fields, there will be the need of accessing
\ just one of them, which is chosen to be M0, the System Timer Match 0 that
\ is read on bit 0.
\
SYSTEM_TIMER_BASE     CONSTANT CS
0                     CONSTANT CS.M0

\ System Timer Counter least significant 32 bits. The register is read-only
\
SYSTEM_TIMER_BASE 4 + CONSTANT CLO

\ System Timer Counter most significant 32 bits. The register is read-only
\
SYSTEM_TIMER_BASE 8 + CONSTANT CHI

\ System Timer Compare. This register holds the compare value for the zeroth
\ channel of the controller. Whenever the lower 32 bits of the free-running
\ counter mathces one of the compare values, the corresponding bit in the system
\ timer control/status register is set.
\
SYSTEM_TIMER_BASE C + CONSTANT C0

\ This is the desired counter displacement that we want to wait reaching in
\ order to time other main operation.
\
\ For reference, 1_000_000 -> 0xF4240, so, if DELTAT is set to this value,
\ assuming a 1 MHz counter frequency, timing events may occur approximately
\ every second. 
\
\ It is worth to focus on the word "approximately", in the sense that
\ with this raw timing management, events are not always displaced by exactly
\ the specified duration, since, while the System Timer's free-running
\ counter progresses with a fixed pace, checking the Match Status field is
\ something that itself consumes clock cycles, just as every other intermediate
\ action. Also, the core clock speed may also vary according to the configuration
\ and current load on the processor.
\
\ In our project instance, this is not an issue whatsoever, since the entire system
\ is still paced by the Analog-to-Digital Converter, and the timer serves the whole
\ purpose of avoiding to check the conversion register when it is known that a new 
\ conversion has not yet taken place. 
\
\ For this reason, an optimal mode of operation may consist in regulating the timer
\ according to the 0x48B constant, which is the number obtained after rounding the 
\ division of the 1 MHz free-running counter frequency with the configured maximum
\ sample-per-second rate of the ADC, equal to 860 SPS.
\
\ Here, however, for both demonstration and testing purposes, the time delay is
\ kept high at 0x7A120, which, although not the fastest possible, allows for a better
\ visualization of the inner working of out programmed controller.
\
7A120 CONSTANT DELTAT


\ ------------------------------------------ TIMING ------------------------------------------ \

\ Resetting the timer means storing in the chosen Compare Register (C0)
\ the compare value given by the current counter displaced by the offset.
\
: RESET-TIMER \ ( -- )
    CLO @ DELTAT + C0 !
;

\ Poll of the Status of the System Timer Match 0.
\
: ?TIMERMATCH \ ( -- flag )
    CS @ 1 AND 1 = 
;

\ Once a compare match is detected, the status is cleared in expectation of the
\ next event.
\
: CLEAR-MATCH \ ( -- )
    1 CS !
;

\ The actions to undertake when a compare match is detected.
\
\ As a first action after a match, the timer is reset to the new value,
\ then, the Match field of the Status registre is also cleared, and finally
\ the actions to be timed are executed (in this case, that's just a print of 
\ the stack).
\
: MATCH-ACTIONS \ ( -- )
    RESET-TIMER
    CLEAR-MATCH
    .S
    
;

\ Main (infinite) loop timed by the BCM2711 System Timer.
\
: TIMER \ ( -- )
    RESET-TIMER
    BEGIN
    ?TIMERMATCH IF MATCH-ACTIONS THEN
    AGAIN
;
