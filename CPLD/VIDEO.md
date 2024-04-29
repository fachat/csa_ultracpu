
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

- r1: HDISP: horizontal displayed - defines how many characters are displayed on a character row. (CRTC)
  - note: if upet compatibility (r32.7) is set, this is always for 40 columns even if in 80 column mode.
- r5: HDISP_MM: if registers are memory-mapped (r32.6 = 1), same as r1.
- r6: VDISP: vertial displayed - the number of character rows displayed in a frame (CRTC)
- r8: MODE: mode register
  - bit 7: 1=80 columns
    - TODO: see r22
  - bit 1-0: 
    - 0x= normal display
    - 10= interlace (show every scanline twice, i.e. r9 is effectivly twice its value)
    - 11= double vertical resolution
- r9: CHEIGHT: (bits 3-0) scan lines per character - 1 (CRTC)
  - note: in upet compat mode, also sets vertical position (r45)
- r10: CRSR_STRT: cursor start scan line:  (CRTC)
  - bits 4-0: number of scan line where reverse video cursor starts (0=top)
  - bits 6-5: 
    - 00: solid cursor
    - 01: cursor off
    - 10: blink at 1/16th of the frame rate
    - 11: blink at 1/32th of the frame rate
- r11: CRSR_END: cursor end scan line + 1 (CRTC)
- r12: MEM_STRT_H: start of video memory high (CRTC)
  - note: if upet compat mode, high bit (A15) is inverted
  - note: if r40.0 is set, accesses the alternate video base address
- r13: MEM_STRT_L: start of video memory low (CRTC)
  - note: if r40.0 is set, accesses the alternate video base address
- r14: CRSR_POS_H: cursor position high (CRTC)
  - note: if upet compat mode, high bit (A15) is inverted
- r15: CRSR_POS_L: cursor position low (CRTC)
- r20: ATT_STRT_H: attribute start address high (VDC)
  - note: if r40.0 is set, accesses the alternate attribute base address
- r21: ATT_STRT_L: attribute start address low (VDC)
  - note: if r40.0 is set, accesses the alternate attribute base address
- r22: CHR_HDISP: Horizontal displayed pixel per char
  - bits 3-0: displayed: number of bits displayed from the character definition (not VDC!)
  - bits 7-4: n/a (note, in VDC this is total number of horizontal bits timed for a char, -1. But here fixed to 7)
- r23: CHR_VDISP: character displayed vertical: number of scan lines -1 of the displayed part of a character (VDC)
- r24: VSCRL: vertical smooth scroll (partly VDC, scroll similar to VIC-II)
  - bits 3-0: number of scan lines to scroll the screen up
  - bit 4: RSEL: if set, extend upper and lower border 4 scanlines into the display window, or 8 scanlines if r9 > 7
  - bit 5: character blink rate - 0 blinks characters in 1/16th frame rate, 1 in 1/32th (VDC)
  - bit 6: reverse screen - exchange foreground and background colours when set (VDC)
- r25: HSCRL: horizontal smooth scroll (partly VDC, scroll similar to VIC-II)
  - bits 3-0: number of pixels to shift the output to the right
  - bit 4: CSEL: if set, extend left border by 8 pixels and right border by 8 pixels
    - TODO: according to https://www.c64-wiki.de/wiki/VDC bit4=1 is 40 col mode
  - bit 5: unused (semigraphic mode (display the last pixel of a char in the intercharacter spacing, instead of background))
    - TODO: implement together with parts of R22
  - bit 6: attribute enable (VDC)
  - bit 7: bitmap mode (hires)
- r26: FGBG_COLS: default colours (VDC, not in full colour modes, other restrictions see video modes below))
  - bits 3-0: background color
  - bits 7-4: foreground color
- r27: ROW_INC: address increment per row: add this to the memory address after each character row (VDC)
- r28: CSET_STRT_H: character set start address
  - bits 7-5: character generator address bits A13-A15. (VDC)
- r29: ULINE: underline scan line count (VDC)

