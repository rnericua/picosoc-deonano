# PicoSoC on Terasic DE0-Nano — PR-1: RAM-boot firmware + Icarus sim.
# Quartus bitstream, update_mif, and BOOT=xip are later PRs.

# Optional user-local tools (xPack GCC, extracted iverilog .deb).
ifneq ($(wildcard $(HOME)/.local/xpack-riscv-none-elf-gcc-14.2.0-3/bin/riscv-none-elf-gcc),)
  export PATH := $(HOME)/.local/xpack-riscv-none-elf-gcc-14.2.0-3/bin:$(PATH)
endif
ifneq ($(wildcard $(HOME)/.local/bin/iverilog),)
  export PATH := $(HOME)/.local/bin:$(PATH)
endif

# Extracted Debian/Ubuntu iverilog is hardcoded to /usr/lib/.../ivl.
IVL ?= $(HOME)/.local/lib/x86_64-linux-gnu/ivl
ifneq ($(wildcard $(IVL)/ivl),)
  IVERILOGFLAGS ?= -B$(IVL)
  VVP_M ?= -M$(IVL)
endif

BOOT ?= ram

ifeq ($(BOOT),ram)
  BOOT_DEFS := -DDE0NANO -DDE0NANO_RAM_BOOT -DSYSCLK_HZ=50000000
  MEM_WORDS := 8192
  SIM_DEFS  := -DSIMULATION -DBOOT_FROM_RAM -DPICOSOC_MEM=de0nano_mem
else
  $(error BOOT=$(BOOT) is not built in PR-1; use BOOT=ram. XIP is PR-5)
endif

# Prefer the PicoSoC-documented prefix, then xPack, then Debian's rv64-named gcc.
ifeq ($(origin CROSS), undefined)
  ifneq ($(shell command -v riscv32-unknown-elf-gcc 2>/dev/null),)
    CROSS := riscv32-unknown-elf-
  else ifneq ($(shell command -v riscv-none-elf-gcc 2>/dev/null),)
    CROSS := riscv-none-elf-
  else ifneq ($(shell command -v riscv64-unknown-elf-gcc 2>/dev/null),)
    CROSS := riscv64-unknown-elf-
  else
    CROSS := riscv32-unknown-elf-
  endif
endif

CFLAGS ?=
ARCH_FLAGS := -mabi=ilp32 -march=rv32imc
PICORV32 := third_party/picorv32

SOC_RTL := \
	rtl/de0nano.v \
	rtl/de0nano_mem.v \
	$(PICORV32)/picosoc/picosoc.v \
	$(PICORV32)/picosoc/spimemio.v \
	$(PICORV32)/picosoc/simpleuart.v \
	$(PICORV32)/picorv32.v

.PHONY: all fw sim clean

all: sim

fw: fw/firmware.mem

fw/de0nano_sections.lds: fw/sections.lds
	$(CROSS)cpp -P $(BOOT_DEFS) -o $@ $^

# start.S MUST be the first object so `start` is at ORIGIN.
fw/firmware.elf: fw/de0nano_sections.lds fw/start.S fw/firmware.c
	$(CROSS)gcc $(CFLAGS) $(BOOT_DEFS) $(ARCH_FLAGS) -fno-builtin \
	  -Wl,--build-id=none,-Bstatic,-T,fw/de0nano_sections.lds,--strip-debug,--no-warn-rwx-segments \
	  -ffreestanding -nostdlib -o $@ fw/start.S fw/firmware.c

fw/firmware.bin: fw/firmware.elf
	$(CROSS)objcopy -O binary $< $@

# RAM-boot M9K image (word $readmemh). NEVER pass this to spiflash.v.
fw/firmware.mem: fw/firmware.bin fw/makehex.py
	python3 fw/makehex.py $< $(MEM_WORDS) > $@

sim/de0nano_tb.vvp: sim/de0nano_tb.v $(SOC_RTL) fw/firmware.mem
	iverilog $(IVERILOGFLAGS) -g2005 -s testbench -o $@ $(SIM_DEFS) \
	  sim/de0nano_tb.v $(SOC_RTL)

sim: sim/de0nano_tb.vvp
	vvp $(VVP_M) -N $< $(VVPFLAGS)

clean:
	rm -f fw/firmware.elf fw/firmware.bin fw/firmware.mem fw/firmware.mif \
	      fw/firmware_xip.hex fw/de0nano_sections.lds \
	      sim/de0nano_tb.vvp sim/de0nano.vcd
