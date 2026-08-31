# Build from this directory, or via the repo-root Makefile.
# quartus_sh --flow compile uses the .qpf in cwd.

PROJECT ?= de0nano
REV     ?= de0nano
BLINK   ?= de0nano_blink

QSH  ?= quartus_sh
QCDB ?= quartus_cdb
QASM ?= quartus_asm
QPGM ?= quartus_pgm

SOF       := output_files/$(REV).sof
BLINK_SOF := output_files/$(BLINK).sof
STA_RPT   := output_files/$(REV).sta.rpt
MAP_RPT   := output_files/$(REV).map.rpt

SOC_RTL := \
	../rtl/de0nano.v \
	../rtl/de0nano_mem.v \
	../third_party/picorv32/picosoc/picosoc.v \
	../third_party/picorv32/picosoc/spimemio.v \
	../third_party/picorv32/picosoc/simpleuart.v \
	../third_party/picorv32/picorv32.v \
	../boards/de0nano/pins.qsf \
	../boards/de0nano/de0nano.sdc

.PHONY: all blink update-mif sta prog prog-blink clean check-mif check-sta

all: $(SOF)

$(SOF): ../fw/firmware.mif de0nano.qsf de0nano.qpf $(SOC_RTL)
	$(QSH) --flow compile $(PROJECT) -c $(REV)

blink: $(BLINK_SOF)

$(BLINK_SOF): de0nano_blink.qsf de0nano.qpf ../rtl/de0nano_blink.v \
		../boards/de0nano/pins.qsf ../boards/de0nano/de0nano_blink.sdc
	$(QSH) --flow compile $(PROJECT) -c $(BLINK)

# Firmware-only RAM-boot path: rebuild MIF, refresh RAM contents, re-assemble.
# Does not refit. Caller must have produced ../fw/firmware.mif first.
update-mif: ../fw/firmware.mif
	$(QCDB) $(PROJECT) -c $(REV) --update_mif
	$(QASM) $(PROJECT) -c $(REV)

sta: $(STA_RPT)
	@echo "=== Slow 1200mV 85C Fmax (need CLOCK_50 >= 50 MHz) ==="
	-@grep -n -A20 -E "Slow 1200mV 85C Model Fmax Summary" $(STA_RPT) | head -30
	../scripts/check-sta.sh $(STA_RPT)

# Gate: map report names the MIF on the altsyncram.
check-mif: $(MAP_RPT)
	@grep -E "firmware\.mif|altsyncram|M9K" $(MAP_RPT) | head -40
	@grep -q "firmware.mif" $(MAP_RPT)
	@echo "PASS: map report mentions firmware.mif"

$(STA_RPT) $(MAP_RPT): $(SOF)

prog: $(SOF)
	$(QPGM) -m jtag -o "p;$(SOF)"

prog-blink: $(BLINK_SOF)
	$(QPGM) -m jtag -o "p;$(BLINK_SOF)"

clean:
	rm -rf db incremental_db output_files simulation greybox_tmp
	rm -f *.qws *.qdf c5_pin_model_dump.txt
