
\************************************* ADC **************************************\
\*                                                                              *\
\* This section contains the implementation of the I2C protocol for             *\
\* interfacing the Adafruit ADS1115 ADC Analog-to-Digital Converter (the slave) *\
\* through our Raspberry Pi 4B device (the master) through the RPi's BSC of its *\
\* BCM2711 SoC.                                                                 *\
\*                                                                              *\
\* At the end of the section, sample usages are showcased. Of course, before    *\
\* running those commands, the words contained in "i2c.f" should be imported    *\
\* first.                                                                       *\
\*                                                                              *\
\* For convenience, the hardware layout of the physical connections between     *\
\* is displayed below:                                                          *\
\* ______        ____________                                                   *\
\*   3V3|-------|VDD    ADDR|--- GND                                            *\
\*   GND|-------|GND      A0|---                                                *\
\*   SDA|-------|SDA      A1|---                                                *\
\*   SCL|-------|SCL      A2|---                                                *\
\*      |       |         A3|---                                                *\
\* R. Pi|       |  ADS1115  |                                                   *\   
\* _____|       |___________|                                                   *\
\*                                                                              *\
\*                                                                              *\
\* It should also be pointed out that, regarding the analog inputs (A0-A3),     *\
\* the corresponding pins on the ADS1115 are connected to a voltage divider     *\
\* configuration with the sensor (the LDR, in the context of this project)      *\
\* directly on ground and a "pull-up" resistor of 10 kOhms close to supply,     *\
\* as shown below:                                                              *\
\*                                                                              *\
\*               ___ VDD (3V3)                                                  *\                  
\*                |                                                             *\
\*                |                                                             *\
\*                _                                                             *\
\*               | | 10 kOhms                                                   *\
\*               |_|                                                            *\
\*                |                                                             *\
\*                |--- A0/A1/A2/A3                                              *\
\*                |                                                             *\
\*                _                                                             *\
\*            -->| | LDR                                                        *\
\*            -->|_|                                                            *\
\*                |                                                             *\
\*                |                                                             *\
\*                _ GND                                                         *\
\*                                                                              *\
\*                                                                              *\
\********************************************************************************\

HEX

\ ------------------------------------------ ADC CONFIGURATION ------------------------------------------ \
\
\ Below are some utility words that serve the purpose of directly accessing the Configuration Register of 
\ the slave with I2C commnication.
\ 

\ Writing onto the Configuration Register of the slave is a full write operation that involves 3 bytes
\ in total, the most significant one containing the address of the Configuration Register, which in
\ the ADS1115 is accessed via the 0x01 address, and the remaining 2 being the actual configuration that 
\ needs to be written.
\
\ Note: the ADS1115 resets on power-up, restoring all of the bits in the Configuration Register
\ to their default value. Therefore, every time the device is powered up, there is the need
\ to set back the desired configuration.
\
: WRITE-ADC-CONFIG \ ( config -- )
    ADS1115.CONF_REG 2 BYTE-OFFSET LSHIFT
    +
    3 I2CWRITE>
;

\ Reading the Configuration Register is also a complete read operation, with the 2-step approach 
\ of first writing the target register's address (ADS1115.CONF_REG) and then specifying how many
\ bytes to read from it, i.e., 2, as ADS1115.CONF_REG is 16 bits long.
\
\ The read configuration is then dumped onto the specified buffer.
\
: READ-ADC-CONFIG \ ( buffer -- )
    ADS1115.CONF_REG 2 >I2CREAD
;


\ --------------------------------------- READ CONVERSION REGISTER --------------------------------------- \
\
\ This is arguably the most important section of all this document, since it concerns the actual read
\ of the digital value converted from the analog input of the ADC.
\
\ All of the other words defined so far, from the utilities, to those for the actual write/read
\ operations, converge into the following, simple expressions.
\

\ The ADS1115 is wired so that, as soon as a conversion is triggered (whether in single-shot or
\ continuous mode), the digitalized input is stored in the 16-bit Conversion Register, which gets
\ overwritten as soon as a new conversion is performed.
\
\ Therefore, reading the analog input translates to reading the Conversion Register of the ADC 
\ through the I2C protocol.
\
: READ-ADC-CONVR \ ( buffer -- )
    ADS1115.CONVR_REG 2 >I2CREAD
;

\ This word serves the purpose of continuous monitoring of the analog input (mainly for tests).
\
\ It works by continuously polling, through the I2C bus, the Conversion Register of the ADC,
\ displaying the value that gets dumped to the specified buffer.
\
\ Before launching this word it is suggested to configure the ADS1115 in such a way that
\ bit 8 of its Configuration Register is set 0, which activates to the continuous-conversion
\ mode. One possible full 16-bit configuration that includes this considerartion is 0xC2E3,
\ meaning that
\
\ ...
\ C2E3 WRITE-ADC-CONFIG
\ buffer CONTINUOUS-READ
\ ...
\
\ would be a valid sequence of execution for this mode.
\
: CONTINUOUS-READ \ ( buffer -- )
    BEGIN
        RESET-I2C
        DUP READ-ADC-CONVR
        DUP @ U.
        0 OVER !
    AGAIN
;

\ There may be the case (as it is here), that the Sample-Per-Second (SPS) rate of the ADC
\ is limiting, at least in comparison to the core clock of the main controller processor
\ (860 SPS max for ADC vs. 1 Mhz base clock of processor).
\
\ This translates to the fact that, continuous polling of the Conversion Register, may 
\ waste system resources as there would be a certain number of contiguous reads that yield
\ the same value, it not having being changed in the meantime.
\
\ Note: in this mode, since the single conversion shots must be manually triggered
\ to actually occur, we do that by acting on the config register with a configuration
\ that yields a 1 in bit 15, which initiates a conversion.
\
: CONTINUOUS-SINGLE-SHOT \ ( buffer -- )
    BEGIN
        RESET-I2C
        C3E3 WRITE-ADC-CONFIG
        RESET-I2C
        DUP READ-ADC-CONVR
        DUP @ U.
        0 OVER !
    AGAIN
;



\ ------------------------------------------ USAGE ------------------------------------------ \
\
\ Here, a sample usage of the I2C communication words is presented. It is assumed that all
\ of the words up to those in the "i2c.f" file have been compiled and none of them has yet 
\ been executed.
\

\ Initializations
GPIO-I2C-SETUP
INIT-I2C

\ Instantiating the buffer variable to store the read values.
VARIABLE BUFFER 
0 BUFFER !

\ Sample read of the Configuration Register. 
BUFFER READ-ADC-CONFIG

\ After transfer completion, the buffer holds the value 0x8583, 
\ which is the default according to the ADS1115 reference.
BUFFER @ U.

\ Sample write of new configuration.
C3E3 WRITE-ADC-CONFIG

\ Resetting the buffer to prepare it for the new read value.
0 BUFFER !

\ Reading again the Configuration Register.
BUFFER READ-ADC-CONFIG 

\ Buffer should now hold the value 0xC3E3,
\ which we just set with the previous write.
BUFFER @ U.

\ Similarly, a sample continuous read may occur by running the following.
C2E3 WRITE-ADC-CONFIG
BUFFER CONTINUOUS-READ
