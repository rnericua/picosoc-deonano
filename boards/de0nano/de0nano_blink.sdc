# Constraints for the no-CPU blink SOF. FLASH_* are tied, not toggling.

create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty

set_false_path -from [get_ports {KEY[*] SW[*] UART_RX}]
set_false_path -to   [get_ports {LED[*] UART_TX FLASH_CS_N FLASH_SCK}]
set_false_path -from [get_ports {FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
set_false_path -to   [get_ports {FLASH_IO0 FLASH_IO1 FLASH_IO2 FLASH_IO3}]
