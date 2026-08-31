/*
 * PicoSoC DE0-Nano RAM-boot firmware.
 *
 * Flash / XIP helpers are PR-5 (DE0NANO_XIP). This file must not call
 * flashio() under DE0NANO_RAM_BOOT — that VLAs flashio_worker_* onto the
 * stack and bit-bangs 0x02000000.
 *
 * Based on PicoSoC firmware.c (ISC, Claire Xenia Wolf).
 */

#include <stdint.h>
#include <stdbool.h>

#if defined(DE0NANO_XIP) && defined(DE0NANO_RAM_BOOT)
#  error "DE0NANO_XIP and DE0NANO_RAM_BOOT are mutually exclusive"
#endif
#ifndef DE0NANO
#  error "This firmware is the DE0-Nano port; define DE0NANO"
#endif
#ifdef DE0NANO_XIP
#  define MEM_TOTAL 0x2000  /* 8 KiB scratchpad; matches MEM_WORDS=2048 */
#elif defined(DE0NANO_RAM_BOOT)
#  define MEM_TOTAL 0x8000  /* 32 KiB; matches MEM_WORDS=8192 */
#else
#  error "Define DE0NANO_RAM_BOOT or DE0NANO_XIP"
#endif
#ifndef SYSCLK_HZ
#  error "Pass -DSYSCLK_HZ=50000000 (or 25000000 if PLL fallback)"
#endif
#define UART_BAUD 115200
#define UART_DIV  (SYSCLK_HZ / UART_BAUD)  /* 434 @ 50 MHz; PicoSoC clk/baud */

#ifdef DE0NANO_RAM_BOOT
#  define MEMTEST_BASE 0x5000
#  define MEMTEST_SIZE 0x1000
#else
#  define MEMTEST_BASE 0
#  define MEMTEST_SIZE MEM_TOTAL
#endif

#define reg_spictrl     (*(volatile uint32_t *)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t *)0x02000004)
#define reg_uart_data   (*(volatile uint32_t *)0x02000008)
#define reg_leds        (*(volatile uint32_t *)0x03000000)

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

void print_hex(uint32_t v, int digits)
{
	for (int i = 7; i >= 0; i--) {
		char c = "0123456789abcdef"[(v >> (4 * i)) & 15];
		if (c == '0' && i >= digits)
			continue;
		putchar(c);
		digits = i;
	}
}

void print_dec(uint32_t v)
{
	if (v >= 1000) {
		print(">=1000");
		return;
	}

	if      (v >= 900) { putchar('9'); v -= 900; }
	else if (v >= 800) { putchar('8'); v -= 800; }
	else if (v >= 700) { putchar('7'); v -= 700; }
	else if (v >= 600) { putchar('6'); v -= 600; }
	else if (v >= 500) { putchar('5'); v -= 500; }
	else if (v >= 400) { putchar('4'); v -= 400; }
	else if (v >= 300) { putchar('3'); v -= 300; }
	else if (v >= 200) { putchar('2'); v -= 200; }
	else if (v >= 100) { putchar('1'); v -= 100; }

	if      (v >= 90) { putchar('9'); v -= 90; }
	else if (v >= 80) { putchar('8'); v -= 80; }
	else if (v >= 70) { putchar('7'); v -= 70; }
	else if (v >= 60) { putchar('6'); v -= 60; }
	else if (v >= 50) { putchar('5'); v -= 50; }
	else if (v >= 40) { putchar('4'); v -= 40; }
	else if (v >= 30) { putchar('3'); v -= 30; }
	else if (v >= 20) { putchar('2'); v -= 20; }
	else if (v >= 10) { putchar('1'); v -= 10; }

	if      (v >= 9) { putchar('9'); v -= 9; }
	else if (v >= 8) { putchar('8'); v -= 8; }
	else if (v >= 7) { putchar('7'); v -= 7; }
	else if (v >= 6) { putchar('6'); v -= 6; }
	else if (v >= 5) { putchar('5'); v -= 5; }
	else if (v >= 4) { putchar('4'); v -= 4; }
	else if (v >= 3) { putchar('3'); v -= 3; }
	else if (v >= 2) { putchar('2'); v -= 2; }
	else if (v >= 1) { putchar('1'); v -= 1; }
	else putchar('0');
}

char getchar_prompt(char *prompt)
{
	int32_t c = -1;

	uint32_t cycles_begin, cycles_now, cycles;
	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));

	reg_leds = ~0;

	if (prompt)
		print(prompt);

	while (c == -1) {
		__asm__ volatile ("rdcycle %0" : "=r"(cycles_now));
		cycles = cycles_now - cycles_begin;
		if (cycles > SYSCLK_HZ) {
			if (prompt)
				print(prompt);
			cycles_begin = cycles_now;
			reg_leds = ~reg_leds;
		}
		c = reg_uart_data;
	}

	reg_leds = 0;
	return c;
}

