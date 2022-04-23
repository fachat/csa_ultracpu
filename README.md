# Ultra-CPU

This is the CPU board for a re-incarnation of the Commodore PET or other computer(s) from the later 1970s.

It is build on a Eurocard board and has only parts that can still be obtained new in 2021.
It uses the [CS/A bus interface](http://www.6502.org/users/andre/csa/index.html) to use other I/O boards.

As the memory mapping is programmable using the CPLD on the board, multiple types of computers can
potentially re-created. I started with my favourite one, the Commodore PET.

The reason this board is called Ultra-CPU is because it has colour over the [MicroPET](http://www.6502.org/users/andre/upet/index.html), and it can potentially be used to recreate not only the Commodore PET.
The downside compared to the Micro-PET is, that it needs a separate I/O board to re-create a Commodore PET.
This can be found [here on my CS/A page](http://www.6502.org/users/andre/csa/petio/index.html).

![Picture of an Ultra-CPU board with a PETIO](images/cover.jpg)

## Features

The board is built with a number of features:

- Commodore 3032 / 4032 / 8032 / (8296 TODO) with options menu to select at boot
  - Boot-menu to select different PET versions to run (BASIC 1, 2, 4)
  - 40 col character display
  - 80 col character display
  - (8296 memory map emulation TODO)
- Improved system design:
  - 512k video RAM, plus 512k fast RAM, accessible using banks on the W65816 CPU
  - boot from an SPI Flash ROM
  - up to 12.5 MHz mode (via configuration register)
  - VGA color video output (RGBI in 640x480 mode, up to 640x450 usable)
  - Write protection for the PET ROMs once copied to RAM
  - lower 32k RAM mappable from all of the 512k fast RAM
- Improved Video output:
  - modifyable character set
  - 40/80 column display switchable
  - 25/50 rows display switch (untested)
  - multiple video pages mappable to $8000 video mem address

## Overview

[//]: # The system architecture is actually rather simple, as you can see in the following graphics.

[//]: # ![MicroPET System Architecture](images/upet-system-architecture.png)

The main functionality is "hidden" inside the CPLD. It does:

1. clock generation and management
2. memory mapping
3. video generation.
4. SPI interface and boot

On the CPU side of the CPLD it is actually a rather almost normal 65816 computer, 
with the exception that the bank register (that catches and stores the address lines 
A16-23 from the CPU's data bus) is in the CPLD, and that there is no ROM. The ROM has been
replaced with some code in the CPLD that copies the initial program to the CPU accessible
RAM, taking it from the Flash Boot ROM via SPI. This actually simplifies the design,
as 

1. parallel ROMs are getting harder to come by and
2. they are typically not as fast as is needed, and
3. with the SPI boot they don't occupy valuable CPU address space.

The video generation is done using time-sharing access to the video RAM.
The VGA output is 640x480 at 60Hz. So there is a 40ns slot per pixel on the screen, 
with a pixel clock of 25MHz.

The system runs at 12.5MHz, so a byte of pixel output (i.e. eight pixels) has four
memory accesses to VRAM. Two of them are reserved for video access, one for fetching the
character data (e.g. at $08xxx in the PET), and the second one to fetch the "character ROM"
data, i.e. the pixel data for a character. This is also stored in VRAM, and is being loaded
there from the Flash Boot ROM by the initial boot loader.

The CPLD reads the character data, stores it to fetch the character pixel data, and streams
that out using its internal video shift register.

For more detailled descriptions of the features and how to use them, pls see the subdirectory,
as described in the next section.

## Building

Here are four subdirectories:

- [Board](Board/) that contains the board schematics and layout
- [CPLD](CPLD/) contains the VHDL code to program the CPLD logic chip used, and describes the configuration options - including the [SPI](CPLD/SPI.md) usage
- [ROM](ROM/) ROM contents to boot

### Board

To build the board, you have to find a provider that builds PCBs from Eagle .brd files.
Currently no gerbers are provided.

### CPLD

The CPLD is a Xilinx xc95288xl programmable logic chip. It runs on 3.3V, but is 5V tolerant,
so can be directly connected to 5V TTL chips. I programmed it in VHDL.

Unfortunately the W65xx parts are "only" CMOS, and not TTL input chips - but 3.3V is still above
the VCC/2 for the 5V chips. Only Phi2 needs improvements on the signal quality using a pull-up resistor
and specific VHDL programming.

### ROM

The ROM image can be built using gcc, xa65, and make. Use your favourite EPROM programmer to burn it into the SPI Flash chip.

The ROM contains images of all required ROM images for BASIC 1, 2, and 4, and corresponding editor ROMs, including
some that have been extended with wedges and colour-PET functionality.

The updated editor ROMs are from [Steve's Editor ROM project](http://www.6502.org/users/sjgray/projects/editrom/index.html) and can handle C64 keyboards, has a DOS wedge included, and resets into the Micro-PET boot menu.
For more details see the [ROM description](ROM/README.md)


## Future Plans

These are future expansions I want to look into. Not all may be possible to implement.

- Look into using the CPU as part of an Apple II clone?

## Gallery

![A full system with nano488 disk and keyboard](images/system.jpg)

![Boot menu](images/bootmenu.jpg)

![debug](images/debug.jpg)
 