- r30: RLINE_L: read: rasterline counter low (bits 0-7); write: rasterline match value
- r31: RLINE_H: read: rasterline counter high (bits 0-1); write: rasterline match value

- r32: CTRL: control register
  - bit 1-0: -
  - bit 2: extended mode (enable full and multicolor text modes)
  - bit 4: DEN: display enable
  - bit 5: palette select (0 = lower half of palette in R88-R95, 1 = upper half) 
  - bit 6: if set, map registers into memory (see below)
  - bit 7: Micro-PET compatible (see r1)

- r33: EXT_BGCOLS: extended background colour 
  - bits 3-0 background colour 1
  - bits 7-4 background colour 2
- r34: BRDR_COL: border colour
  - bits 3-0: border colour
- r35: IRQ_CTRL: IRQ control (VIC-II)
  - bit 0: raster match enable
  - bit 1: sprite/bitmap collision enable
  - bit 2: sprite/sprite collision enable
  - bit 3: sprite/border collision enable
  - bit 7-4: unused
- r36: IRQ_STAT: IRQ status; read the interrupt status. Clear by writing 1s into relevant bits (VIC-II)
  - bit 0: raster match occured
  - bit 1: sprite/bitmap collision occured
  - bit 2: sprite/sprite collision occured
  - bit 3: sprite/border collision occured
  - bit 6-4: unused
  - bit 7: one when interrupt has occurred
- r37: SYNC: sync status
  - bit 5: vsync
  - bit 6: hsync

- r38: HPOS: horizontal position (in chars); replaces r2
  - bit 0-6, defaults to 21 (on 70 MHz)
- r39: VPOS: vertical position (in rasterlines) of start of raster screen; replaces r7
  - bit 0-7, defaults to 110 (so 25 rows with 8 rasterlines/char are centered on screen); in upet compat mode, gets set when r9 is written
- r40: ALT1: alternate register control I
  - bit 0: if set, enable access to alternate r12/r13 video memory, r20/r21 attribute memory addresses, and r88-95 alternate palette
  - bit 1: alternate bitmap mode bit
  - bit 2: alternate attribute mode bit
  - bit 3: alternate extended mode bit
  - bit 4: if set, set palette to alternate palette on raster match - reset to original palette at start of screen 
  - bit 5: if set, set bitmap, attribute and extended mode bits to alternate values on raster match - reset to orig values at start of screen
  - bit 6: if set, set attribute address memory counter to alternate address on raster match (r38/39) - reset to orig values at start of screen
  - bit 7: if set, set video memory address counter to alternate address on raster match (r38/39) - reset to orig values at start of screen
- r41: ALT2: alternate register control II
  - bit 0-3: alternate raster row counter for a character cell
  - bit 7: if set, set the raster row counter to alternate value on raster match

Sprite registers (subject to change):

- r42: SPRT_BASE: sprite block base (high)
  - top 8 bytes in page given here are sprite pointers
  - in addition, bits 7/6 are bits 15/14 of sprite data base address
  - initializes to $97, so mapped pointers are at $87f8-$87ff

- r43: SPRT_BRDR: sprite-border collision 
- r44: SPRT_SPRT: sprite-sprite collision (VIC-II) 
- r45: SPRT_RSTR: sprite-data collision (VIC-II) 

- r46: SPRT_MCOL1: sprite multicolor 0 (VIC-II)
- r47: SPRT_MCOL2: sprite multicolor 1 (VIC-II)

- r48-51: VCCY_SPRT_BASE_0: Sprite 0
- r48: X coordinate sprite 0 (VIC-II)
  - note: X coordinates are 2x2 pixels in 40 column modes, except fine mode is set (r51.6)
- r49: Y coordinate sprite 0 (VIC-II)
  - note: Y coordinates are 2x2 pixels in non-double modes (r8.0/1 != "11"), except fine mode is set (r51.6)
