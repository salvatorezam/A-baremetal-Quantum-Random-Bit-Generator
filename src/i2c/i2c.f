
\************************************* I2C *************************************\
\*                                                                             *\
\* Here, the inner workings of the I2C bus are dissected and words are         *\
\* defined to implement a communication through the Broadcom Serial Control    *\
\* (BCS) controller of the BCM2711 chip.                                       *\
\*                                                                             *\
\* The code for interfacing the BSC is generalized and adaptable to any kind   *\
\* of read/write communication to any slave.                                   *\
\*                                                                             *\
\* The "adc.f" file showcases the practical implementation of the words        *\
\* defined here, contextualizing them for writing/reading to/from the ADS1115  *\
\* Analog-to-Digital converter module.                                         *\
\*                                                                             *\
\* For reference, the ADC slave interfaces with the RPi master according       *\
\* to the following layout:                                                    *\
\* ______        ____________                                                  *\
\*   3V3|-------|VDD    ADDR|--- GND                                           *\
\*   GND|-------|GND      A0|---                                               *\
\*   SDA|-------|SDA      A1|---                                               *\
\*   SCL|-------|SCL      A2|---                                               *\
\*      |       |         A3|---                                               *\
\* R. Pi|       |  ADS1115  |                                                  *\   
\* _____|       |___________|                                                  *\
\*                                                                             *\
\* with A0-A3 being the input lines connected to the analog quantity that      *\
\* needs to be converted and serialized (the LDR voltage in our case).         *\
\*                                                                             *\
\*******************************************************************************\

HEX

\ ------------------------------------------ CONSTANTS ------------------------------------------ \
\
\ This section is used to define utility constants referencing the addresses of the registers that 
\ will be used for interfacing the BCM2711 Serial Controller, as well as the ADS1115 slave device.
\

\ ------- GPIO ------- \

\ In the BCM2711 chip, the main peripherals registers of interests have 
\ addresses in the range 0xFE00_0000 - 0xFEFF_FFFF.
\
\ For this reason, the base address is set to be the first in this range,
\ and everything that follows will be referenced in respect to this number.
\
FE000000 CONSTANT BASE_ADDRESS

\ Setting GPIO controllers base address according to 0x200000 offset.
\
BASE_ADDRESS 200000 + CONSTANT PERI_BASE

\ The GPFSEL0 register controls pins 0-9, some of which (pins 2 and 3)
\ will be needed to work with the BSC controller of the chip.
\ This register has a 0x00 offset from the base, so just an alias suffices
\ to identify it.
\
PERI_BASE CONSTANT GPFSEL0

\ ------- BSC ------- \
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


\ ------- ADC ------- \

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


\ ------------------------------------------ UTILS ------------------------------------------ \

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


\ ------------------------------------------ I2C SETUP ------------------------------------------ \

\ The SDA and SCL lines of the I2C protocol can be found, respectively, on pins
\ 2 and 3 of the Raspberry Pi 4B GPIOs.
\
\ We will therefore refer to the GPFSEL0 register, and particularly to bits:
\   - 8:6 -> GPIO Pin 2
\   - 11:9 -> GPIO Pin 3
\ setting 001 to both of them, which corresponds to Alternate Function 0 (ALT0), 
\ being that it is in ALT0 that SDA and SCL are configured.
\
\ Therefore, the bits that need to be set are encoded by the number
\  0b 0000 0000 0000 0000 0000 1001 0000 0000 -> 0x900
\
: GPIO-I2C-SETUP \ ( -- )
    900 GPFSEL0  SETBITS!
;

\ Another preparatory step to work with the BSC controller requires enabling it.
\ This is done by simply setting to 1 the I2CC.EN (I2C Enable) field of the I2C_CONTROL_REG
\ register. Setting the same field as 0 disables the controller.
\
: ENABLE-I2C \ ( -- )
    I2CC.EN I2C_CONTROL_REG  SETBITS!
;

: DISABLE-I2C \ ( -- )
    I2CC.EN I2C_CONTROL_REG  CLEARBITS!
;

