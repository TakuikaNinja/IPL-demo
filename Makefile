GAME=IPL-demo
ASSEMBLER=ca65
LINKER=ld65

OBJ_FILES=$(GAME).o

all: $(GAME).hex

$(GAME).hex : $(OBJ_FILES)  $(GAME).cfg
	$(LINKER) -o $(GAME).bin -C $(GAME).cfg $(OBJ_FILES) -m $(GAME).map.txt -Ln $(GAME).labels.txt --dbgfile $(GAME).dbg
	bin2hex.py --offset=0x6000 $(GAME).bin prg.hex
	bin2hex.py --offset=0x2000 Jroatch-chr-sheet.chr chr.hex
	hexmerge.py -o $(GAME).hex prg.hex chr.hex

clean:
	rm -f *.o *.bin *.hex *.dbg *.nl *.map.txt *.labels.txt

$(GAME).o: *.asm

%.o:%.asm
	$(ASSEMBLER) $< -g -o $@