- r50: sprite 0 extra
  - bit 1-0: bits 8-7 of sprite 0 X coordinate (80 cols/fine) / bit 0 only in 40 col modes
  - bit 5-4: bits 8-7 of sprite 0 Y coordinate (double resolution/fine) / bit 4 only if non-double modes
  - note: X coordinates are 2 pixels wide in 40 column modes, except fine mode is set (r51.6)
  - note: Y coordinates are 2 pixel rows high in non-double-resolution modes (r8.0/1 != "11"), except fine mode is set (r51.6)
- r51: sprite 0 control
  - bit 0: enable
  - bit 1: X-expand
  - bit 2: Y-expand
  - bit 3: Multicolour flag
  - bit 4: sprite data priority: if set high, background overlays the sprite
  - bit 5: sprite border flag (if set, show sprite over border)
  - bit 6: if set, use 80 col (X) / double resolution (Y) coordinates
- r52-: SPRT_BASE_1: sprite 1
- r56-: SPRT_BASE_2: sprite 2
- r60-: SPRT_BASE_3: sprite 3
- r64-: SPRT_BASE_4: sprite 4
- r68-: SPRT_BASE_5: sprite 5
- r72-: SPRT_BASE_6: sprite 6
- r76-: SPRT_BASE_7: sprite 7

- r80: SPRT_COL_0: color sprite 0 (VIC-II)
- r81: SPRT_COL_1: color sprite 1 (VIC-II)
- r82: SPRT_COL_2: color sprite 2 (VIC-II)
- r83: SPRT_COL_3: color sprite 3 (VIC-II)
- r84: SPRT_COL_4: color sprite 4 (VIC-II)
- r85: SPRT_COL_5: color sprite 5 (VIC-II)
- r86: SPRT_COL_6: color sprite 6 (VIC-II)
- r87: SPRT_COL_7: color sprite 7 (VIC-II)

Palette registers:

- r88 - r95: 8 out of 16 palette entries. Which half of the registers is determined by r32.5

### Memory-mapped registers

If r32.6 is set, then the registers are not only accessible via the standard two bytes interface (and the extended 4 byte interface described above), but also mapped into I/O memory from $E884-$E8DF. The register number directly translates to the address by calculating $E880 + regnumber.

Note that the first four registers would not be available as memory-mapped. However, only register 1 is implemented for compatibility with the (Micro-) PET. Thus, register 1 is then directly accessible on address $E885 (as $E881 is still occupied by the 4 address interface).

## CRTC/VDC emulation

The Video code (partially) emulates only a subset of the CRTC registers, as given 
in the register description above.

As usual with the CRTC, you have to write the register number to $e880 (59520),
the write the value to write to the register to $e881 (59521). 
Alternatively, you can use register $e883 to read or write a CRTC register - but when you access it, the index register 
increases by one. This allows setting multiple consecutive values without having to reload the index register.

The video code emulates some kind of hybrid between the C128 VDC (which basically includes
the CRTC registers), the PET CRTC, and the C64 VIC-II. PET CRTC emulation is made as good as possible as makes sense
with a VGA timing running in the background. VDC is partially emulated, and features coming from the VIC-II are separate.

## Video modes

The following video modes are supported

### Text modes

For all the text modes, the hires bit in r25.7 must be zero.

1. single colour text mode (VDC/CRTC)

In this mode, extended mode and attribute memory are disabled in R33 and R25 respectively.

Each character data is read from character memory, and used as index in the character generator memory.
The data from the character generator memory is shifted out, using foreground (1-pixels) or background (0-pixels) colours
from R26.

This basically emulates a simple b/w screen, just with colours adjustable via R26.

2. attribute colour text mode (VDC)

This is the VDC's attribute colour mode. To achieve this, extended mode bit r33.2 must be 0, and attribute enable bit r25.6 must be 1.

Together with the character value an attribute value is being read from video memory.
This attribute byte contains the following bits:

- bit 7: alternate character set
- bit 6: reverse video attribute bit
- bit 5: underline attribute bit
- bit 4: blink attribute bit
- bit 3-0: foreground colour

Using the additional alternate character set bit from the attribute byte, the character bit value is loaded from memory
and streamed out. 1-bits get the foreground colour from the attribute byte. 0-bits get the background colour from r26.

