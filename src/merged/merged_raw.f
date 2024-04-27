
HEX

\ Constants
FE000000 CONSTANT BASE_ADDRESS
BASE_ADDRESS 200000 + CONSTANT PERI_BASE

PERI_BASE 4 + CONSTANT GPFSEL1
FFFFFFC7 CONSTANT FSEL11_MASK
8 CONSTANT FSEL11.OUT
PERI_BASE 1C + CONSTANT GPSET0
PERI_BASE 28 + CONSTANT GPCLR0

BASE_ADDRESS 3000 +  CONSTANT SYSTEM_TIMER_BASE
SYSTEM_TIMER_BASE     CONSTANT CS
0                     CONSTANT CS.M0
SYSTEM_TIMER_BASE 4 + CONSTANT CLO
SYSTEM_TIMER_BASE 8 + CONSTANT CHI
SYSTEM_TIMER_BASE C + CONSTANT C0
7A120 CONSTANT DELTAT

PERI_BASE CONSTANT GPFSEL0
804000                    CONSTANT BSC1OFFSET
BASE_ADDRESS BSC1OFFSET + CONSTANT BSC1
BSC1 CONSTANT I2C_CONTROL_REG
1           CONSTANT I2CC.READ
1 4 LSHIFT  CONSTANT I2CC.CLRF
1 7 LSHIFT  CONSTANT I2CC.ST
1 F LSHIFT  CONSTANT I2CC.EN
BSC1 4 +    CONSTANT I2C_STATUS_REG
1           CONSTANT I2CS.TA
1 1 LSHIFT  CONSTANT I2CS.DONE
1 8 LSHIFT  CONSTANT I2CS.ERR
1 9 LSHIFT  CONSTANT I2CS.CLKT
BSC1 8 + CONSTANT I2C_DLEN_REG
BSC1 C + CONSTANT I2C_SLAVE_ADDR
BSC1 10 + CONSTANT I2C_DATA_FIFO
48 CONSTANT ADS1115.SLAVE_ADDR
00 CONSTANT ADS1115.CONVR_REG
01 CONSTANT ADS1115.CONF_REG
FF CONSTANT BYTEMASK

\ Utils
: SETBITS! TUCK @ OR SWAP ! ;
: CLEARBITS! SWAP INVERT OVER @ AND SWAP ! ;
: SET-MASKED-BITS! OVER @ AND 2 PICK OR SWAP ! DROP ;

\ Laser
: GPIO-LD-SETUP FSEL11.OUT GPFSEL1 FSEL11_MASK  SET-MASKED-BITS! ;
: LASER 800 GPSET0 GPCLR0 ;
: ON    DROP ! ;
: OFF   NIP ! ;

\ Timer
: RESET-TIMER CLO @ DELTAT + C0 ! ;
: ?TIMERMATCH  CS @ 1 AND 1 = ;
: CLEAR-MATCH 1 CS ! ;

