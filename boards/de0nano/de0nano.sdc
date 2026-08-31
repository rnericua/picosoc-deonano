# PicoSoC DE0-Nano SDC. Applied to every SoC SOF, including RAM-boot:
# spimemio still wiggles FLASH_SCK / FLASH_IO* (FFh/ABh at reset).
# Do not set_false_path the flash ports.

create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty

# UART: oversampled async. KEY/SW: human-speed.
set_false_path -from [get_ports {KEY[*] SW[*] UART_RX}]
set_false_path -to   [get_ports {LED[*] UART_TX}]

# spimemio_xfer: flash_clk <= !flash_clk && !flash_csb  →  SCK = 25 MHz
create_generated_clock -name FLASH_SCK \
    -source [get_ports CLOCK_50] -divide_by 2 [get_ports FLASH_SCK]

# W25Q64JV 03h (3.3 V, typical datasheet): tCLQV max 6 ns, tDVCH/tCHDX 2 ns,
# tCLQX/tOH min ~1.5 ns. Add ~2 ns for <10 cm Dupont wire.
set_output_delay -clock FLASH_SCK -max  4.000 [get_ports {FLASH_CS_N FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
set_output_delay -clock FLASH_SCK -min -1.000 [get_ports {FLASH_CS_N FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
set_input_delay  -clock FLASH_SCK -max  8.000 [get_ports {FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
set_input_delay  -clock FLASH_SCK -min  0.000 [get_ports {FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