Note, that the alternate character set bit and the graphics output from the VIA CA2 are XOR'd.

3. full colour text mode (ColourPET)

This is the Colour-PET video mode. To achieve it, the extended mode bit r33.2 must be set, and the attribute enable bit r25.6 must be 0.

In this mode, again character value and attributes are loaded from memory. The attribute byte contains the following information:

- bits 3-0: foreground colour
- bits 7-4: background colour

There is no alternate character set bit in the attribute byte, only VIA CA2 is used as usual in the PET. 
After reading the character bit data, it is streamed out using the foreground colour (for 1-bits) and 
background colour (for the 0-bits) from the attribute byte.

4. multicolour mode (partly VIC-II, partly VDC)

This mode is an extension to the C64's multicolour text mode, utilizing the additional bits in the attribute memory compared to the VIC-II's 4-bit video memory.

Character data and attribute data are being fetched. The attribute byte contains the following bits:

- bit 7: alternate character set
- bit 6: reverse video attribute bit (mc=0)
- bit 5: multicolour bit (mc)
- bit 4: blink attribute bit (mc=0)
- bit 3-0: foreground colour

Note the different meaning of bit 5 - it is used to disable multicolour for that character, or enable it.
With disabled multicolour the character is displayed as in attribute colour text mode, except there is no underline bit. 
With enabled multicolour bit, the character bits are fetched (alternate character set as in attribute colour text mode).
When streaming, two bits are lumped together and evaluated to give these colours:

- 00: background colour register r26
- 01: background colour 1 register r34
- 10: background colour 2 register r34
- 11: foreground colour from attribute byte

### High Resolution Modes

For all the hires modes, the hires bit in r25.7 must be set.

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

There are two Micro-PET control ports that affect video operation as well, and relate to the integration of the
Video output into the system architecture.

#### $e800 (59392) Video Control

