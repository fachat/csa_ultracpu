
ASM=low32k virtpet
BASIC=readflash rtcc batmem sdcard showcols

all: ${ASM} ${BASIC} bench

clean:
	(cd benchmark; make clean)
	rm -f ${ASM} ${BASIC} bench

${ASM}: %: %.a65
	xa -w -M $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<

bench:
	(cd benchmark; make)
	ln -s benchmark/bench

