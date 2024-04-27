
\************************************* UTILS *************************************\
\*                                                                               *\
\* The following definitions serve the purpose of aiding the manipulation of     *\
\* both the Forth stack and the BCM2711 registers.                               *\
\*                                                                               *\                                 *\
\* The motivation behind the usage of each of those words is explained prior     *\
\* to each of them.                                                              *\
\*                                                                               *\
\*********************************************************************************\

\ ------------------------------------ REGISTER MANIPULATION ------------------------------------ \
\
\ Useful words for editing the contents of the main registers.
\

\ This word takes as input a numerical value (of 32 bits maximum) and uses it
\ to edit the contents of the register at the provided addr. The input number 
\ specifies the target's bits that need to be set to 1, maintaining the value 
\ of the others. This is a crucial aspect in one such scenario, where most of 
\ the registers possess reserved fields, which may not be altered.
\
\ The parameter ordering (stack: s_base val addr) is chosen to maintain the Forth 
\ convention of words that perform a store operation (!).
\
: SETBITS! \ ( val addr -- )
    TUCK @ OR SWAP !
;

\ The action of this word is similar to that of the previous one, but it is used to 
\ clear bits (i.e., set them to 0) instead.
\
: CLEARBITS! \ ( val addr -- )
    SWAP INVERT OVER @ AND SWAP !
;

\ For some register editing instances, SETBITS! and CLEARBITS! are not enough to achieve 
\ the desired results. This is because those registers in question need to receive an 
\ entire numerical value while at the same time leaving some reserved bits untouched.
\
\ To ensure the protection of reserved bits, we take advantage of a mask, which allows 
\ only the specified field to be modified. As an example, applying a mask of 0xFFFF0000
\ in conjunction with this word means editing only the 2 least significant bytes of the 
\ register's content, keeping the most singificant ones as they are read at the beginning.
\
: SET-MASKED-BITS! \ ( val addr mask -- )
    OVER @ AND 2 PICK OR SWAP ! DROP
;


\ ------------------------------------------ TIMER ------------------------------------------ \
\
\ Words for testing and implementing the logic behind the BCM2711 System Timer.
\

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