- Bit 0: unused - must be 0
- Bit 1: 0= 40 column display, 1= 80 column display (OR'd with the Viccy register value from above)
- Bit 2: 0= screen character memory in bank 0, 1= character memory only in video bank (see memory map)
- Bit 3-6: unused - must be 0
- Bit 7: 0= video enabled; 1= video disabled

Note, that bit 1 (40/80 column) is deprecated and will be removed once the firmware gets updated
to actually use the Viccy registers.

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

#### $e802 (59394) Bank Control

This register allows re-mapping memory maps in bank 0:

- Bit 0-3: map the low 32k in bank 0 to any of the 16 32k pages in the 512k Fast RAM area
- Bit 4-6: map the 2k video window at $8000 and the 2k colour RAM window at $8800 as described below
- Bit 7: unused, must be 0

The three bits in the video map allow for eight configurations. These determine where in 
the video bank ($08xxxx) the video window at $008xxx is mapped:

  - $80xx
  - $88xx
  - $90xx
  - $98xx
  - $a0xx
  - $a8xx
  - $b0xx
  - $b8xx

Note that the colour RAM window at $8800-$8fff maps correspondingly to start at
  - $c0xx
  - $c8xx
  - ...
  - $f8xx

Note, that this register may in a future release be separated from the memory bank register.

### Video memory mapping

The video memory is defined as follows:

#### Character mode

In character mode (see control port below) two memory areas are used:

1. Character memory (r12/r13) and
2. Character pixel data (usually "character ROM") (r28)
3. Character attribute data (r20/r21)

Character memory is mapped to bank 0 at boot, but can be unmapped and only be available in bank 8 (VRAM) using the control port
The address of the character memory in the video bank can be set with registers r12/r13.

The character attribute data address in the video bank can be set with registers r20/r21.

Note that for "usual" operation, it makes most sense to map the character and attribute data to places
in the video bank that can be mapped to the video windows at $8xxx in bank 0 with the control register described
above.

Typically the display is either 80 or 40 columns with 25 lines. 
Using other values for character cell height, character cell count, or characters displayed per line, this
area can be modified in certain ranges. 
As long as the ranges fit into the given 640x480 pixels of the VGA canvas, they will be displayed.
Anything outside the defined ranges will be displayed in border colour.

The character set is 8k in size: two character sets of 4k each, switchable with the 
VIA I/O pin given to the CRTC as in the PET. 
Note that each character occupies 16 bytes (not 8 as in the typical
Commodore character set), so the 9th (or more) rasterlines for a character may be used.
Character set data can be mapped to the full video bank in steps of 8k via register R28.

#### Hires mode

Hires mode is available in 40 as well as 80 "column" mode, i.e. mainly either in 320x200 or 640x200 pixels.
Using other values for character cell height, character cell count, or characters displayed per line, this
area can be modified. See comments on ranges above.

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

The Sprites feature has been inspired by the VIC-II sprites.
Please see the extensive VIC-II documentation for a description and base understanding of the corresponding sprite registers

The sprite registers have been re-arranged a bit to allow for a more modular VHDL implementation.
Each sprite has a block of four registers (plus a separate colour register):

- 0: X coordinate sprite 0 (VIC-II)
  - note: X coordinates are 2x2 pixels in 40 column modes, except fine mode is set (r51.6)
- 1: Y coordinate sprite 0 (VIC-II)
  - note: Y coordinates are 2x2 pixels in non-double modes (r8.0/1 != "11"), except fine mode is set (r51.6)
- 2: sprite 0 extra
  - bit 1-0: bits 8-7 of sprite 0 X coordinate (80 cols/fine) / bit 0 only in 40 col modes
  - bit 5-4: bits 8-7 of sprite 0 Y coordinate (double resolution/fine) / bit 4 only if non-double modes
- 3: sprite 0 control
  - bit 0: enable
  - bit 1: X-expand
  - bit 2: Y-expand
  - bit 3: Multicolour flag
  - bit 4: sprite data priority: if set high, background overlays the sprite
  - bit 5: sprite border flag (if set, show sprite over border)
  - bit 6: if set, use 80 col (X) / double resolution (Y) coordinates

The registers 0, 1, and 2 determine the position of the sprite on the screen. As the VGA canvas size allows for finer positioning,
both coordinates X and Y overflow bits from register 0 or 1 respectively to register 2.

The control bits have been combined into register 3. A sprite can be enabled, expanded in X and/or Y direction as in the VIC-II.
Also the multicolour mode can be set.

The sprite data priority determines, as in the VIC-II, if the sprite displays above the raster data (character or hires data).
The sprite border flag determines, if the sprite is being shown on top of the border - so, no need to "open borders" to get sprites in the border :-)

In 40 column and single Y-resolution modes, the X and Y coordinates count two pixels in their respective direction in relation to the VGA zero coordinate.
In 80 column mode the Y coordinate counts single VGA pixels. This can also be achieved in 40 columns by setting the "fine resolution" bit 6 in the control register 3.
In 25 (character) row mode, the screen shows 200 raster lines on top of 400 VGA raster lines. The raster lines "in between" are either not shown (dark) or show the same line again depending on r8.0/1. Therefore the Y coordinate also only counts in increments of two VGA rasterlines. In 50 row mode (r8.0/1 = "11"), 400 real rasterlines are shown with separate data - so the sprite Y coordinate also counts single VGA raster lines. This can also be achieved in 25 row mode by setting the "fine resolution" bit 6 in the control register 3.

#### Sprite Mapping

Similar to the VIC-II, the Viccy reads pointers to sprite data before fetching the actual sprite data.
The VIC-II has a fixed screen size, so the address where the sprite pointers are read from can be easily defined as the last bytes in the screen memory.
The Viccy's geometry is much more flexible, so the pointer address needs to be defined separately. This is done with register r42.
R42 defines the page in the video bank that contains the 8 sprite data pointers in its top 8 bytes.

Each sprite data pointer defines address bits 6-13, so it points to a 64 byte block (of which 63 are used for sprite data). 
The uppermost two address bits 14 and 15 for the sprite data are also taken from r42, from bits 6 and 7.


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

