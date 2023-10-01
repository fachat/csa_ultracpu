
# VICCY-II

The Viccy-II is a re-implementation of the video code from the Micro-PET (nick-named Viccy), but using the full capabilities
of the Ultra-CPU's FPGA. In addition to the emulation of the few CRTC registers already done in the Micro-PET,
it adds a lot of other features similar to those from the C128's VDC, and the C64's VIC-II.

The Viccy-II, as the Viccy before, is using a fixed VGA-defined timing for outputting the video signal.
This means, that anything defined here just paints pixels onto that frame canvas.

Currently the Viccys support 640x480@60Hz VGA timing. As 80 character with 8 pixel width already consume
640 pixels in the horizontal resolution, there are no left and right borders. However, there is a 
vertical border, depending on the vertical timing setup. An option to increase the resolution to 768x576@60Hz
is under investigation.

Note: this is currently under development and subject to change without notice!

## Overview

This is an overview on the register set. Registers are marked with which chip they should be
compatible with (roughly). Note, that the VDC is an extension to the CRTC. CRTC register are not additionally marked as VDC.

These are the memory locations seen by the CPU:

- $e880 (59520): status register (read), index register (write only)
- $e881 (59521): read/write access to register specified in index register
- $e882 (59522): read/write access to index register (new)
- $e883 (59523): read/write access to register as in $e881; each access increases index register by one (new)