\ For this implementation, the regular I2C 7-bit addressing is used for the referencing the slave.
\ In addition, only one slave is used, meaning that its address can be directly hard-coded into the 
\ main setup and instantiated just once.
\
: SET-SLAVE-ADDR \ ( -- )
    ADS1115.SLAVE_ADDR I2C_SLAVE_ADDR  SETBITS!
;

\ In this case the word is defined upon SET-MASKED-BITS! since there is the need to update a numerical 
\ value onto the DATA field of I2C_DLEN_REG, while preserving the 31:16 bits, which are reserved. 
\ To achieve that, a 0xFFFF0000 mask is employed.
\
: SET-DLEN \ ( dlen -- )
    I2C_DLEN_REG FFFF0000  SET-MASKED-BITS!
;

\ The fields of the I2C_STATUS_REG are, as one would expect, mainly read-only, with the exception
\ of some that are in W1C mode, that is, they can be cleared by writing 1 to them.
\ Specifically, the clearable single-bit fields are DONE, ERR, and CLKT.
\
\ The DONE field gets detached from the other resets as it will be useful to clear it individually
\ in the future.
\
: CLEAR-DONE \ ( -- )
    I2CS.DONE I2C_STATUS_REG  SETBITS!
;
\
: CLEAR-STATUS \ ( -- )
    I2CS.DONE I2CS.ERR I2CS.CLKT OR OR I2C_STATUS_REG  SETBITS!
;

\ Similarly, to clear the I2C FIFO, it is sufficient to set the I2CC.CLRF to 1, since it
\ is a W1C field as well.
\
: CLEAR-FIFO \ ( -- )
    I2CC.CLRF I2C_CONTROL_REG  SETBITS!
;

\ Utility word to prepare the BSC for a new transfer, whether it is the first one after 
\ initialization, or one in the middle of a communication.
\
: RESET-I2C \ ( -- )
    CLEAR-STATUS
    CLEAR-FIFO
;

\ Wait for transfer completion.
\
\ This word monitors the Transfer Active field of I2C_STATUS_REG and makes sure
\ that no other register manipulation is performed by the user's commands while 
\ a transfer is underway.
\ 
: WAIT-FOR-TRANSFER \ ( -- )
    BEGIN I2C_STATUS_REG @ I2CS.TA AND 0= UNTIL
    CLEAR-DONE
;

\ First initialization of the GPIO and BSC registers for I2C communications.
\
: INIT-I2C \ ( -- )
    ENABLE-I2C
    RESET-I2C
    SET-SLAVE-ADDR
;


\ ------------------------------------------ I2C FIFO UTILS ------------------------------------------ \
\
\ As already mentioned, the BSC FIFO is internally managed by the controller, so no direct access 
\ can be made to it. One one hand, this spares the programmer the burden of handling incoming
\ or outgoing data, but on the other hand, a complete understanding of how this queue is 
\ actually managed is imperative for an optimal usage.
\ 
\ E.g., one consideration to take into account refers to the fact that the I2C_DATA_FIFO is such that
\ bits 31:8 are reserved, while bits 7:0 constitute the actual DATA field. 
\ This means that data must be handled in single bytes, as 1 byte is the length of DATA, and extra
\ care must be taken to ensure that reserved areas are not affected by regular communication.
\ 
\ In addition, it is also useful to know that when the actual FIFO is empty, reading from the DATA 
\ field returns the last value that was written to it, whether it was from a master or a slave.
\

\ There will be the need, in order to work byte-wise, to move around the content of registers one 
\ byte at a time, which arises the need of computing the exact amount of bits to include within
\ shift operations.
\
: BYTE-OFFSET \ ( dlen -- offset )
    8 *
;

\ ------- I2C WRITE SUBSECTION ------- \

\ This word shifts the single-byte mask towards the byte of interest labeled by the input offset.
\
: SHIFT-MASK \ ( mask offset -- shifted_mask )
    SWAP LSHIFT
;

\ The following word encapsulates the entire masking procedure:
\   - first the offset is computed according to the running dlen counter;
\   - then, a mask is built upon such offset;
\   - finally the mask is applied to the starting number with an AND operation.
\
: APPLY-MASK \ ( number dlen -- offset masked_number );
    DUP BYTE-OFFSET
    DUP BYTEMASK
    SHIFT-MASK
    3 PICK
    AND
