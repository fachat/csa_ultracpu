
ASM=virtpet dacdma dacfile dacirq spriteirq sprite2irq
BASIC=readflash rtcc batmem sdcard showcols dacfload sprite sprite2

all: ${ASM} ${BASIC} upeteth bench2

clean:
	rm -f *.o65 ${ASM} ${BASIC} upeteth bench
	(cd benchmark; make clean)

${ASM}: %: %.a65
	xa -w -XMASM $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<

upeteth: upeteth.s enceth.inc
	xa -R -XCA65 -o $@.o65 $<
	reloc65 -X -o $@ $@.o65

bench2:
	(cd benchmark; make)
	ln -sf benchmark/bench

