# PicoSoC on Terasic DE0-Nano

A port of [YosysHQ PicoSoC](https://github.com/YosysHQ/picorv32/tree/main/picosoc) to the Terasic DE0-Nano (Cyclone IV E EP4CE22F17C6N).

**PR-1:** RAM-boot firmware in on-chip M9K plus Icarus simulation.
**PR-2:** Quartus project, pin/SDC constraints, `altsyncram` MIF init, blink SOF.
External SPI-flash XIP is PR-5.

Design notes: [docs/picosoc-de0nano-port.md](docs/picosoc-de0nano-port.md).

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
| Python 3 | `fw/makehex.py`, `scripts/bin2mif.py` |
| Quartus Prime **Lite** 18.1 / 23.1 / 24.1 + Cyclone IV E pack | bitstream (PR-2). Pro does not support Cyclone IV. |

The Makefile picks the first of `riscv32-unknown-elf-`, `riscv-none-elf-`, `riscv64-unknown-elf-` on `PATH`. Override with `make CROSS=riscv-none-elf- sim`.

Put Quartus on `PATH`:

```
export PATH=/opt/intelFPGA_lite/24.1std/quartus/bin:$PATH
```

## Simulate (no Quartus)

```
make sim
```

Pass criteria (RAM-boot):

- LED nibble `00000001` → `00000011` → `00000111` → `00001111` (`start.S`)
- UART prints `Booting..` and `PicoSoC DE0-Nano`
- Testbench prints `PASS: RAM-boot banner and LED nibble`

```
make fw          # fw/firmware.elf .bin .mem .mif
make BOOT=ram fw
vvp -N sim/de0nano_tb.vvp +timeout=4000000 +vcd   # optional VCD
```

`make BOOT=xip` is PR-5.

## Quartus (PR-2)

Silicon RAM-boot **source of truth** is `altsyncram` with
`init_file = ../fw/firmware.mif` (path relative to `quartus/de0nano.qpf`).
Do not feed `firmware.mem` or a Verilog `$readmemh` `.hex` to Quartus — those are not Intel HEX.

```
make quartus-blink && make prog-blink   # optional: LED[0] ~0.75 Hz, no CPU
make quartus                            # SoC SOF with MIF
make sta                                # Slow 85 °C Fmax gate (>= 50 MHz)
make check-mif                          # map report names firmware.mif
make prog                               # USB-Blaster JTAG
```

Firmware-only refresh (no refit):

```
make fw && make update-mif && make prog
```

`scripts/prog.sh [file.sof]` is the same JTAG program step.

### S1 lab

1. If the SoC SOF is dark, load the blink SOF first. If blink is also dark, stop: CLOCK_50 / KEY0 / LED pins, not firmware.
2. SoC SOF: LED[0:3] should freeze at `0x0F` after a few microseconds (`start.S`). KEY0 held low keeps the CPU in reset.
3. `make update-mif` after a firmware edit must change that pattern without a full `quartus_fit`.

### STA fallback (same PR, 50 MHz)

Need Slow 1200 mV 85 °C **Restricted Fmax of `CLOCK_50` ≥ 50 MHz**. If it misses, uncomment in `quartus/de0nano.qsf`:

```
set_global_assignment -name VERILOG_MACRO "BARREL_SHIFTER_OFF=1"
```

Rebuild. UART divider stays **434**. Do **not** add a 25 MHz PLL in this PR (that is PR-7, only if shifter-off still fails).

### Device / pins

| Item | Value |
| --- | --- |
| Device | `EP4CE22F17C6`, family Cyclone IV E |
| Clock | `CLOCK_50` = `PIN_R8`, 20 ns |
| UART | JP1 pin 10 `UART_TX` (`PIN_B5`) → adapter RXD; pin 8 `UART_RX` (`PIN_B4`) ← adapter TXD; GND pin 12 |
| SPI NOR | JP2 pins 13–18 (CS/SCK/IO0–3). RAM-boot still wiggles these (`spimemio` FFh/ABh). |

**5 V USB-serial TXD will damage Cyclone IV I/O.** Measure adapter TXD (~3.3 V) before connecting to `PIN_B4`. Wiring notes are PR-3.

## Memory map (unchanged from PicoSoC)

| Address | Contents |
| --- | --- |
| `0x00000000` | 32 KiB M9K (`.text` / `.data` / `.bss` in RAM-boot) |
| `0x02000004` | UART clock divider (write `434` at 50 MHz / 115200) |
| `0x02000008` | UART data |
| `0x03000000` | GPIO: LED[7:0] RW, SW[3:0] and KEY[1:0] RO |

RAM-boot layout: `[0x0000,0x5000)` image/heap, `[0x5000,0x6000)` memtest, `[0x6000,0x8000)` stack.

Firmware images (do not mix):

| File | Consumer |
| --- | --- |
| `fw/firmware.mem` | Icarus `$readmemh` (word) |
| `fw/firmware.mif` | Quartus `altsyncram` `init_file` |
| `fw/firmware_xip.hex` | PR-5 `objcopy -O verilog` / `spiflash.v` |

## License

ISC. Vendored PicoRV32/PicoSoC remains ISC, copyright Claire Xenia Wolf; see `LICENSE` and `third_party/picorv32`.