\ I2C
: GPIO-I2C-SETUP 900 GPFSEL0  SETBITS! ;
: ENABLE-I2C  I2CC.EN I2C_CONTROL_REG  SETBITS! ;
: DISABLE-I2C I2CC.EN I2C_CONTROL_REG  CLEARBITS! ;
: SET-SLAVE-ADDR ADS1115.SLAVE_ADDR I2C_SLAVE_ADDR  SETBITS! ;
: SET-DLEN I2C_DLEN_REG FFFF0000  SET-MASKED-BITS! ;
: CLEAR-DONE I2CS.DONE I2C_STATUS_REG  SETBITS! ;
: CLEAR-STATUS I2CS.DONE I2CS.ERR I2CS.CLKT OR OR I2C_STATUS_REG  SETBITS! ;
: CLEAR-FIFO I2CC.CLRF I2C_CONTROL_REG  SETBITS! ;
: RESET-I2C CLEAR-STATUS CLEAR-FIFO ;
: WAIT-FOR-TRANSFER BEGIN I2C_STATUS_REG @ I2CS.TA AND 0= UNTIL CLEAR-DONE ;
: INIT-I2C ENABLE-I2C RESET-I2C SET-SLAVE-ADDR ;
: BYTE-OFFSET 8 * ;
: SHIFT-MASK SWAP LSHIFT ;
: APPLY-MASK DUP BYTE-OFFSET DUP BYTEMASK SHIFT-MASK 3 PICK AND ;
: GET-BYTE SWAP RSHIFT ;
: PUSH-BYTE-TO-FIFO I2C_DATA_FIFO ! ;
: PUSH-BYTES-TO-FIFO 1- BEGIN DUP 0>= WHILE APPLY-MASK GET-BYTE PUSH-BYTE-TO-FIFO 1- REPEAT 2DROP ;
: POP-BYTE-FROM-FIFO I2C_DATA_FIFO @ FF AND ;
: UPDATE-BUFFER OVER BYTE-OFFSET LSHIFT 2 PICK @ OR 2 PICK ! ;
: FIFO>BUFFER 1- BEGIN DUP 0>= WHILE POP-BYTE-FROM-FIFO UPDATE-BUFFER 1- REPEAT 2DROP ;
: SETUP-I2C-WRITE TUCK PUSH-BYTES-TO-FIFO SET-DLEN ;
: START-WRITE I2CC.READ I2C_CONTROL_REG  CLEARBITS! I2CC.ST I2C_CONTROL_REG  SETBITS! ;
: I2CWRITE> SETUP-I2C-WRITE START-WRITE WAIT-FOR-TRANSFER ;
: START-READ I2CC.READ I2CC.ST OR I2C_CONTROL_REG  SETBITS! ;
: REPEATED-START-READ DUP SET-DLEN START-READ WAIT-FOR-TRANSFER ;
: >I2CREAD  SWAP 1 I2CWRITE> REPEATED-START-READ FIFO>BUFFER ;

\ ADC
: WRITE-ADC-CONFIG ADS1115.CONF_REG 2 BYTE-OFFSET LSHIFT + 3 I2CWRITE> ;
: READ-ADC-CONFIG ADS1115.CONF_REG 2 >I2CREAD ;
: READ-ADC-CONVR ADS1115.CONVR_REG 2 >I2CREAD ;
: CONTINUOUS-READ BEGIN RESET-I2C DUP READ-ADC-CONVR DUP @ U. 0 OVER ! AGAIN ;
: CONTINUOUS-SINGLE-SHOT BEGIN RESET-I2C C3E3 WRITE-ADC-CONFIG RESET-I2C DUP READ-ADC-CONVR DUP @ U. 0 OVER ! AGAIN ;

\ QRBG
: WAIT-FOR-NEW-SAMPLE RESET-TIMER BEGIN ?TIMERMATCH UNTIL CLEAR-MATCH ;
: READ-AIN0 RESET-I2C C3E3 WRITE-ADC-CONFIG WAIT-FOR-NEW-SAMPLE READ-ADC-CONVR ;
: READ-AIN1 RESET-I2C D3E3 WRITE-ADC-CONFIG WAIT-FOR-NEW-SAMPLE READ-ADC-CONVR ;
: READ-AIN0-1 READ-AIN0 READ-AIN1 ;
: PULSE-MEASURE LASER ON READ-AIN0-1 LASER OFF ;
: GET-BIT > IF 1 ELSE 0 THEN ;
: START-BITSTREAM BEGIN 2DUP PULSE-MEASURE DUP @ 2 PICK @ GET-BIT . 0 OVER ! 0 2 PICK ! AGAIN ;
: CONFIG-GPIOS GPIO-LD-SETUP GPIO-I2C-SETUP ;
: STARTUP CONFIG-GPIOS INIT-I2C ;


STARTUP
VARIABLE BUFFER 0 BUFFER !
BUFFER START-BITSTREAM