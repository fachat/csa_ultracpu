
ASM=virtpet
BASIC=readflash rtcc batmem sdcard showcols

all: ${ASM} ${BASIC} bench2

clean:
	(cd benchmark; make clean)
	rm -f ${ASM} ${BASIC} bench

${ASM}: %: %.a65
	xa -w -M $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<

bench2:
	(cd benchmark; make)
	ln -sf benchmark/bench

