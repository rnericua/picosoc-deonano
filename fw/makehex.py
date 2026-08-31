#!/usr/bin/env python3
#
# Word-oriented $readmemh image for M9K / inferred RAM.
# One 32-bit little-endian word per line, no @ address tokens.
# NEVER pass this file to spiflash.v (that model is a byte array
# loaded by objcopy -O verilog / firmware_xip.hex).
#
# Based on picorv32/firmware/makehex.py (public domain).
# The upstream assert is strict `<`; an image that is exactly
# 4*nwords bytes must be accepted, so this copy uses `<=`.

from sys import argv, exit

if len(argv) != 3:
    print("usage: makehex.py <firmware.bin> <nwords>", flush=True)
    exit(1)

binfile = argv[1]
nwords = int(argv[2])

with open(binfile, "rb") as f:
    bindata = f.read()

assert len(bindata) <= 4 * nwords, "image larger than RAM (%d bytes > %d)" % (
    len(bindata),
    4 * nwords,
)
assert len(bindata) % 4 == 0, "image length is not a multiple of 4"

for i in range(nwords):
    if i < len(bindata) // 4:
        w = bindata[4 * i : 4 * i + 4]
        print("%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0]))
    else:
        print("0")
