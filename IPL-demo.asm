; main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

.include "defs.asm"
.include "ram.asm"
.include "constants.asm"

.segment "PRG_DAT"
; reset handler
Reset:
		lda FDS_CTRL_MIRROR								; get setting previously used by FDS BIOS
		and #$f7										; and set for vertical mirroring
		sta FDS_CTRL
		
		lda #$80										; pick NMI #2
		sta NMI_FLAG
		
		lda #$00										; clear RAM
		tax
@clrmem:
		sta $00,x
		cpx #4											; preserve BIOS stack variables at $0100~$0103
		bcc :+
		sta $100,x
:
		inx
		bne @clrmem
		jsr InitNametables

		lda #%10000000									; enable NMIs & change background pattern map access
		sta PPU_CTRL_MIRROR
		sta PPU_CTRL
		
Main:
		jsr ProcessBGMode
		jsr WaitForNMI
		beq Main										; back to main loop
		
; NMI handler
NonMaskableInterrupt:
		bit NMIRunning									; exit if NMI is already in progress
		bmi InterruptRequest
		
		sec
		ror NMIRunning									; set flag for NMI in progress
		
		pha												; back up A/X/Y
		txa
		pha
		tya
		pha
		
		lda NMIReady									; check if ready to do NMI logic (i.e. not a lag frame)
		beq NotReady
		
		lda NeedDraw									; transfer Data to PPU if required
		beq :+
		
		jsr WriteVRAMBuffer								; transfer data from VRAM buffer at $0302
		jsr SetScroll									; reset scroll after PPUADDR writes
		dec NeedDraw
		
:
		lda NeedPPUMask									; write PPUMASK if required
		beq :+
		
		lda PPU_MASK_MIRROR
		sta PPU_MASK
		dec NeedPPUMask

:
		dec NMIReady
		jsr ReadOrDownPads								; read controllers + expansion port

NotReady:
		jsr SetScroll									; remember to set scroll on lag frames
		
		pla												; restore X/Y/A
		tay
		pla
		tax
		pla
		
		asl NMIRunning									; clear flag for NMI in progress before exiting
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

EnableRendering:
		lda #%00001010									; enable background and queue it for next NMI
	.byte $2c											; [skip 2 bytes]
		
DisableRendering:
		lda #%00000000									; disable background and queue it for next NMI

UpdatePPUMask:
		sta PPU_MASK_MIRROR
		lda #$01
		sta NeedPPUMask
		rts

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$24										; top-right

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

NumToChars:												; converts A into hex chars and puts them in X/Y
		pha
		and #$0f
		tay
		lda NybbleToChar,y
		tay
		pla
		lsr
		lsr
		lsr
		lsr
		tax
		lda NybbleToChar,x
		tax
		rts

NybbleToChar:
	.byte "0123456789ABCDEF"

; uses CRC32 calculation routine from https://www.nesdev.org/wiki/Calculate_CRC32
CheckIPL:
		lda #$00										; init pointer
		sta IPLPtr
		tay
		lda #$02
		sta IPLPtr+1
		
@crc32init:
		ldx #3
		lda #$ff
@c3il:
		sta testcrc+0,x
		dex
		bpl @c3il
		
@CalcCRC32:
		lda (IPLPtr),y
@crc32:
		ldx #8
		eor testcrc+0
		sta testcrc+0
@c32l:
		lsr testcrc+3
		ror testcrc+2
		ror testcrc+1
		ror testcrc+0
		bcc @dc32
		lda #$ed
		eor testcrc+3
		sta testcrc+3
		lda #$b8
		eor testcrc+2
		sta testcrc+2
		lda #$83
		eor testcrc+1
		sta testcrc+1
		lda #$20
		eor testcrc+0
		sta testcrc+0
@dc32:
		dex
		bne @c32l

		inc IPLPtr
		bne @CalcCRC32
		inc IPLPtr+1
		lda IPLPtr+1
		cmp #$08
		bne @CalcCRC32

@crc32end:
		ldx #3
@c3el:
		lda #$ff
		eor testcrc+0,x
		sta testcrc+0,x
		dex
		bpl @c3el

		lda testcrc+3
		jsr NumToChars
		stx CRC32+0
		sty CRC32+1
		lda testcrc+2
		jsr NumToChars
		stx CRC32+2
		sty CRC32+3
		lda testcrc+1
		jsr NumToChars
		stx CRC32+4
		sty CRC32+5
		lda testcrc+0
		jsr NumToChars
		stx CRC32+6
		sty CRC32+7
		rts

WaitForNMI:
		inc NMIReady
:
		lda NMIReady
		bne :-
		rts

; Jump table for main logic
ProcessBGMode:
		lda BGMode
		jsr JumpEngine
	.addr BGInit
	.addr DoNothing

; Initialise background to display the program name and FDS BIOS revision
BGInit:
		jsr CheckIPL ; IPL occupies $0200~$07ff
		jsr DisableRendering
		jsr WaitForNMI
		jsr VRAMStructWrite
	.addr BGData
		inc BGMode
		jmp EnableRendering								; remember to enable rendering for the next NMI

DoNothing:
		rts

BGData:													; VRAM transfer structure
Palettes:
	.byte $3f, $00										; destination address (BIG endian)
	.byte %00000000 | PaletteSize						; d7=increment mode (+1), d6=transfer mode (copy), length

; Just write to all of the entries so PPUADDR safely leaves the palette RAM region
; (palette entries will never be changed anyway, so we might as well set them all)
PaletteData:
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20 ; PPUADDR ends at $3F20 before the next write (avoids rare palette corruption)
PaletteSize=*-PaletteData

TextData:
	.byte $20, $8C										; destination address (BIG endian)
	.byte %00000000 | Text1Length						; d7=increment mode (+1), d6=transfer mode (copy), length
	
Chars1:
	.byte "IPL-demo"
Text1Length=*-Chars1

	.byte $20, $a9										; destination address (BIG endian)
	.byte %00000000 | Text2Length						; d7=increment mode (+1), d6=transfer mode (copy), length
	
Chars2:
	.byte "CRC32: "
CRC32:
	.byte "FFFFFFFF"
Text2Length=*-Chars2
	.byte $ff											; terminator


; FDS vectors
.segment "VECTORS"
.addr NonMaskableInterrupt
.addr NonMaskableInterrupt
.addr Bypass ; default, used by Namco IPL
.addr Reset
.addr InterruptRequest
