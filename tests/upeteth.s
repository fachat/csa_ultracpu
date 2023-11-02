;
; ENC28J60 Driver (originally for SBC-3
; Written by Daryl Rictor (c) 2010)
;
; Adapted for CS/A NETUSB 2.0 by A. Fachat (2011)
; Adapted for UPET by A. Fachat (2023)
;

	.include	"enceth.inc"
;	.import	_uip_buf
;	.import	_mymac
;	.import	_uip_appdata
;	.import     _uip_len
;	.importzp	ptr1,ptr2
;	.export	_init_ether 
;	.export	_send_ether 
;	.export	_rcv_ether 

;
; constants
;

SPIeth	=  	4		; uses SPI Port 4 


;
; 65SPI register addresses (using a modified 65SPI for SBC-3)
;

SPIDR		:=	$e809	; SPI data port (write / peek)
SPIPEEK		:=	$e80a	; SPI data port (write / peek)
SPISR		:=	$e808	; SPI status
SPISSRB		:=	$e808	; SPI Device Select register (lower 3 bits)

		.zero
ptr1		.word 0
ptr2		.word 0

		.bss
_uip_len	.word 0
_uip_appdata	.word 0		; where to take the payload data to send
_uip_buf	.dsb 2048

		.data
_mymac		.word 1,2,3,4,5,6

.code

       .word $0401
       *=$0401

       .word link
       .word 10
       .byt $9e, "1040", 0
link    .word 0

       .dsb 1040-*, 0

	jsr _init_ether

	jsr _rcv_ether

	rts




;############################## Internal Functions ############################

;*********************************************************************
; Read ENC28J60 Control Register
; Address is X, return value in A
;
EthReadReg:
                jsr     enc_select
		TXA
		and	#ADDR_MASK		; mask address
		STA	SPIDR			; read address command
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
		lda	#$00			; dummy command
		STA	SPIDR			; send it
		txa
		and	#$80
		beq	@3
@2:		LDA	SPISR			; 
		bmi	@2			; wait for tx to end
		lda	#$00			; dummy read for MAC and MII regs
		STA	SPIDR			; send it
@3:		LDA	SPISR			; 
		bmi	@3			; wait for tx to end
		LDA	SPIPEEK			; read eth data
		pha				; save parm in
                jsr     enc_deselect
		pla
		rts

;*********************************************************************
; Read ENC28J60 Control Register
; Address is X, return value in A
;
EthReadRaw:
                jsr     enc_select
		TXA
		STA	SPIDR			; read address command
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
		lda	#$00			; dummy command
		STA	SPIDR			; send it
@2:		LDA	SPISR			; 
		bmi	@2			; wait for tx to end
		LDA	SPIPEEK			; read eth data
		pha				; save parm in
                jsr     enc_deselect
		pla
		rts

;*********************************************************************
; Write ENC28J60 Control Register
; Address is X, value in A
;
EthWriteReg:
		pha				; save value
                jsr     enc_select
		TXA
		and	#ADDR_MASK		; mask address
		ora	#$40			; write control reg
		STA	SPIDR			; read address command
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
		pla				; get value
		STA	SPIDR			; send it
@2:		LDA	SPISR			; 
		bmi	@2			; wait for tx to end
                jsr     enc_deselect
		rts

;*********************************************************************
; Write ENC28J60 raw
; command+Address is X, value in A
;
EthWriteRaw:
		pha				; save value
                jsr     enc_select
		TXA
		STA	SPIDR			; read address command
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
		pla				; get value
		STA	SPIDR			; send it
@2:		LDA	SPISR			; 
		bmi	@2			; wait for tx to end
                jsr     enc_deselect
		rts

;*********************************************************************
; Write ENC28J60 Page Register
; Page Address is X
;
EthWritePage:
                jsr     enc_select
		lda	#$BF			; bit field clear ECON1 command
		STA	SPIDR			; read address command
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
		lda	#$03			; clear bits 0 & 1
		STA	SPIDR			; send it
@2:		LDA	SPISR			; 
		bmi	@2			; wait for tx to end
		LDA	SPIPEEK			; read eth data
                jsr     enc_deselect
		txa
		rol				; shift 
		rol
		rol
		rol
		and	#$03			; mask page bits
		beq	@5			; if page=0, we're done
		pha
                jsr     enc_select
		lda	#$9F			; bit field set ECON1
		STA	SPIDR			; 
