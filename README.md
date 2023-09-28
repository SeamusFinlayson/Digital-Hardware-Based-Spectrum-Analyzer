# Digital-Hardware-Based-Spectrum-Analyzer
This repository is an implementation of a spectrum analyzer using System Verilog. Designed using Quartus and ModelSim.

## PROJECT DESCRIPTION
This project uses a Cyclone V FPGA which has an onboard analog to digital converter (ADC), a breakout board to connect the FPGA to and HDMI cable, a small HDMI connected display, and an analog signal generator.

The FPGA continuously samples the ADC to collect data samples of an electrical signal, in our case a simple sine wave at frequencies varying from 500Hz to 4kHz. The FPGA preforms a four point discrete fourier transform (DFT) implemented using a state machine. The result of the DFT is sent to the HDMI display.

## CONTRIBUTERS
This project was made as a collaberation between Seamus Finlayson and Micheal Andrews.

Contributions by Seamus Finlayson:
- Added analog to digital converter
- Added discrete fourier transform
- Added state machine for collecting samples and performing calculations

Contributions by Micheal Andrews:
- Added HDMI interface
- Added top level module
