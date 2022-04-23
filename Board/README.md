
# Board V2.1A

The board is a two-layer Eurocard, i.e. 160mm x 100mm.

## Schematics & Layout

The schematics and layout have been created with Cadsoft Eagle.
So, here you can find the 

- [csa_ultracpu.sch](csa_ultracpu.sch) and
- [csa_ultracpu.brd](csa_ultracpu.brd) files

But, you can still have a look at the schematics and layout using the
PNG images created

- [csa-ultracpu-v1.0b-sch-1.png](csa-ultracpu-v1.0b-sch-1.png) Part 1 - CS/A Bus interface
- [csa-ultracpu-v1.0b-sch-2.png](csa-ultracpu-v1.0b-sch-2.png) Part 2 - CPLD, CPU, Fast RAM
- [csa-ultracpu-v1.0b-sch-3.png](csa-ultracpu-v1.0b-sch-3.png) Part 3 - Power
- [csa-ultracpu-v1.0b-sch-4.png](csa-ultracpu-v1.0b-sch-4.png) Part 4 - Video and Audio output
- [csa-ultracpu-v1.0b-sch-5.png](csa-ultracpu-v1.0b-sch-5.png) Part 5 - SPI devices (Eth, USB, RTCC, ...)
- [csa-ultracpu-v1.0b-sch-6.png](csa-ultracpu-v1.0b-sch-6.png) Part 6 - Video RAM, data fetch and shift register

## Bill of Material

The main chips are:

- 1x W65816S CPU

- 1x xc95288xl CPLD
- 2x 8x512k parallel SRAM with 25ns access time
- Several ICs for Video generation:
  - 2x 74hct245d
  - 2x 74hct574d
  - 1x 74hct157d
  - 1x 74hct166d
  - 1x 74hct138d (optional brown fix)
- several ICs for the bus interface
  - 2x 74hct244d
  - 3x 74hct245d
  - 1x 74ls14d
  - 1x 74ls06d
- 1x DS1813 RESET controller

- 50 MHZ crystal oscillator
- 16 MHZ crystal oscillator (bus clock - may be optional)

- Voltage regulator

- x 0.1uF bypass caps

- 1x LM2937-3.3V SOT
- div. resistors/caps to generate 3.3V output

More details can be found in the [Eagle parts list](csa-ultracpu-parts.txt).

## Changelog

### V1.0B

This fixes couple of things I found in V1.0A:

- The order of the color/intensity signals was the wrong way around
- The A/B and G inputs of IC15 had been accidently swapped
- An optional second color buffer has been removed as timing was good enough for it not be needed
- An optional "brown fix" has been added.
- On the board, two bypass caps were placed under the CPU socket
- On the board, the JP1 connector has been turned 180 degrees to confirm existing boards


