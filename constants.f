
\********************************** CONSTANTS **********************************\
\*                                                                             *\
\* This file contains the preliminary definitions of every constant that       *\
\* will be needed in the project.                                              *\
\*                                                                             *\
\* As a side note, a naming convention has been used for constants that have   *\
\* multi-word names:                                                           *\
\*     - constants that refer to memory registers are separated by             *\
\*       underscores (e.g. BASE_ADDRESS);                                      *\
\*     - constants that refer to specific fields of a register                 *\
\*       follow the C dot-operator notation (e.g., I2CC.READ);                 *\
\*     - constants that contain purely numerical values are not                *\
\*       separated by any character (e.g. BYTEOFFSET).                         *\
\*                                                                             *\
\* It should also be specified that multi-word Forth words that are not        *\
\* utils, but project-specific will also be treated in their own way, that is, *\
\* by inserting a dash (-) when needed. Utils words will instead have no       *\
\* character at all, just as constants with purely numerical values.           *\
\*                                                                             *\
\*******************************************************************************\

HEX

\ ---------------------------------------- GPIO ---------------------------------------- \

\ ------- BASE ------- \

\ In the BCM2711 chip, the main peripherals registers of interests have 
\ addresses in the range 0xFE00_0000 - 0xFEFF_FFFF.
\ For this reason, we set our base address to be the first in this range,
\ and everything that follows will be referenced in respect to this number.
\
FE000000 CONSTANT BASE_ADDRESS

\ Setting GPIO controllers base address according to 0x200000 offset.
\
BASE_ADDRESS 200000 + CONSTANT PERI_BASE

\ ------- LASER ------- \

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

\ ------- BSC ------- \

\ The GPFSEL0 register controls pins 0-9, some of which (pins 2 and 3)
\ will be needed to work with the BSC controller of the chip.
\ This register has a 0x00 offset from the base, so just an alias suffices
\ to identify it.
\
PERI_BASE CONSTANT GPFSEL0


\ ---------------------------------------- TIMER ---------------------------------------- \

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
\ For reference, 1_000_000 -> 0x7A120, so, if DELTAT is set to this value,
\ assuming a 1 MHz core clock frequency, timing events may occur approximately
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
7A120 CONSTANT DELTAT


\ ---------------------------------------- BSC ---------------------------------------- \
\
\ The Broadcom Serial Control (BSC) controller of the BCM2711 chip has eight memory-mapped
\ registers of 32 bits each (BSCO0-BSC7). Keeping in mind that BSC2 and BSC7 are reserved 
\ for HDMI interfaces, any of the others can be used to handle the I2C communication with 
\ slave devices, with the Raspberry being assigned the role of master.
\

\ Out of the 6 available controllers, BSC1 is chosen, corresponding to an offset
\ of 0x804000 from the base address.
\
\ For this project, there will be the need to interface with 2 different sensors (the LDRs).
\ While defining a single controller for each of those could be an option, in order to 
\ allocate as few memory as possible, just one BSC controller is used. Such mode of operation
\ is encouraged by the inner architecture of the chosen slave device, which has multiple
\ input channels and offers the possibility to multiplex them between each read operation.
\
804000                    CONSTANT BSC1OFFSET
BASE_ADDRESS BSC1OFFSET + CONSTANT BSC1

\ The Control Register manages the main I2C operations of the controller.
\ Its offset is of 0x00 with respect to the specific controller base address.
\
BSC1 CONSTANT I2C_CONTROL_REG  
\
\ The following constants are useful references to the individual fields of the Control
\ Register. As an example, according to the reference, bit 7 of I2C_CONTROL_REG is
\ associated with the Start Transfer (ST) command, which is encoded in the I2CC.ST constant.
\
1           CONSTANT I2CC.READ
1 4 LSHIFT  CONSTANT I2CC.CLRF
1 7 LSHIFT  CONSTANT I2CC.ST
1 F LSHIFT  CONSTANT I2CC.EN

\ The Status Register monitors the I2C communication on the BSC controller.
\ Its fields are mainly read-only, with some exceptions that allow for a
\ one-shot clearing.
\
BSC1 4 +    CONSTANT I2C_STATUS_REG
\
\ Similarly to I2C_CONTROL_REG, individual fields are explicited for convenience.
\
1           CONSTANT I2CS.TA
1 1 LSHIFT  CONSTANT I2CS.DONE
1 8 LSHIFT  CONSTANT I2CS.ERR
1 9 LSHIFT  CONSTANT I2CS.CLKT

\ The Data Length register contains the number of bytes that need to be written/read 
\ on a single I2C transfer.
\
\ This register is updated by the controller during the transfer with the remaining 
\ bytes until completion; reading from it when idle returns the last value written to it.
\
BSC1 8 + CONSTANT I2C_DLEN_REG

\ A crucial component of an I2C communication is the mutual acknowledgement between 
\ talking devices. The Slave Address register contains the 7-bit hardware address of 
\ the slave device that will be sent onto the bus at the start of every transfer.
\ Only after a successful acknowledgement from the slave, the actual data transfer can
\ occur.
\
BSC1 C + CONSTANT I2C_SLAVE_ADDR

\ The 16-byte FIFO of the BSC controller cannot be accessed directly, rather, it is through 
\ the I2C_DATA_FIFO register that data is written to and read from it: read cycles to this
\ address place data in the FIFO, ready to transmit on the BSC bus. Read cycles access data 
\ received from the bus.
\
BSC1 10 + CONSTANT I2C_DATA_FIFO


\ ---------------------------------------- ADC ---------------------------------------- \

\ The default slave addres of the ADS1115 Analog-to-Digital (ADC) converter is 0x48. 
\ This is the address that the device responds to when its ADDR pin is connected to the main GND.
\
\ Similarly, we know that the Conversion and Configuration registers of the device are
\ accessed by writing, respectively 0b00 and b01 to the Address Pointer Register of the device.
\
48 CONSTANT ADS1115.SLAVE_ADDR
00 CONSTANT ADS1115.CONVR_REG
01 CONSTANT ADS1115.CONF_REG


\ ------- OTHERS ------- \

\ Constant used to extract single bytes from longer words.
FF CONSTANT BYTEMASK