@3:		LDA	SPISR			; 
		bmi	@3			; wait for tx to end
		pla				; get value
		STA	SPIDR			; send it
@4:		LDA	SPISR			; 
		bmi	@4			; wait for tx to end
                jsr     enc_deselect
@5:		rts

;*********************************************************************
; Read buffer
; ptr1 = data pointer
; ptr2 = len
ReadBuffer:
		; 6502 only: save yr
		tya
		pha

                jsr     enc_select
		lda	#$3A			; read buffer mem command
		STA	SPIDR			; 
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end
@2:		lda	#$00			; dummy command
		STA	SPIDR			; send it
@3:		LDA	SPISR			; 
		bmi	@3			; wait for tx to end
		LDA	SPIPEEK			; read data
;---------- 6502 - 18 bytes
		ldy 	#$00
		sta 	(ptr1),y
inc 59521
		inc 	ptr1
		bne 	@4
		inc	ptr1+1
@4:		
		lda 	ptr2
		bne 	@5
		dec	ptr2+1
@5:		dec 	ptr2
		bne 	@2			; repeat until 0
		lda 	ptr2+1			; set Z-flag
;---------- 65816 - 10 bytes
;		sta	(ptr1)			; store it
;		rep	#$20			; 16 bit mode
;		inc	ptr1			; inc pointer
;		dec	ptr2            	; dec counter
;		sep	#$20			; 8 bit mode
;---------- 
		bne	@2			; repeat until 0
                jsr     enc_deselect

		; 6502 only - restore yr
		pla
		tay
		rts

;*********************************************************************
; Write buffer
; 
WriteBuffer:
		; 6502 only
		tya				; save yr
		pha

                jsr     enc_select
		lda	#$7A			; write buffer mem command
		STA	SPIDR			; 
@1:		LDA	SPISR			; 
		bmi	@1			; wait for tx to end

;---------- 6502 - 4 bytes
		ldy 	#$00
@2:		lda 	(ptr1),y
;---------- 65816 - 2 bytes
;@2:		lda	(ptr1)			; get data
;---------- 

		STA	SPIDR			; send it
@3:		LDA	SPISR			; 
		bmi	@3			; wait for tx to end

;---------- 6502 
		inc	ptr1
		bne 	@4
		inc	ptr1+1
@4:		
		lda 	ptr2
		bne 	@5
		dec	ptr2+1
@5:		dec	ptr2
		bne 	@2
		lda 	ptr2+1
;---------- 65816 
;		rep	#$20			; 16 bit mode
;		inc	ptr1			; inc pointer
;		dec	ptr2              ; dec counter
;		sep	#$20			; 8 bit mode
;---------- 

		bne	@2			; repeat until 0
                jsr     enc_deselect

		; 6502 only
		pla
		tay				; restore yr
		rts


;*********************************************************************
; PhyRead 
; address in X
; returns int in a,x
;
;PhyRead:
;		phx
;		ldx	#MIREGADR		; page 2	
;		jsr	EthWritePage	; 
;		pla
;		jsr	EthWriteReg		; write address to MIREGADR
;		ldx	#MICMD
;		lda	#MICMD_MIIRD	; read command
;		jsr	EthWriteReg
;		ldx	#MISTAT		; page 3
;		jsr	EthWritePage	
;@1:		jsr	EthReadReg		; MI status
;		and	#MISTAT_BUSY	
;		bne	@1			; wait for not busy
;		ldx	#MICMD		; page 2
;		jsr	EthWritePage
;		lda	#$00
;		jsr	EthWriteReg		; stop reading
;		ldx	#MIRDL
;		jsr	EthReadReg
;		pha
;		ldx	#MIRDH
;		jsr	EthReadReg
;		pha
;		ldx	#ERDPTL		; page 0
;		jsr	EthWritePage
;		plx
;		pla
;		rts

;*********************************************************************
; PHYWrite
; Address in X, data in a,y 
;
PhyWrite:
		pha
;---------- 6502
		txa
		pha 