char getchar(void)
{
	return getchar_prompt(0);
}

uint32_t xorshift32(uint32_t *state)
{
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;
	return x;
}

void cmd_memtest(void)
{
	int cyc_count = 5;
	int stride = 256;
	uint32_t state;

	volatile uint32_t *base_word = (uint32_t *)MEMTEST_BASE;

	print("Running memtest ");

	for (int i = 1; i <= cyc_count; i++) {
		state = i;

		for (int word = 0; word < (int)(MEMTEST_SIZE / sizeof(int)); word += stride)
			*(base_word + word) = xorshift32(&state);

		state = i;

		for (int word = 0; word < (int)(MEMTEST_SIZE / sizeof(int)); word += stride) {
			if (*(base_word + word) != xorshift32(&state)) {
				print(" ***FAILED WORD*** at ");
				print_hex(MEMTEST_BASE + 4 * word, 4);
				print("\n");
				return;
			}
		}

		print(".");
	}

#ifndef DE0NANO_RAM_BOOT
	{
		volatile uint8_t *base_byte = (uint8_t *)0;
		for (int byte = 0; byte < 128; byte++)
			*(base_byte + byte) = (uint8_t)byte;
		for (int byte = 0; byte < 128; byte++) {
			if (*(base_byte + byte) != (uint8_t)byte) {
				print(" ***FAILED BYTE*** at ");
				print_hex(byte, 4);
				print("\n");
				return;
			}
		}
	}
#endif

	print(" passed\n");
}

uint32_t cmd_benchmark(bool verbose, uint32_t *instns_p)
{
	uint8_t data[256];
	uint32_t *words = (void *)data;
	uint32_t x32 = 314159265;
	uint32_t cycles_begin, cycles_end;
	uint32_t instns_begin, instns_end;

	__asm__ volatile ("rdcycle %0" : "=r"(cycles_begin));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_begin));

	for (int i = 0; i < 20; i++) {
		for (int k = 0; k < 256; k++) {
			x32 ^= x32 << 13;
			x32 ^= x32 >> 17;
			x32 ^= x32 << 5;
			data[k] = x32;
		}

		for (int k = 0, p = 0; k < 256; k++) {
			if (data[k])
				data[p++] = k;
		}

		for (int k = 0; k < 64; k++)
			x32 = x32 ^ words[k];
	}

	__asm__ volatile ("rdcycle %0" : "=r"(cycles_end));
	__asm__ volatile ("rdinstret %0" : "=r"(instns_end));

	if (verbose) {
		print("Cycles: 0x");
		print_hex(cycles_end - cycles_begin, 8);
		putchar('\n');

		print("Instns: 0x");
		print_hex(instns_end - instns_begin, 8);
		putchar('\n');

		print("Chksum: 0x");
		print_hex(x32, 8);
		putchar('\n');
	}

	if (instns_p)
		*instns_p = instns_end - instns_begin;

	return cycles_end - cycles_begin;
}

void cmd_echo(void)
{
	print("Return to menu by sending '!'\n\n");
	char c;
	while ((c = getchar()) != '!')
		putchar(c);
}

#ifdef DE0NANO_XIP
#  error "XIP firmware (flash helpers, Icebreaker W25Q) is PR-5"
#endif

void main(void)
{
	reg_leds = 31;
	reg_uart_clkdiv = UART_DIV;
	print("Booting..\n");

	reg_leds = 63;
	print("PicoSoC DE0-Nano\n");
	print("Total memory: ");
	print_dec(MEM_TOTAL / 1024);
	print(" KiB\n");

	reg_leds = 127;

	while (getchar_prompt("Press ENTER to continue..\n") != '\r') { /* wait */ }

	print("\n");
	print("  ____  _          ____         ____\n");
	print(" |  _ \\(_) ___ ___/ ___|  ___  / ___|\n");
	print(" | |_) | |/ __/ _ \\___ \\ / _ \\| |\n");
	print(" |  __/| | (_| (_) |__) | (_) | |___\n");
	print(" |_|   |_|\\___\\___/____/ \\___/ \\____|\n");
	print("\n");

	while (1) {
		print("\n");
		print("Select an action:\n");
		print("\n");
		print("   [9] Run simplistic benchmark\n");
		print("   [M] Memtest (0x5000-0x5FFF)\n");
		print("   [e] Echo UART\n");
		print("\n");

		for (int rep = 10; rep > 0; rep--) {
			print("Command> ");
			char cmd = getchar();
			if (cmd > 32 && cmd < 127)
				putchar(cmd);
			print("\n");

			switch (cmd) {
			case '9':
				cmd_benchmark(true, 0);
				break;
			case 'M':
				cmd_memtest();
				break;
			case 'e':
				cmd_echo();
				break;
			default:
				continue;
			}
			break;
		}
	}
}
