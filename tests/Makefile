
ASM=low32k virtpet dacdma dacfile dacirq spriteirq sprite2irq
BASIC=readflash rtcc batmem sdcard showcols dacfload sprite sprite2

all: ${ASM} ${BASIC} upeteth

clean:
	rm -f *.o65 ${ASM} ${BASIC} upeteth

${ASM}: %: %.a65
	xa -w -XMASM $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<

upeteth: upeteth.s enceth.inc
	xa -R -XCA65 -o $@.o65 $<
	reloc65 -X -o $@ $@.o65



