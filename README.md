# Agiematic CD monitor frequency converter
## what is it? 
This is an FPGA module designed for xillinx Zynq xc7z010 from Antminer S9 control board. 
this module is created to allow you to plug a standard VGA monitor instead of the original CRT
into your AGIEMATIC cnc rack. 
## how to use it? 
this is only an FPGA module. you also need a constraints file to specify clocks and pins, and an ADC.
i've made an ADC using three AD9283 ICs, i might publish kicad sources soon.
## project state
### broken lol
now we have strange output, but it works in debug mode... 
