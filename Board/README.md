
# Board

The board is a two-layer Eurocard, i.e. 160mm x 100mm.

## Schematics & Layout

The schematics and layout have been created with Cadsoft Eagle.
So, here you can find the 

- [csa_ultracpu.sch](csa_ultracpu.sch) and
- [csa_ultracpu.brd](csa_ultracpu.brd) files

But, you can still have a look at the schematics and layout using the
PNG images created

- [csa_ultracpu_v2.0b-sch-1.png](csa_ultracpu_v2.0b-sch-1.png) Part 1 - CS/A Bus interface
- [csa_ultracpu_v2.0b-sch-2.png](csa_ultracpu_v2.0b-sch-2.png) Part 2 - CPLD, CPU, Fast RAM
- [csa_ultracpu_v2.0b-sch-3.png](csa_ultracpu_v2.0b-sch-3.png) Part 3 - Power
- [csa_ultracpu_v2.0b-sch-4.png](csa_ultracpu_v2.0b-sch-4.png) Part 4 - Video and Audio output
- [csa_ultracpu_v2.0b-sch-5.png](csa_ultracpu_v2.0b-sch-5.png) Part 5 - SPI devices (Eth, USB, RTCC, ...)
- [csa_ultracpu_v2.0b-sch-6.png](csa_ultracpu_v2.0b-sch-6.png) Part 6 - Video RAM, data fetch and shift register

- [csa_ultracpu_v2.0b-layout.png](csa_ultracpu_v2.0b-layout.png) layout of the chips
- [csa_ultracpu_v2.0b-brd.png](csa_ultracpu_v2.0b-brd.png) layout of the traces

## Bill of Material

The main chips are:

- 1x W65816S CPU
- 1x x Spartan 6 FPGA
- 2x 8x512k parallel SRAM with 25ns access time
- Several ICs for Video generation
- several ICs for the bus interface
- 1x DS1813 RESET controller

- 70 MHZ crystal oscillator
- 16 MHZ crystal oscillator (bus clock - may be optional)

- Voltage regulators

- bypass caps

- 1x LM2937-3.3V SOT
- div. resistors/caps to generate 3.3V output

More details can be found in the [Eagle parts list](csa_ultracpu.csv).

A full [BOM](csa_ultracpu_BOM.xlsx) with parts numbers from Mouser is now provided as well.

## Changelog

### V2.0B

This moves from the Spartan 3 to a Spartan 6, increases clock speed to 70 MHz for a 
higher resolutoin video output, and more.

### V1.3C

This is a technology change of the programmable logic from the CPLD to an FPGA.
The FPGA has the same footprint, but much more space for logic inside. 
This allowed to integrate proper colour support, bitmaps, sprites, and many more
graphics features. A DAC allows outputting digital sound. 

### V1.0B

This fixes couple of things I found in V1.0A:

- The order of the color/intensity signals was the wrong way around
- The A/B and G inputs of IC15 had been accidently swapped
- An optional second color buffer has been removed as timing was good enough for it not be needed
- An optional "brown fix" has been added.
- On the board, two bypass caps were placed under the CPU socket
- On the board, the JP1 connector has been turned 180 degrees to confirm existing boards


