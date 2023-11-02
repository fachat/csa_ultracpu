
ASM=low32k virtpet 
BASIC=readflash rtcc batmem sdcard showcols

all: ${ASM} ${BASIC} upeteth

clean:
	rm -f *.o65 ${ASM} ${BASIC} upeteth

${ASM}: %: %.a65
	xa -w -M $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<

upeteth: upeteth.s enceth.h
	xa -R -XCA65 -o $@.o65 $<
	reloc65 -X -o $@ $@.o65



