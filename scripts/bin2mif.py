#!/usr/bin/env python3
#
# firmware.bin → Quartus Memory Initialization File (MIF).
# WIDTH=32, DEPTH=nwords, little-endian words matching makehex.py / PicoRV32.
# Path consumed by altsyncram init_file = "../fw/firmware.mif" (relative to
# quartus/de0nano.qpf). Never name this .hex — Quartus HEX_FILE is Intel HEX.

from sys import argv, exit


def main():
    if len(argv) != 3:
        print("usage: bin2mif.py <firmware.bin> <nwords>", flush=True)
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

    print("DEPTH = %d;" % nwords)
    print("WIDTH = 32;")
    print("ADDRESS_RADIX = HEX;")
    print("DATA_RADIX = HEX;")
    print("CONTENT BEGIN")
    for i in range(nwords):
        if i < len(bindata) // 4:
            w = bindata[4 * i : 4 * i + 4]
            word = w[0] | (w[1] << 8) | (w[2] << 16) | (w[3] << 24)
            print("%X : %08X;" % (i, word))
        else:
            print("%X : 00000000;" % i)
    print("END;")


if __name__ == "__main__":
    main()
