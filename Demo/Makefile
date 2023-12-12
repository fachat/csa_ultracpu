
PRGS=

all: updemo

updemo: updemo.a65 *.a65 
	#xa -w -M -XCA65 -OPETSCII -l $@.lab -o $@ $<
	xa -w -XCA65 -Pupdemo.lst -l $@.lab -o $@ $<

updemo.hex: updemo
	hexdump -C $< > $@.hex
	#diff -u $@.hex ../8296_burnin/8296\ burnin.hex

	cc -Wall -pedantic -o $@ $<

${PRGS}: % : %.lst
	petcat -w40 -o $@ $<

clean:
	rm -f updemo.lab updemo.hex

