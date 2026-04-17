# Agiematic CD monitor frequency converter
## what is it? 
it's an FPGA module, written for xillinx Zynq xc7z010 from Antminer S9 control board. 
this module is created to allow you to plug a standard VGA monitor instead of original CRT
into your AGIEMATIC cnc rack. 
## how to use it? 
this is only an FPGA module. you also need a constraints file to specify clocks and pins, and an ADC.
i've made an ADC using three AD9283 ICs, may be i will publish kicad sources soon.
## project state
now we get DECERR BRESP signal. it became so after i changed the pixel size from 8 to 16 bits. 
but when it was 8, all worked fine. Unfortunately, that 8-bit version wasn't save and is disappeared.