;

\ Since we are only interested in the masked byte as a standalone 8-bit number,
\ we shift it back with the same offset into the least significant positions, so 
\ that the output is an 8-bit value that can be directly fed to the DATA field 
\ of I2C_DATA_FIFO.
\
: GET-BYTE \ ( offset masked_number -- extracted_byte )
    SWAP RSHIFT
;

\ Word for loading to FIFO individual bytes that need to be written to the slave from the master.
\ I2C_DATA_FIFO has an 8-bit-long DATA register, while bits 31:8 are reserved.
\
\ In this particular instance the word SET-MASKED-BITS! cannot be used, nor any other technique 
\ that involves first reading the register, since reading from it would trigger a byte from the 
\ FIFO to be dumped (ironically enough, it is somewhat alike how, in quantum mechanics, measuring
\ a combined state destroys the superposition).
\
\ References do not address this issue, and from experimental trials it is expected that some sort 
\ of internal control is indeed performed to set only the DATA field.
\
: PUSH-BYTE-TO-FIFO \ ( byte -- )
    I2C_DATA_FIFO ! 
;

\ Main word for loading an arbitrary amount of data (16 bytes max) onto the BSC FIFO,
\ from most to least significant bytes.
\
\ It is used when the master (raspberry) needs to write to the slave (ADC). Since the 
\ primary function of the ADS1115 ADC is to read analog inputs and convert it in digital
\ form, the only writes that can be performed to it are those that (a) set which register
\ to read from and (b) configure the operational modes of the device.
\
\ In (a), just one byte needs to be written, containing the address of the ADC register 
\ that needs to be read; as per (b), a number composed of 3 bytes in total will be 
\ pushed to the FIFO:
\   - 1 byte containing the address of the register the controller is writing to;
\   - 2 bytes (most significant first) representing the updated configuration, 
\       which in the ADS1115 is always 16-bit long, regardless of the register.
\
\ The word takes therefore as input whichever number from either case (a) or (b), and
\ the length in number of bytes that compose it, respectively 1 and 3 for those instances.
\
: PUSH-BYTES-TO-FIFO \ ( number dlen -- )
    1-
    BEGIN
        DUP 0>=
        WHILE
            APPLY-MASK
            GET-BYTE PUSH-BYTE-TO-FIFO
            1-
    REPEAT
    2DROP
;

\ ------- I2C READ SUBSECTION ------- \

\ Similarly to the write case, we also need to define the symmetric operation for the read action.
\ 
\ Since we are once again interested in individual bytes, that is, the DATA field of I2C_DATA_FIFO,
\ corresponding to bits 7:0, reading the register is followed by a mask on the least significant 8 bits.
\ Everything that is read from reserved bits is discarded.
\
: POP-BYTE-FROM-FIFO \ ( -- fifo_byte )
    I2C_DATA_FIFO @ FF AND 
;

\ In order to store permanently the contents read from the slave, a buffer variable is used.
\
\ This buffer gets filled in the same way the FIFO is, from the most to the least significant 
\ byte. Filling occurs with the same shifting philosophy of the write mask operation, with the
\ difference that here, data flows from the FIFO, instead that into it.
\ 
: UPDATE-BUFFER \ ( buffer dlen byte -- buffer dlen )
    OVER BYTE-OFFSET LSHIFT 2 PICK @ OR 2 PICK !
;

\ Main word for storing an arbitrary amount of data (16 bytes max) from the BSC FIFO into a
\ buffer variable, again, from most to least significant bytes.
\ 
\ This word itself is the reversed-action version of the PUSH_BYTES_TO_FIFO used for writing
\ to the slave.
\
: FIFO>BUFFER \ ( buffer dlen -- )
    1-
    BEGIN 
        DUP 0>=
        WHILE
            POP-BYTE-FROM-FIFO
            UPDATE-BUFFER
            1-
    REPEAT
    2DROP
;