Note that the last two registers are new and should provide easier access to the register file.

 [CRTC emulation](#crtc-emulation)

The following are the internal Viccy registers:

- r1: horizontal displayed - defines how many characters are displayed on a character row. (CRTC)
  - note: if upet compatibility (r39.7) is set, this is always for 40 columns even if in 80 column mode.
- r6: vertial displayed - the number of character rows displayed in a frame (CRTC)
- r8: mode register
  - bit 7: 1=80 columns
    - TODO: see r22
  - bit 1-0: 
    - 0x= normal display
    - 10= interlace (show every scanline twice, i.e. r9 is effectivly twice its value)
    - 11= double vertical resolution
- r9: (bits 3-0) scan lines per character - 1 (CRTC)
  - note: in upet compat mode, also sets vertical position (r45)
- r10: cursor start scan line:  (CRTC)
  - bits 4-0: number of scan line where reverse video cursor starts (0=top)
  - bits 6-5: 
    - 00: solid cursor
    - 01: cursor off
    - 10: blink at 1/16th of the frame rate
    - 11: blink at 1/32th of the frame rate
- r11: cursor end scan line + 1 (CRTC)
- r12: start of video memory high (CRTC)
- r13: start of video memory low (CRTC)
- r14: cursor position high (CRTC)
- r15: cursor position low (CRTC)
- r20: attribute start address high (VDC)
- r21: attribute start address low (VDC)
- r22: (not used: character horizontal - define character width total and displayed (VDC)
  - bits 3-0: displayed: number of bits displayed from the character definition (not VDC!)
  - bits 7-4: total: total number of horizontal bits timed for a char, -1.)
  - TODO: while total h.bits will always be 8, implement displayed h.bits (.0-.3)
- r23: character displayed vertical: number of scan lines -1 of the displayed part of a character (VDC)
    - TODO
- r24: vertical smooth scroll (partly VDC, scroll similar to VIC-II)
  - bits 3-0: number of scan lines to scroll the screen up
  - bit 4: RSEL: if set, extend upper and lower border 4 scanlines into the display window, or 8 scanlines if r9 > 7
    - TODO: VDC: bits 4-0: scan lines to scroll UP
  - bit 5: character blink rate - 0 blinks characters in 1/16th frame rate, 1 in 1/32th (VDC)
  - bit 6: reverse screen - exchange foreground and background colours when set (VDC)
- r25: horizontal smooth scroll (partly VDC, scroll similar to VIC-II)
  - bits 3-0: number of pixels to shift the output to the right
  - bit 4: CSEL: if set, extend left border by 7 pixels and right border by 9 pixels
    - TODO: according to https://www.c64-wiki.de/wiki/VDC bit4=1 is 40 col moddde
  - bit 5: unused (semigraphic mode (display the last pixel of a char in the intercharacter spacing, instead of background))
    - TODO: implement together with parts of R22
  - bit 6: attribute enable (VDC)
  - bit 7: bitmap mode (hires)
- r26: default colours (VDC)
  - bits 3-0: background color
  - bits 7-4: foreground color
- r27: address increment per row: add this to the memory address after each character row (VDC)
- r28: character set start address
  - bits 7-5: character generator address bits A13-A15. (VDC)
- r29: underline scan line count (VDC)

- (r30) block copy/fill word count
- (r31) data register
- (r32) block copy source (a15-a8)
- (r33) block copy source (a7-a0)
- (r34) display enable begin
- (r35) display enable end
- (r36) DRAM refresh cycles per rasterline

- r37: sync status
  - bit 5: vsync
  - bit 6: hsync

- r38: rasterline counter low (bits 0-7)
- r39: control register
  - bits 1-0: bits 9/8 of the rasterline counter
    - Note: rasterline here does not make much sense as always needs to be combined with mode bits
  - bit 2: extended mode (enable full and multicolor text modes)
  - bit 4: DEN: display enable
  - bit 6-5: - 
  - bit 7: Micro-PET compatible (see r1)
    - TODO: change bits so rasterline can be extended (e.g. 2->5, 4->6); move border x/y ext bits here (.3,.4)?
- r40: extended background colour 
  - bits 3-0 background colour 1
  - bits 7-4 background colour 2
- r41: border colour
  - bits 3-0: border colour
- r42 IRQ control (VIC-II)
  - bit 0: raster match enable
  - bit 1: sprite/bitmap collision enable
  - bit 2: sprite/sprite collision enable
  - bit 7-3: unused
- r43 IRQ status; read the interrupt status. Clear by writing 1s into relevant bits (VIC-II)
  - bit 0: raster match occured
  - bit 1: sprite/bitmap collision occured
  - bit 2: sprite/sprite collision occured
  - bit 6-3: unused
  - bit 7: one when interrupt has occurred
- r44 horizontal position (in chars); replaces r2
  - bit 0-6, defaults to 8
- r45 vertical position (in rasterlines) of start of raster screen; replaces r7
  - bit 0-7, defaults to 84 (so 25 rows with 8 rasterlines/char are centered on screen); in upet compat mode, gets set when r9 is written

Sprite registers (subject to change):

- r50: X coordinate sprite 0 (VIC-II)
- r51: Y coordinate sprite 0 (VIC-II)
- r52: sprite 0 extra
  - bit 1-0: bits 8-7 of sprite 0 X coordinate
  - bit 5-4: bits 8-7 of sprite 0 Y coordinate
- r53: sprite 0 control
  - bit 0: enable
  - bit 1: X-expand
  - bit 2: Y-expand
  - bit 3: Multicolour flag
  - bit 4: sprite data priority
  - bit 5: sprite border flag (if set, show over border)
- r54: color sprite 0 (VIC-II)

- r55-: sprite 1
- r60-: sprite 2
- r65-: sprite 3
- r70-: sprite 4
- r75-: sprite 5
- r80-: sprite 6
- r85-: sprite 7

- r90: sprite-sprite collision (VIC-II)
- r91: sprite-data collision (VIC-II)

- r92: sprite multicolor 0 (VIC-II)
- r93: sprite multicolor 1 (VIC-II)


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

For all the text modes, the hires bit in r25.7 must be zero.

1. single colour text mode (VDC/CRTC)

In this mode, extended mode and attribute memory are disabled in R33 and R25 respectively.

Each character data is read from character memory, and used as index in the character generator memory.
The data from the character generator memory is shifted out, using foreground (1-pxiels) or background (0-pixels) colours
from R26.

This basically emulates a simple b/w screen, just with colours adjustable via R26.

2. attribute colour text mode (VDC)

Together with the character value and attribute value is being read from video memory.
This attribute byte contains the following bits:

- bit 7: alternate character set
- bit 6: reverse video attribute bit
- bit 5: underline attribute bit
- bit 4: blink attribute bit
- bit 3-0: foreground colour

Using the additional alternate character set bit from the attribute byte, the character bit value is loaded from memory
and streamed out. 1-bits get the foreground colour from the attribute byte. 0-bits get the background colour from r26.

Note that the alternate character set bit and the graphics output from the VIA CA2 are XOR'd.

This is the VDC's attribute colour mode. To achieve this, extended mode bit r33.2 must be 0, and attribute enable bit r25.6 must be 1.

3. full colour text mode (ColourPET)

In this mode, again character value and attributes are loaded from memory. The attribute byte contains the following information:

- bits 3-0: foreground colour
- bits 7-4: background colour

There is no alternate character set bit in the attribute byte, only VIA CA2 is used as usual in the PET. 
After reading the character bit data, it is streamed out using the foreground colour (for 1-bits) and 
background colour (for the 0-bits) from the attribute byte.

This is the Colour-PET video mode. To achieve it, the extended mode bit r33.2 must be set, and the attribute enable bit r25.6 must be 0.

4. multicolour mode (partly VIC-II, partly VDC)

This mode is an extension to the C64's multicolour text mode, utilizing the additional bits in the attribute memory compared to the VIC-II's 4-bit video memory.

Character data and attribute data are being fetched. The attribute byte contains the following bits:

- bit 7: alternate character set
- bit 6: reverse video attribute bit (mc=0)
- bit 5: multicolour bit (mc)
- bit 4: blink attribute bit (mc=0)
- bit 3-0: foreground colour

Note the different meaning of bit 5 - it is not used to disable multicolour for that character, or enable it.
With disabled multicolour the character is displayed as in attribute colour text mode, except there is no underline bit. 
With enabled multicolour bit, the character bits are fetched (alternate character set as in attribute colour text mode).
When streaming, two bits are lumped together and evaluated to give these colours:

- 00: background colour register r26
- 01: background colour 1 register r34
- 10: background colour 2 register r34
- 11: foreground colour from attribute byte

#### High Resolution Modes

For all the text modes, the hires bit in r25.7 must be set.

1. single colour hires mode

In this mode the bitmap is displayed in the two colours from r26.

To use this mode, extended mode bit r33.2 and attribute enable bit r25.6 must be zero.

2. attribute colour hires mode (VDC)

This mode works like the attribute colour text mode, only that not character data is read and displayed,
but pixel data. The background colour is taken from r26. The foreground colour is taken from the attribute byte.

Note that the attribute byte is read for a full character cell with 8 pixels width and height as defined with r9.
All bitmap pixels in that cell share the same colour information.

To use this mode, extended mode bit r33.2 is zero, and attribute enable bit r25.6 must be set.

3. full colour hires mode

Similar to the full colour text mode, the attribute byte provides both foreground and background colours
for all bitmap pixels in the attribute colour cell.

To use this mode, extended mode bit r33.2 is set, and attribute enable bit r25.6 must be clear.

4. multicolour hires mode

In this mode, bitmap data and attribute bytes are loaded from memory. 
The attribute byte contains the following information:

- bits 3-0: foreground colour
- bits 7-4: background colour

From the bit map data, every two bits of the pixel data are lumped together and used to determine the colour:

- 00: background colour from attribute byte
- 01: background colour 1 register r34
- 10: background colour 2 register r34
- 11: foreground colour from attribute byte
 
To use this mode, extended mode bit r33.2 is set, and attribute enable bit r25.6 must be set as well.


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

TODO: should bit 1 be replaced with R25.5 "Pixel double width"? It would be incompatible with the Micro-PET
TODO: should bits 3 and 4 be replaced with R8.1/0 interlace control?

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



### Video memory mapping

The video memory is defined as follows:

#### Character mode

In character mode (see control port below) two memory areas are used:

1. Character memory (r12/r13) and
2. Character pixel data (usually "character ROM") (r28)
3. Character attribute data (r20/r21)

Character memory is mapped to bank 0 at boot, but can be unmapped and only be available in bank 8 (VRAM) using the control port

The character set is 8k in size: two character sets of 4k each, switchable with the 
VIA I/O pin given to the CRTC as in the PET. Register 12 can be used to select
one of 4 such 8k sets. Note that each character occupies 16 bytes (not 8 as in the typical
Commodore character set), so the 9th rasterline for a character may be used.
Character set data is mapped to the lower half of bank 8 (VRAM bank 0, i.e. A15=0).

#### Hires mode

Hires mode is available in 40 as well as 80 "column" mode, i.e. either 320x200 or 640x200 pixels.

1. Bitmap data memory (r12/r13) and
2. Character attribute data (r20/r21)

#### Character generator memory

The following diagram describes the way that the char generator memory is addressed.
The Character generator memory is the memory that holds the pixel data for each character.
Each character has 16 consecutive bytes, so that the maximum of 9 pixel rows per
character can be handled. As a character has 16 bytes, a character set of 256 characters
has a character generator of 4k.

The Character set start address register allows to select 8 blocks of 8k for the character generator memory,
located at the Video Bank 8.
In each 8k, there are two sets of character generators, of 4k each. The one to use is selected by the
VIA CA2 output pin as on the PET.


       Video    +----+ $090000
                |    |	      r28.7/6/5 -> 111, VIA CA2=1 
                +----+ $08f000
                |    |	      r28.7/6/5 -> 111, VIA CA2=0 
                +----+ $08e000	 
                |    |	      r28.7/6/5 -> 110, VIA CA2=1 
                +----+ $08d000
                |    |	      r28.7/6/5 -> 110, VIA CA2=0
                +----+ $08c000
                |    |	      r28.7/6/5 -> 101, VIA CA2=1
                +----+ $08b000
                |    |	      r28.7/6/5 -> 101, VIA CA2=0
                +----+ $08a000
                |    |	      r28.7/6/5 -> 100, VIA CA2=1
                +----+ $089000
                |    |	      r28.7/6/5 -> 100, VIA CA2=0
                +----+ $088000	 
                |    |	      r28.7/6/5 -> 011, VIA CA2=1 
                +----+ $087000	 
                |    |	      r28.7/6/5 -> 011, VIA CA2=0 
                +----+ $086000	 
                |    |	      r28.7/6/5 -> 010, VIA CA2=1 
                +----+ $085000	 
                |    |	      r28.7/6/5 -> 010, VIA CA2=0
                +----+ $084000	 
                |    |	      r28.7/6/5 -> 001, VIA CA2=1
                +----+ $083000	 
                |    |	      r28.7/6/5 -> 001, VIA CA2=0
                +----+ $082000	 
                |    |	      r28.7/6/5 -> 000, VIA CA2=1
                +----+ $081000	 
                |    |	      r28.7/6/5 -> 000, VIA CA2=0
                +----+ $080000
        
### Sprites

Please see the extensive VIC-II documentation for a description of the corresponding sprite registers

## Colour Palette

The colour palette is the same as the C128 VDC's.

- 0: black
- 1: dark grey
- 2: dark blue
- 3: light blue
- 4: dark green
- 5: light green
- 6: dark cyan
- 7: light cyan
- 8: dark red
- 9: light red
- A: dark purple
- B: light purple
- C: brown
- D: yellow
- E: light grey
- F: white