;---------- 65816 
;		phx
;---------- 

		ldx	#MIREGADR		; page 2	
		jsr	EthWritePage	; 
		pla				; address
		jsr	EthWriteReg		; write address to MIREGADR
		pla
		LDX	#MIWRL
		jsr	EthWriteReg
		tya
		LDX	#MIWRH
		jsr	EthWriteReg
		ldx	#MISTAT		; page 3
		jsr	EthWritePage	
@1:		jsr	EthReadReg		; MI status
	sta $8026
	inc $8027
		and	#MISTAT_BUSY	
		bne	@1			; wait for not busy
		ldx	#ERDPTL		; page 0
		jsr	EthWritePage
		rts

;*********************************************************************
; delay ms delay milliseconds in A reg
;

;---------- 6502
delay_ms:
			pha
			txa
			pha
			tya
			pha
@1:			ldy 	#$01
			ldx 	#$c0
@2:			dex
			bne 	@2
			dey
			bne	@2
			tsx
			dec 	$0103,x			; the AC as saved on the stack
			bne 	@1
			pla
			tay
			pla
			tax
			pla
			rts
;---------- 65816
;delay_ms:		phx				; 
;			phy				;  1MHz clk = $01C0 
;@1:			ldy	#$06			;  2MHz clk = $0288 
;			ldx	#$90			;  4MHz clk = $0416 
;@2:			dex				;  8MHz clk = $0734 
;			bne	@2			; 10MHz clk = $08C3
;			dey				; 14MHz clk = $0BE0
;			bne	@2                ; 14.318MHz = $0C24
;			dec                     ; 7.159 Mhz = $0690
;			bne	@1
;			ply
;			plx
;			rts
;---------- 

;*********************************************************************
; select/deselect ENC28J60 chip on SPI

enc_select:		;lda #15-SPIeth
			lda #SPIeth
			sta SPISSRB
			rts

enc_deselect:		lda #0
			sta SPISSRB
			rts


;############################## External Functions ############################

;*********************************************************************
; _init_ether
; 
_init_ether:
		; init SPI interface
;		lda 	#$04		; ECE - external clock enable
;		sta	SPICR
;		lda	#2
;		sta 	SPIDIV
inc $8000
lda #41
sta 59520
inc 59521
		jsr enc_select
		lda #%01011110		; write control reg. ECON2
		sta SPIDR
@1:		lda SPISR
		bmi @1
		lda #0			; clear powersave mode
		sta SPIDR
@2:		lda SPISR
		bmi @2
		jsr enc_deselect

		; init ENC28J60

inc $8001
		ldx	#ERDPTL		; page 0
		jsr	EthWritePage

		; perform system reset
		jsr 	enc_select
		lda	#ENC_SOFT_RESET
		STA	SPIDR			; soft reset command
@3:		LDA	SPISR			; 
		bmi	@3			; wait for tx to end
                jsr     enc_deselect

		lda	#$01
		jsr	delay_ms		; wait 1 ms

		ldx	#ESTAT
