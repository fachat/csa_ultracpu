
ASM=low32k virtpet
BASIC=readflash rtcc batmem sdcard showcols

all: ${ASM} ${BASIC}

clean:
	rm -f ${ASM} ${BASIC}

${ASM}: %: %.a65
	xa -w -M $< -o $@

${BASIC}: %: %.lst
	petcat -w40 -o $@ $<


