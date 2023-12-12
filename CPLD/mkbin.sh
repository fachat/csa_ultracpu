#!/bin/sh

. /opt/Xilinx/14.7/ISE_DS/settings64.sh

promgen -w -spi -p bin -r fpgaprom.mcs -o fpgaprom.bin

