
# VICCY-II

The Viccy-II is a re-implementation of the video code from the Micro-PET (nick-named Viccy), but using the full capabilities
of the Ultra-CPU's FPGA. In addition to the emulation of the few CRTC registers already done in the Micro-PET,
it adds a lot of other features similar to those from the C128's VDC, and the C64's VIC-II.

The Viccy-II, as the Viccy before, is using a fixed VGA-defined timing for outputting the video signal.
This means, that anything defined here just paints pixels onto that frame canvas.

Currently the Viccys support 640x480@60Hz VGA timing. As 80 character with 8 pixel width already consume
640 pixels in the horizontal resolution, there are no left and right borders. However, there is a 
vertical border, depending on the vertical timing setup.

## Overview

This is an overview on the register set. Registers are marked with which chip they should be
compatible with (roughly). Note, that the VDC is an extension to the CRTC. CRTC register are not additionally marked as VDC.

- $e880/e881 (59520/59521) [CRTC emulation](#crtc-emulation)
  - r1: horizontal displayed - defines how many characters are displayed on a character row. (CRTC)
  - r6: vertial displayed - the number of character rows displayed in a frame (CRTC)
  - r9: (bits 3-0) scan lines per character - 1 (CRTC)
  - r10: cursor start scan line:  (CRTC)
    - bits 4-0: number of scan line where reverse video cursor starts (0=top)
    - bits 6-5: 
      - 00: solid cursor
      - 01: cursor off
      - 10: blink at 1/16th of the frame rate
      - 10: blink at 1/32th of the frame rate
  - r11: cursor end scan line + 1 (CRTC)
  - r12: start of video memory high (CRTC)
  - r13: start of video memory low (CRTC)
  - r14: cursor position high (CRTC)
  - r15: cursor position low (CRTC)
  - r20: attribute start address high (VDC)
  - r21: attribute start address low (VDC)
  - r22: character horizontal - define character width total and displayed (VDC)
    - bits 3-0: displayed: number of bits displayed from the character definition (not VDC!)
    - bits 3-0: total: total number of horizontal bits timed for a char, -1.
  - r23: character displayed vertical: number of scan lines -1 of the displayed part of a character (VDC)
  - r24: vertical smooth scroll (partly VDC, scroll similar to VIC-II)
    - bits 3-0: number of scan lines to scroll the screen down 
    - bit 4: RSEL: if set, extend upper and lower border 4 scanlines into the display window, or 8 scanlines if r9 > 7
    - bit 5: character blink rate - 0 blinks characters in 1/16th frame rate, 1 in 1/32th (VDC)
    - bit 6: reverse screen - exchange foreground and background colours when set (VDC)
  - r25: horizontal smooth scroll (partly VDC, scroll similar to VIC-II)
    - bits 3-0: number of pixels to shift the output to the right
    - bit 4: CSEL: if set, extend left border by 7 pixels and right border by 9 pixels
    - bit 5: semigraphic mode (display the last pixel of a char in the intercharacter spacing, instead of background)
    - bit 6: attribute enable (VDC)
    - bit 7: bitmap mode
  - r26: default colours (VDC)
    - bits 3-0: background color
    - bits 7-4: foreground color
  - r27: address increment per row: add this to the memory address after each character row (VDC)
  - r28: character set start address
    - bits 7-5: character generator address bits A13-A15. (VDC)
  - r29: underline scan line count (VDC)
  - r32: rasterline counter low (bits 0-7)
  - r33: control register
    - bits 1-0: bits 9/8 of the rasterline counter
    - bit 2: extended mode (enable full and multicolor text modes)
    - bit 4: DEN: display enable
    - bit 7-5: - 
  - r34: extended background colour 
    - bits 3-0 background colour 1
    - bits 7-4 background colour 2
  - r35: border colour
    - bits 3-0: border colour
  - r36 IRQ control (VIC-II)
    - bit 0: raster match enable
    - bit 1: sprite/bitmap collision enable
    - bit 2: sprite/sprite collision enable
    - bit 7-3: unused
  - r37 IRQ status; read the interrupt status. Clear by writing 1s into relevant bits (VIC-II)
    - bit 0: raster match occured
    - bit 1: sprite/bitmap collision occured
    - bit 2: sprite/sprite collision occured
    - bit 6-3: unused
    - bit 7: one when interrupt has occurred

Sprite registers:

  - r40: X coordinate sprite 0 (VIC-II)
  - r41: Y coordinate sprite 0 (VIC-II)

  - r42: X coordinate sprite 1 (VIC-II)
  - r43: Y coordinate sprite 1 (VIC-II)

  - r44: X coordinate sprite 2 (VIC-II)
  - r45: Y coordinate sprite 2 (VIC-II)

  - r46: X coordinate sprite 3 (VIC-II)
  - r47: Y coordinate sprite 3 (VIC-II)

  - r48: X coordinate sprite 4 (VIC-II)
  - r49: Y coordinate sprite 4 (VIC-II)

  - r50: X coordinate sprite 5 (VIC-II)
  - r51: Y coordinate sprite 5 (VIC-II)

  - r52: X coordinate sprite 6 (VIC-II)
  - r53: Y coordinate sprite 6 (VIC-II)

  - r54: X coordinate sprite 7 (VIC-II)
  - r55: Y coordinate sprite 7 (VIC-II)

  - r56: bit 7 of sprite X coordinates (VIC-II)
  - r57: bit 7 of sprite Y coordinates
  - r58: bit 8 of sprite X coordinates

  - r59: sprite enabled (VIC-II)

  - r60: sprite X expansion (VIC-II)
  - r61: sprite Y expansion (VIC-II)

  - r62: sprite-sprite collision (VIC-II)
  - r63: sprite-data collision (VIC-II)

  - r64: sprite data priority (VIC-II)
  - r65: sprite multicolor (VIC-II)

  - r66: sprite multicolor 0 (VIC-II)
  - r67: sprite multicolor 1 (VIC-II)

  - r68: color sprite 0 (VIC-II)
  - r69: color sprite 1 (VIC-II)
  - r70: color sprite 2 (VIC-II)
  - r71: color sprite 3 (VIC-II)
  - r72: color sprite 4 (VIC-II)
  - r73: color sprite 5 (VIC-II)
  - r74: color sprite 6 (VIC-II)
  - r75: color sprite 7 (VIC-II)

## Control Ports

### Micro-PET

There are four control ports at $e800 - $e803. They are currently only writable.

#### $e800 (59392) Video Control

TODO: need to check interference with VDC registers

- Bit 0: unused - must be 0
- Bit 1: 0= 40 column display, 1= 80 column display
- Bit 2: 0= screen character memory in bank 0, 1= character memory only in video bank (see memory map)
- Bit 3: 0= double pixel rows, 1= single pixel rows (also 400 px vertical hires)
- Bit 4: 0= interlace mode (only every second rasterline), 1= duplicate rasterlines
- Bit 5: unused - must be 0
- Bit 6: 0= when switching char height, move vsync to keep screen centered. 1= prevent that
- Bit 7: 0= video enabled; 1= video disabled

Note that if you use 80 columns, AND double pixel rows (+interlace), you get the 80x50 character resolution.
This mode is, however, not easily manageable by normal code in bank 0. In the $8xxx area the video
and colour memory can be accessed. The first half accesses the character video memory, the second half
is reserved for the colour memory. Now, 80x50 character require almost 4k of character video memory,
more than twice than is available in the reserved space from $8000 to $8800. So, the screen can,
in this mode, only be managed using long addresses into bank 8 (the video bank), or code running
in the video bank.

##### Screen mirror in bank 0

The CRTC reads its video data from the video bank in VRAM.
This is not mapped to bank 0 in the CPU address space, as it is "slow" memory, because
the available memory bandwidth is shared with the video access.

To allow the PET code to directly write to $8xxx for character video memory, Bit 2 maps
the $8xxx window in CPU bank 0 to the VRAM video bank.

Note that with the register $e802, the position of the video window in the video bank
can be changed (while it stays at $8xxx in the CPU memory bank 0). This allows 
for easy switching between multiple screens beyond the 4k limit of the PET video memory
window at $8xxx.

##### Interlace and 50 row mode

In normal mode (after reset), the VGA video circuit runs in interlace mode,
i.e. only every second raster line is displayed with video data.
Writing a "1" into Video Control register bit 4, interlace is switched off, and every
single line is displayed with video data. 

As long as bit 3 is 0, every rasterline is 
displayed twice, to get to the same height as in interlace mode.
If bit 3 is 1, then every rasterline is a new rasterline.
So, setting bit 3=1 and bit 4=1 gives double the number of character rows
(or raster rows in bitmap mode). I.e. with this you can enable 50 character row
screens.

##### Moving Sync

The character height can be switched between 8 pixel rows and 9 pixel rows (using 
R9 of the emulated CRTC, see below). 
This gives a displayed height of the screen of either 400 or 450 (each rasterline is
displayed twice, see previous section). 

For the video code, the screen starts with the first displayed rasterline. The sync position
is fixed to that position, i.e. it has a fixed rasterline where the vertical sync is triggered.
The value is selected such, that the displayed data is about centered on the screen.

Now, if the character height is changed, the height of the displayed data is changed, and to 
keep the this area vertically centered, the position of the vertical sync in relation to the 
first rasterline is moved. 

However, as there just isn't enough space in the CPLD, when this happens, the distance between
two vertical sync signals changes for one displayed frame. Some monitors may have difficulties
with this, trying to find a new video mode and switching the display off during that search 
attempt. 

In normal operation that does not matter, as this mode should be set once and then left as it is.
But for programs that may switch character height more often, this may be irritating. So,
with bit 6 you can disable moving the vertical sync. The displayed data will stay relatively
high on the screen, and just the lower border moves up and down when the character height is
changed. Then the monitors don't recognize a potential mode change, and thus don't blank
the screen. It just isn't properly centered anymore.


## CRTC/VDC emulation

The Video code (partially) emulates only a subset of the CRTC registers, as given 
in the register short description above.

As usual with the CRTC, you have to write the register number to $e880 (59520),
the write the value to write to the register to $e881 (59521).

The video code emulates some kind of hybrid between the C128 VDC (which basically includes
the CRTC registers), the PET CRTC, and the C64 VIC-II. PET CRTC emulation is made as good as possible,
VDC is partially emulated, and features coming from the VIC-II are separate.

### Video modes

The following video modes are supported

#### Text modes

1. single color mode

In this mode, extended mode and attribute memory are disabled in R33 and R25 respectively.

Each character data is read from character memory, and used as index in the character generator memory.
The data from the character generator memory is shifted out, using foreground (1-pxiels) or background (0-pixels) colours
from R26.

This basically emulates a simple b/w screen, just with colours adjustable via R26.

2. attribute color mode



### Video memory mapping

The video memory is defined as follows:

#### Character mode

In character mode (see control port below) two memory areas are used:

1. Character memory and
2. Character pixel data (usually "character ROM")

Register 12 is used as follows:

- Bit 0: - unused - must be 0
- Bit 1: - unused - must be 0
- Bit 2: A10 of start of character memory
- Bit 3: A11 of start of character memory 
- Bit 4: A12 of start of character memory
- Bit 5: A13 of start of character memory
- Bit 6: A13 of character pixel data (charrom)
- Bit 7: A14 of character pixel data (charrom)

As you can see, the character memory can be mapped in 1024 byte pages.
14/15 of character memory address are set to %10, so character memory
starts at $8000 in the video bank, and reaches up to $bfff

For 40 column mode this means 16 screen pages, or 8 screen pages in 80 column mode.
Character memory is mapped to bank 0 at boot, but can be unmapped and only be available in bank 8 (VRAM) using the control port

The character set is 8k in size: two character sets of 4k each, switchable with the 
VIA I/O pin given to the CRTC as in the PET. Register 12 can be used to select
one of 4 such 8k sets. Note that each character occupies 16 bytes (not 8 as in the typical
Commodore character set), so the 9th rasterline for a character may be used.
Character set data is mapped to the lower half of bank 8 (VRAM bank 0, i.e. A15=0).

#### Hires mode

Hires mode is available in 40 as well as 80 "column" mode, i.e. either 320x200 or 640x200 pixels.

Register 12 here is used as follows:

- Bit 0: - unused - must be 0
- Bit 1: - unused - must be 0
- Bit 2: A10 of start of hires data
- Bit 3: A11 of start of hires data
- Bit 4: A12 of start of hires data
- Bit 5: A13 of start of hires data
- Bit 6: A14 of start of hires data
- Bit 7: A15 of start of hires data

#### Character generator memory

The following diagram describes the way that the char generator memory is addressed.
The Character generator memory is the memory that holds the pixel data for each character.
Each character has 16 consecutive bytes, so that the maximum of 9 pixel rows per
character can be handled. As a character has 16 bytes, a character set of 256 characters
has a character generator of 4k.

The Bank Control register allows to select 4 blocks of 8k for the character generator memory,
located at the lower half of the Video Bank 8.
In each 8k, there are two sets of character generators, of 4k each. The one to use is selected by the
VIA CA2 output pin as on the PET.


       Video    +----+ $090000
       BANK     |    |        
                |    |	 
                |    |	 
                +----+ $08e000	 
                |    |	 
                |    |
                |    |	 
                +----+ $08c000
                |    |
                |    |
                |    |
                +----+ $08a000
                |    |	 
                |    |
                |    |	 
                +----+ $088000	 
                |    |	      CRTC12.6/7 -> 11, VIA CA2=1 
                +----+ $087000	 
                |    |	      CRTC12.6/7 -> 11, VIA CA2=0 
                +----+ $086000	 
                |    |	      CRTC12.6/7 -> 10, VIA CA2=1 
                +----+ $085000	 
                |    |	      CRTC12.6/7 -> 10, VIA CA2=0
                +----+ $084000	 
                |    |	      CRTC12.6/7 -> 01, VIA CA2=1
                +----+ $083000	 
                |    |	      CRTC12.6/7 -> 01, VIA CA2=0
                +----+ $082000	 
                |    |	      CRTC12.6/7 -> 00, VIA CA2=1
                +----+ $081000	 
                |    |	      CRTC12.6/7 -> 00, VIA CA2=0
                +----+ $080000
        
### Sprites

Please see the extensive VIC-II documentation for a description of the corresponding sprite registers


