/*
 * Icarus RAM-boot testbench for the PicoSoC DE0-Nano port.
 *
 * Compile with -DSIMULATION -DBOOT_FROM_RAM -DPICOSOC_MEM=de0nano_mem
 * (presence-only; never -DBOOT_FROM_RAM=0). Clock is 50 MHz to match silicon.
 *
 * Based on PicoSoC hx8kdemo_tb.v (ISC, Claire Xenia Wolf).
 */

`timescale 1 ns / 1 ps

module testbench;
	reg clk = 1'b0;
	always #10 clk = ~clk; /* 50 MHz */

	localparam ser_half_period = 217; /* half of UART_DIV=434 */
	event ser_sample;

	integer timeout_cycles;
	initial begin
		if ($test$plusargs("vcd")) begin
			$dumpfile("sim/de0nano.vcd");
			$dumpvars(0, testbench);
		end
		if (!$value$plusargs("timeout=%d", timeout_cycles))
			timeout_cycles = 2000000;
		repeat (timeout_cycles) @(posedge clk);
		if (!banner_ok)
			$fatal(1, "TIMEOUT after %0d cycles: no UART 'Booting..'", timeout_cycles);
		if (!(&led_seen))
			$fatal(1, "TIMEOUT after %0d cycles: LED nibble incomplete (%b)",
			       timeout_cycles, led_seen);
		$display("TIMEOUT after %0d cycles", timeout_cycles);
		$finish;
	end

	wire [7:0] LED;
	wire       UART_TX;
	wire       UART_RX = 1'b1;
	wire       FLASH_CS_N;
	wire       FLASH_SCK;
	wire       FLASH_IO0;
	wire       FLASH_IO1;
	wire       FLASH_IO2;
	wire       FLASH_IO3;

	pullup (FLASH_IO0);
	pullup (FLASH_IO1);
	pullup (FLASH_IO2);
	pullup (FLASH_IO3);

	always @(LED) begin
		#1 $display("%b", LED);
	end

	de0nano uut (
		.CLOCK_50  (clk       ),
		.KEY       (2'b11     ),
		.SW        (4'b0000   ),
		.LED       (LED       ),
		.UART_TX   (UART_TX   ),
		.UART_RX   (UART_RX   ),
		.FLASH_CS_N(FLASH_CS_N),
		.FLASH_SCK (FLASH_SCK ),
		.FLASH_IO0 (FLASH_IO0 ),
		.FLASH_IO1 (FLASH_IO1 ),
		.FLASH_IO2 (FLASH_IO2 ),
		.FLASH_IO3 (FLASH_IO3 )
	);

	/* Fetch past SRAM in RAM-boot waits forever on spimem_ready. */
	integer spi_wait;
	always @(posedge clk) begin
		if (!uut.resetn)
			spi_wait <= 0;
		else if (uut.soc.mem_valid &&
		         (uut.soc.mem_addr >= 32'h0000_8000) &&
		         (uut.soc.mem_addr <  32'h0200_0000) &&
		         !uut.soc.spimem_ready) begin
			spi_wait <= spi_wait + 1;
			if (spi_wait >= 10000)
				$fatal(1, "RAM-boot hung on spimem_ready mem_addr=%08x",
				       uut.soc.mem_addr);
		end else
			spi_wait <= 0;
	end

	reg [7:0] buffer;
	reg [8*9-1:0] uart_tail = 0;
	reg banner_ok = 1'b0;
	reg [3:0] led_seen = 4'b0000;

	always @(LED) begin
		if (LED == 8'b00000001) led_seen[0] = 1'b1;
		if (LED == 8'b00000011) led_seen[1] = 1'b1;
		if (LED == 8'b00000111) led_seen[2] = 1'b1;
		if (LED == 8'b00001111) led_seen[3] = 1'b1;
	end

	always begin
		@(negedge UART_TX);

		repeat (ser_half_period) @(posedge clk);
		-> ser_sample; /* start bit */

		repeat (8) begin
			repeat (ser_half_period) @(posedge clk);
			repeat (ser_half_period) @(posedge clk);
			buffer = {UART_TX, buffer[7:1]};
			-> ser_sample;
		end

		repeat (ser_half_period) @(posedge clk);
		repeat (ser_half_period) @(posedge clk);
		-> ser_sample; /* stop bit */

		if (buffer < 32 || buffer >= 127)
			$display("Serial data: %d", buffer);
		else
			$display("Serial data: '%c'", buffer);

		uart_tail = {uart_tail[8*8-1:0], buffer};
		if (uart_tail == "Booting..")
			banner_ok = 1'b1;
		if (banner_ok && (&led_seen)) begin
			$display("PASS: RAM-boot banner and LED nibble");
			$finish;
		end
	end
endmodule
