
# DAC

The DAC feature is implemented by a MCP4802 digital-analog converter and provides analog or audio output.

## Overview

The MCP4802 is controlled by SPI, and is connected to the FPGA via dedicated SPI lines. This way it can be used independently from other SPI devices. The SPI protocol used is programmed into the FPGA. Using FPGA registers, data can either be sent directly to the DAC, or data can be automatically read from VRAM via DMA.

The DMA engine has a 16 byte buffer that is filled from memory as soon as there is bandwidth available (from video - DAC DMA stops the CPU). Filling happens e.g. off-screen during horizontal blank periods. From that buffer the data is sent to the DAC with constant data rate, to minimize jitter.

## Register Set

This is an overview on the register set. These are the memory locations seen by the CPU:

- $e830 (59440): DMA base address low (7-0)
- $e831 (59441): DMA base address mid (15-8)
- $e832 (59442): DMA base address high (18-16)
- $e833 (59443): DMA block length low (7-0)
- $e834 (59444): DMA block length mid (15-8)
- $e835 (59445): DMA block length high (18-16)
- $e836 (59446): DMA rate low (7-0), counted in 1/64 of the main clock (50MHz)
- $e837 (59447): DMA rate high (17-8)

- $e83c (59452): Channel 0: Write: send new data byte to DAC (not when DMA is active); read: last byte sent to DAC
- $e83d (59453): Channel 1: Write: send new data byte to DAC (not when DMA is active); read: last byte sent to DAC
- $e83e (59454): Status (read only)
  - b7: DMA is active (fetching & sending to DAC)
  - b6: interrupt is active
  - b5: DMA has fetched all bytes, but buffer is not empty yet and data being sent to the DAC
  - b4: -
  - b3-0: number of bytes in the DMA buffer
- $e83f (59455): Control (r/w)
  - b4: enable IRQ when DMA is done (but SPI not yet finished)
  - b3: DMA channel (if not stereo) / Dual-Mono-Flag (if stereo)
  - b2: DMA stereo flag - data bytes are alternating between channel 0 and 1
  - b1: DMA loop flag: if set, and full DMA block has been read, continue from the beginning
  - b0: DMA active: set to start DMA. Will be reset to 0 when DMA ends


## Data format

The data is byte-wide (8 bit), with a range of (at the current schematics) between about 10 and 220 with a linear output. 

You can convert WAV or MP3 files using the "sox" utility like so:

sox input.wav -t raw -r 8000 -b 8 -e unsigned-integer output.raw

play -t raw -r 8000 -b 8 -e unsigned-integer simple-logo-149190.raw

Important are the options:
- -r 8000: data rate of 8000 Hz
- -t raw: raw output format
- -b 8: 8 bit format
- -e unsigned-integer: unsigned integer

## Stereo DMA

For stereo output using DMA, the data for both channels need to be interleaved. I.e. first byte channel 0, second byte channel 1. Two bytes are sent to the DAC chip, and then simulaneously loaded into the DAC using the chips "/LDAC" signal.

Note that for stereo, CTRL.2 must be 1, and CTRL.3 must be zero

## Dual-Mono DMA

In this mode data is read from memory as mono data, i.e. one byte per time slot. However, the same data is sent to the DAC on both channels.

Note that for stereo, CTRL.2 must be 1, and CTRL.3 must be 1

## Interrupt 

When the DMA interrupt is enabled, the interrupt is triggered when the last byte of the defined DMA buffer has been read from memory into the 16 byte pipeline buffer. This enables the interrupt routine to re-set the data buffer address and size, and re-start the DMA with these values. So an uninterrupted data output can be achieved.



