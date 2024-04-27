
\************************************* LASER **************************************\
\*                                                                                *\
\* Here, utils for accessing the Laser Diode are defined.                         *\
\*                                                                                *\
\* The LD is wired into the hardware layout so that its supply is controlled by   *\
\* GPIO Pin 11, as below:                                                         *\ 
\*                                                                                *\
\*                                                                                *\
\*  ______                                                                        *\
\*  GPIO11|---- |                                                                 *\
\*     GND|     _                                                                 *\
\*        |    | | 330 Ohms                                                       *\
\*        |    |_|                                                                *\
\*        |     |                                                                 *\
\*  R. Pi |     |                                                                 *\  
\*  ______|   __|__ LD                                                            *\    
\*            \   /  -->                                                          *\
\*           __\ /__ -->                                                          *\
\*              |                                                                 *\ 
\*              |                                                                 *\
\*              _ GND                                                             *\
\*                                                                                *\
\**********************************************************************************\

HEX

\ ---------------------------------------- CONSTANTS ---------------------------------------- \

\ To control the laser diode, GPIO Pin 11 is chosen, whose function is 
\ configured by the GPFSEL1 register.
\
\ Any other pin would have done the job, but 11 is the one that is most 
\ nicely accessible on the breadboard, according to the layout of the 
\ other components.
\
PERI_BASE 4 + CONSTANT GPFSEL1

\ According to the Peripherals reference, Pin 11 is associated
\ with bits 5:3 (FSEL11 field) of GPFSEL1. 
\
\ Within the 32-bit register, those bits are identified by the mask
\  0b 1111 1111 1111 1111 1111 1111 1100 0111 -> 0xFFFFFFC7
\
FFFFFFC7 CONSTANT FSEL11_MASK

\ In order to set Pin 11 as output, the FSEL11 field must take
\ value 0b001.
\
8 CONSTANT FSEL11.OUT

\ GPIO Pin 11 is such that its actual value is set and cleared by the
\ GPSET0 and GPCLR0 registers.
\
PERI_BASE 1C + CONSTANT GPSET0
PERI_BASE 28 + CONSTANT GPCLR0


\ ------------------------------------------ SETUP ------------------------------------------ \

\ Configuring GPIO pin 11 for controlling the Laser Diode.
\
\ In order to have this GPIO as an output, the field FSEL11
\ must take value 001 (FSEL11.OUT), which we configure by masking
\ the target bits (FSEL11_MASK) and then applying the desired config.
\
: GPIO-LD-SETUP \ ( -- )
    FSEL11.OUT GPFSEL1 FSEL11_MASK  SET-MASKED-BITS!
;


\ ------------------------------------------ LASER ------------------------------------------ \

\ Defining words for turning the laser on and off.
\
\ This is done by setting to 1 the 11th bit (for the 11th pin),
\ corresponding to the hex value of 0x800 to GPSET0 to activate
\ its corresponding function, and doing the same to GPCLR0 to 
\ deactivate it.
\   
: LASER 800 GPSET0 GPCLR0 ;
: ON    DROP ! ;
: OFF   NIP ! ;