@4:		jsr	EthReadReg		; wait for end of reset
		and	#ESTAT_CLKRDY
		beq	@4

		; do bank 0 stuff
		; initialize receive buffer
		; 16-bit transfers, must write low byte first
		lda	#<RXSTART_INIT
		ldx	#>RXSTART_INIT
		sta	NextPacketPtr
		stx	NextPacketPtr+1

		; set receive buffer start address
		lda	#<RXSTART_INIT
		ldx	#ERXSTL
		jsr	EthWriteReg
		lda	#>RXSTART_INIT
		ldx	#ERXSTH
		jsr	EthWriteReg
		
		; set receive read pointer address
		lda	#<RXSTART_INIT
		ldx	#ERXRDPTL
		jsr	EthWriteReg
		lda	#>RXSTART_INIT
		ldx	#ERXRDPTH
		jsr	EthWriteReg

		; set receive write pointer address
		lda	#<RXSTART_INIT
		ldx	#ERXWRPTL
		jsr	EthWriteReg
		lda	#>RXSTART_INIT
		ldx	#ERXWRPTH
		jsr	EthWriteReg

		; set receive buffer end
		; ERXND defaults to 0x1FFF (end of ram)
		lda	#<RXSTOP_INIT
		ldx	#ERXNDL
		jsr	EthWriteReg
		lda	#>RXSTOP_INIT
		ldx	#ERXNDH
		jsr	EthWriteReg

		; set transmit buffer start
		; ETXST defaults to 0x0000 (beginnging of ram)
		lda	#<TXSTART_INIT
		ldx	#ETXSTL
		jsr	EthWriteReg
		lda	#>TXSTART_INIT
		ldx	#ETXSTH
		jsr	EthWriteReg

		; do bank 1 stuff
		LDX	#ERXFCON
		JSR	EthWritePage
		lda	#$A1			; default setting
		jsr	EthWriteReg

		; do bank 2 stuff
		; enable MAC receive
		LDX	#MACON1
		JSR	EthWritePage
		lda	#MACON1_MARXEN + MACON1_TXPAUS + MACON1_RXPAUS
		jsr	EthWriteReg

		; bring MAC out of reset
		ldx	#MACON2	;*** this reg not in PDF????
		lda	#$00
		jsr	EthWriteReg

		; enable automatic padding and CRC operations
		ldx	#ENC_BIT_FIELD_SET + (MACON3 & $1F) 
		lda	#MACON3_PADCFG0 + MACON3_TXCRCEN + MACON3_FRMLNEN
		jsr	EthWriteRaw

		; set inter-frame gap (non-back-to-back)
		ldx	#MAIPGL
		lda	#$12
		jsr	EthWriteReg
		ldx	#MAIPGH
		lda	#$0C
		jsr	EthWriteReg

		; set inter-frame gap (back-to-back)
		ldx	#MABBIPG
		lda	#$12
		jsr	EthWriteReg

		; Set the maximum packet size which the controller will accept
		ldx	#MAMXFLL
		lda	#<MAX_FRAMELEN
		jsr	EthWriteReg
		ldx	#MAMXFLH
		lda	#>MAX_FRAMELEN
		jsr	EthWriteReg

		; do bank 3 stuff
		; write MAC address
		; NOTE: MAC address in ENC28J60 is byte-backward
		ldx	#MAADR5
		jsr	EthWritePage
		lda	_mymac
		jsr	EthWriteReg
		ldx	#MAADR4
		lda	_mymac+1
		jsr	EthWriteReg
		ldx	#MAADR3
		lda	_mymac+2
		jsr	EthWriteReg
		ldx	#MAADR2
		lda	_mymac+3
		jsr	EthWriteReg
		ldx	#MAADR1
		lda	_mymac+4
		jsr	EthWriteReg
		ldx	#MAADR0
		lda	_mymac+5
		jsr	EthWriteReg

		; no loopback of transmitted frames
		ldx	#PHCON2			; moves to page 2
		lda	#<PHCON2_HDLDIS
		ldy	#>PHCON2_HDLDIS
		jsr	PhyWrite			; returns on page 0

		; switch to bank 0 (done above)
		; enable interrutps
		; EDIT: Don't - not handled in this code, and directly creates CPU int
		;ldx	#ENC_BIT_FIELD_SET + EIE
		;lda	#EIE_INTIE + EIE_PKTIE
		;jsr	EthWriteRaw

		; enable packet reception
		ldx	#ENC_BIT_FIELD_SET + ECON1
		lda	#ECON1_RXEN
		jsr	EthWriteRaw
inc $8002
		rts

;*********************************************************************
; _send_ether
; 
_send_ether:
		;  test minimum packet length
		lda	#$3C
		ldx	_uip_len+1
		bne	@05
		cmp	_uip_len
		bcc	@05			; len > 3C
		sta	_uip_len
