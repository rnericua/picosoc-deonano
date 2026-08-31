# PicoSoC on Terasic DE0-Nano

A port of [YosysHQ PicoSoC](https://github.com/YosysHQ/picorv32/tree/main/picosoc) to the Terasic DE0-Nano (Cyclone IV E EP4CE22F17C6N).

This is **PR-1**: RAM-boot firmware in on-chip M9K plus an Icarus Verilog simulation. Quartus bitstream generation is PR-2. External SPI-flash XIP is PR-5.

Design notes: [docs/picosoc-de0nano-port.md](docs/picosoc-de0nano-port.md).

## What PR-1 builds

- PicoRV32 + PicoSoC interconnect, 32 KiB on-chip RAM, UART, LED/KEY/SW GPIO
- Firmware linked at address 0 (`PROGADDR_RESET = 0`), baked into `fw/firmware.mem` for `$readmemh`
- `make sim` runs a 50 MHz Icarus testbench and prints the UART banner

PicoRV32/PicoSoC RTL is a **git submodule** pinned to `a473fc8fca393771d83b0ffcf0b14db3393339d8`.

## Clone

```
git clone --recurse-submodules <this-repo>
# or after a plain clone:
git submodule update --init --recursive
```

## Tools

| Tool | Role |
| --- | --- |
| `riscv32-unknown-elf-gcc` (or `riscv-none-elf-gcc` / `riscv64-unknown-elf-gcc` with `-march=rv32imc`) | firmware |
| Icarus Verilog 11+ (`iverilog`, `vvp`) | simulation |
| Python 3 | `fw/makehex.py` |

The Makefile picks the first of `riscv32-unknown-elf-`, `riscv-none-elf-`, `riscv64-unknown-elf-` on `PATH`. Override with `make CROSS=riscv-none-elf- sim`.

## Simulate

```
make sim
```

Pass criteria (RAM-boot):

- LED nibble `00000001` → `00000011` → `00000111` → `00001111` (`start.S`)
- UART prints `Booting..` and `PicoSoC DE0-Nano`

Useful plusargs:

```
make sim VVPFLAGS=          # see Makefile; or:
vvp -N sim/de0nano_tb.vvp +timeout=4000000 +vcd
```

`+vcd` writes `sim/de0nano.vcd`. Default timeout is 2 000 000 cycles (~40 ms at 50 MHz), enough for the banner.

Firmware-only:

```
make fw          # fw/firmware.elf .bin .mem
make BOOT=ram fw
```

`make BOOT=xip` is not built in PR-1.

## Memory map (unchanged from PicoSoC)

| Address | Contents |
| --- | --- |
| `0x00000000` | 32 KiB M9K (`.text` / `.data` / `.bss` in RAM-boot) |
| `0x02000004` | UART clock divider (write `434` at 50 MHz / 115200) |
| `0x02000008` | UART data |
| `0x03000000` | GPIO: LED[7:0] RW, SW[3:0] and KEY[1:0] RO |

RAM-boot layout: `[0x0000,0x5000)` image/heap, `[0x5000,0x6000)` memtest, `[0x6000,0x8000)` stack.

## License

ISC. Vendored PicoRV32/PicoSoC remains ISC, copyright Claire Xenia Wolf; see `LICENSE` and `third_party/picorv32`.