\ ------------------------------------------ I2C WRITE ------------------------------------------ \
\
\ According to the ADS1115 reference, write operations to the device on the I2C bus are composed
\ of 3 main stages:
\    1. the master writes to the bus the slave address of the device and the slave acknowledges it;
\    2. the master writes a byte to the bus, of which the least significant two bits identify 
\       the ADS1115 register that are being written to;
\    3. after ACK, the master writes onto the bus what to write into the register; this is done
\       one byte at a time (removing it from the loaded FIFO), and starting with the most
\       significant one.
\ 
\ One exception is made when the write is the preliminary opeation for a read: in that case,
\ just one byte is set to be sent, and step 3. does not occur.
\
\ The BSC controller autonomously takes care of sending the slave address to the bus, as well
\ as acknowledging ACK bits during each byte of communication. Every other step will require 
\ manual configuration.

\ The setup of a write operation is performed by filling the FIFO with the required bytes,
\ again, most significant first, and then telling the BSC controller how many of them 
\ (virtually, all) to write to the bus.
\
: SETUP-I2C-WRITE \ ( data dlen -- )
    TUCK PUSH-BYTES-TO-FIFO
    SET-DLEN
;

\ A write operation is initiated by first setting to 0 the I2CC.READ field of I2C_CONTROL_REG,
\ and then writing to the ST field of the same register to initiate a transfer.
\ 
: START-WRITE \ ( -- )
    I2CC.READ I2C_CONTROL_REG  CLEARBITS!
    I2CC.ST I2C_CONTROL_REG  SETBITS!
;

\ Main word for writing on the I2C bus.
\
\ The BSC is first prepped, then a write transfer is initiated and then the controller monitors
\ the Status Register to detect when the transfer has been completed.
\
\ The word takes as input the data to write to the slave (data) and its length in bytes (dlen).
\ During a regular write operation (not the write that occurs before a read), this data field must
\ incorporate, as its most significant byte, the content of the Address Pointer Register of 
\ the slave device to tell it which register to write to.
\
: I2CWRITE> \ ( data dlen -- )
    SETUP-I2C-WRITE
    START-WRITE
    WAIT-FOR-TRANSFER
;


\ ------------------------------------------ I2C READ ------------------------------------------ \
\
\ A read operation is slightly more complex, as it involves a preliminary write on the I2C bus 
\ to identify the register that needs to be read, before actually reading it contents.
\ The read procedure can be summarized as:
\    1. the master writes to the bus the slave address of the device;
\    2. as a second byte, the master sends the address of the device's register that
\       needs to be read;
\    3. the master keeps the communication open and triggers a Repeated Start, sending a byte
\       composed of once again the 7-bit slave's address, along with a high I2CC.READ bit;
\    4. the slave fills the FIFO with the data from its chosen register, starting from the
\       most significant byte until completion.
\
\ For each of those byte-wise steps, the BSC handles ACK bits and Start and Repeated Start conditions
\ leaving to the programmer the task of managing just the content bytes. In addition, for steps 1. and 2. 
\ it is possible to just re-use the words defined for write operations.

\ Initiating a read is once again done by setting as 1 the Start Transfer bit of I2C_CONTROL_REG
\ with the I2CC.READ field also set high.
\
: START-READ \ ( -- )
    I2CC.READ I2CC.ST OR I2C_CONTROL_REG  SETBITS!
;

\ The repeated start procedure does not need additional config except for updating I2C_DLEN_REG 
\ with the number of bytes that are to be read.
\
\ The BSC controller handles the Repeated Start condition once I2CC.READ and I2CC.ST are set to 1,
\ that is, as soon as the START-READ word is executed.
\
: REPEATED-START-READ \ ( dlen -- )
    DUP SET-DLEN 
    START-READ
    WAIT-FOR-TRANSFER
;

\ Main word for reading from the I2C bus.
\
\ First, a write operation is triggered to select the register (reg) to read from. This write operation
\ is trivially 1-byte long. Then, a Repeated Start is triggered to read the actual data of interest, 
\ of length dlen, which is put into the FIFO. Finally, the contents of the FIFO are dumped onto the buffer 
\ variable passed as a parameter to the word.
\
: >I2CREAD \ ( buffer reg dlen -- )
    SWAP 1 I2CWRITE>
    REPEATED-START-READ
    FIFO>BUFFER
;