@05:		
		; set _uip pointers
		lda	#<_uip_buf
		ldx	#>_uip_buf
		sta	ptr1
		stx	ptr1+1

		lda	_uip_len
		ldx	_uip_len+1
		sta	ptr2
		stx	ptr2+1

		; Set the write pointer to start of transmit buffer area
		ldx	#EWRPTL
		lda	#<TXSTART_INIT
		jsr	EthWriteReg
		ldx	#EWRPTH
		lda	#>TXSTART_INIT
		jsr	EthWriteReg

		; Set the TXND pointer to correspond to the packet size given
		clc
		lda	ptr2
		adc	#<TXSTART_INIT
		tay
		lda	ptr2+1
		adc	#>TXSTART_INIT		
		pha
		ldx	#ETXNDL
		tya
		jsr	EthWriteReg
		ldx	#ETXNDH
		pla
		jsr	EthWriteReg

		; write per-packet control byte
		ldx	#ENC_WRITE_BUF_MEM
		lda	#$00
		jsr	EthWriteRaw

		; we send header and user data seperately
		sec
		lda	ptr2
		sbc	#54			; ETH hdr len + IP hdr len
		pha				 
		lda	ptr2+1
		sbc	#0
		pha

		; copy the packet headers into the transmit buffer
		lda	#54
		sta	ptr2
;-------- 6502
		lda 	#$00
		sta	ptr2+1
;-------- 65816
;		stz	ptr2+1
;-------- 
		jsr	WriteBuffer

		; set data pointer to the uip_appdata pointer
		lda	_uip_appdata
		sta	ptr1
		lda	_uip_appdata+1
		sta	ptr1+1

		; set user data len
;-------- 6502
		pla
		tax
;-------- 65816
;		plx
;-------- 
		pla
		sta	ptr2
		stx	ptr2+1

		; copy the packet into the transmit buffer
		jsr	WriteBuffer
	
		; send the contents of the transmit buffer onto the network
		ldx	#ENC_BIT_FIELD_SET + ECON1
		lda	#ECON1_TXRTS
		jsr	EthWriteRaw
		rts

;*********************************************************************
; _rcv_ether
; buffer pointer in a,x, maxlen on stack
;
_rcv_ether:
		; check if a packet has been received and buffered
		ldx	#EPKTCNT
		jsr	EthWritePage		; page 1
		jsr	EthReadReg
		cmp	#$00
		bne	@1
		ldx	#ERDPTL
		jsr	EthWritePage		; page 0
;-------- 6502
		lda	#$00
		sta	_uip_len
		sta	_uip_len+1			; mark no data
;-------- 65816
;		stz	_uip_len
;		stz	_uip_len+1			; mark no data
;		lda	#$0
;-------- 
inc $8022
		tax
		rts
@1:
	inc $8023
		; set _uip pointers
		lda	#<_uip_buf
		ldx	#>_uip_buf
		sta	ptr1
		stx	ptr1+1

		; Set the read pointer to the start of the received packet
		ldx	#ERDPTL
		jsr	EthWritePage		; page 0
		lda	NextPacketPtr
		jsr	EthWriteReg
		ldx	#ERDPTH
		lda	NextPacketPtr+1
		jsr	EthWriteReg

		; read the next packet pointer
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw
		sta	NextPacketPtr
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw
		sta	NextPacketPtr+1

		; read the packet length
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw
		sta	ptr2
sta $8020
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw
		sta	ptr2+1
sta $8021
cmp #2
bcc @xx
lda #1
@xx:
		; dec len by 4 to ignore crc
		sec
		lda	ptr2
		sbc	#$04
		sta	ptr2
		sta	_uip_len
		lda	ptr2+1
		sbc	#$00
		sta	ptr2+1
		sta	_uip_len+1			; save length

		; read and ignore the receive status
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw
		ldx	#ENC_READ_BUF_MEM
		jsr	EthReadRaw

		; copy the packet from the receive buffer
		jsr	ReadBuffer

		; Move the RX read pointer to the start of the next received packet
		; This frees the memory we just read out
		ldx	#ERXRDPTL
		lda	NextPacketPtr
		jsr	EthWriteReg
		ldx	#ERXRDPTH
		lda	NextPacketPtr+1
		jsr	EthWriteReg

		; decrement the packet counter indicate we are done with this packet
		ldx	#ENC_BIT_FIELD_SET + ECON2
		lda	#ECON2_PKTDEC
		jsr	EthWriteRaw

		ldx	_uip_len+1
		lda	_uip_len
		rts

;*********************************************************************
;EthOvfRec
;
EthOvfRec:

		; not implemented

		rts

;************************************************************************

.data
NextPacketPtr: 	.byte  0,0			; word
