/*
 * No-CPU pin/clock/reset smoke top for DE0-Nano.
 *
 * Same ports as de0nano so boards/de0nano/pins.qsf applies. LED[0] toggles
 * from a free-running counter (~1.5 Hz at 50 MHz). KEY0 is the same
 * synchronized POR as the SoC top. If this SOF is dark, do not debug
 * firmware or MIF init — CLOCK_50 / KEY0 / LED pins are wrong first.
 *
 * Copyright (C) 2026 PicoSoC DE0-Nano port authors
 */

module de0nano_blink (
	input        CLOCK_50,
	input  [1:0] KEY,
	input  [3:0] SW,
	output [7:0] LED,
	output       UART_TX,
	input        UART_RX,
	output       FLASH_CS_N,
	output       FLASH_SCK,
	inout        FLASH_IO0,
	inout        FLASH_IO1,
	inout        FLASH_IO2,
	inout        FLASH_IO3
);
	assign UART_TX    = 1'b1;
	assign FLASH_CS_N = 1'b1;
	assign FLASH_SCK  = 1'b0;
	assign FLASH_IO0  = 1'bz;
	assign FLASH_IO1  = 1'bz;
	assign FLASH_IO2  = 1'bz;
	assign FLASH_IO3  = 1'bz;

	wire unused = &{1'b0, KEY[1], SW, UART_RX, FLASH_IO0, FLASH_IO1, FLASH_IO2, FLASH_IO3};

	reg [5:0] reset_cnt = 0;
	reg [1:0] key0_sync = 2'b11;
	wire resetn = &reset_cnt;

	always @(posedge CLOCK_50) begin
		key0_sync <= {key0_sync[0], KEY[0]};
		if (!key0_sync[1])
			reset_cnt <= 6'd0;
		else if (!resetn)
			reset_cnt <= reset_cnt + 1'b1;
	end

	/* 2^25 / 50e6 ≈ 0.67 s half-period → ~0.75 Hz on LED[0]. */
	reg [24:0] cnt;
	always @(posedge CLOCK_50) begin
		if (!resetn)
			cnt <= 25'd0;
		else
			cnt <= cnt + 1'b1;
	end

	assign LED = {7'b0, cnt[24]};
endmodule
