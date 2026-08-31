/*
 * PicoSoC board top for Terasic DE0-Nano (Cyclone IV E EP4CE22F17C6N).
 *
 * Compile-time boot mode is presence-only `ifdef BOOT_FROM_RAM:
 *   defined  -> MEM_WORDS=8192, PROGADDR_RESET=0 (RAM-boot MVP)
 *   omitted  -> MEM_WORDS=2048, PROGADDR_RESET=0x00100000 (XIP, PR-5)
 * Never pass BOOT_FROM_RAM=0: `ifdef stays true and RAM-boot MIF would load.
 *
 * Based on PicoSoC hx8kdemo.v (ISC, Claire Xenia Wolf).
 * Copyright (C) 2026 PicoSoC DE0-Nano port authors
 */

module de0nano (
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
	wire clk = CLOCK_50;

`ifdef BOOT_FROM_RAM
	localparam integer MEM_WORDS    = 8192;
	localparam [31:0]  PROGADDR_RST = 32'h0000_0000;
`else
	localparam integer MEM_WORDS    = 2048;
	localparam [31:0]  PROGADDR_RST = 32'h0010_0000;
`endif

	reg [5:0] reset_cnt = 0;
	reg [1:0] key0_sync = 2'b11;
	wire resetn = &reset_cnt;

	always @(posedge clk) begin
		key0_sync <= {key0_sync[0], KEY[0]};
		if (!key0_sync[1])
			reset_cnt <= 6'd0;
		else if (!resetn)
			reset_cnt <= reset_cnt + 1'b1;
	end

	wire flash_io0_oe, flash_io0_do, flash_io0_di;
	wire flash_io1_oe, flash_io1_do, flash_io1_di;
	wire flash_io2_oe, flash_io2_do, flash_io2_di;
	wire flash_io3_oe, flash_io3_do, flash_io3_di;

	assign FLASH_IO0 = flash_io0_oe ? flash_io0_do : 1'bz;
	assign FLASH_IO1 = flash_io1_oe ? flash_io1_do : 1'bz;
	assign FLASH_IO2 = flash_io2_oe ? flash_io2_do : 1'bz;
	assign FLASH_IO3 = flash_io3_oe ? flash_io3_do : 1'bz;
	assign flash_io0_di = FLASH_IO0;
	assign flash_io1_di = FLASH_IO1;
	assign flash_io2_di = FLASH_IO2;
	assign flash_io3_di = FLASH_IO3;

	wire        iomem_valid;
	reg         iomem_ready;
	wire [3:0]  iomem_wstrb;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	reg  [31:0] iomem_rdata;

	reg [7:0] led_reg;
	assign LED = led_reg;

	always @(posedge clk) begin
		if (!resetn) begin
			led_reg     <= 8'h00;
			iomem_ready <= 1'b0;
		end else begin
			iomem_ready <= 1'b0;
			if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h03) begin
				iomem_ready <= 1'b1;
				iomem_rdata <= {18'b0, KEY, SW, led_reg};
				if (iomem_wstrb[0]) led_reg <= iomem_wdata[7:0];
			end
		end
	end

	picosoc #(
		.BARREL_SHIFTER    (1),
		.ENABLE_MUL        (0),
		.ENABLE_DIV        (0),
		.ENABLE_FAST_MUL   (1),
		.ENABLE_COMPRESSED (1),
		.ENABLE_COUNTERS   (1),
		.ENABLE_IRQ_QREGS  (0),
		.MEM_WORDS         (MEM_WORDS),
		.STACKADDR         (4 * MEM_WORDS),
		.PROGADDR_RESET    (PROGADDR_RST),
		.PROGADDR_IRQ      (32'h0000_0000)
	) soc (
		.clk          (clk         ),
		.resetn       (resetn      ),

		.ser_tx       (UART_TX     ),
		.ser_rx       (UART_RX     ),

		.flash_csb    (FLASH_CS_N  ),
		.flash_clk    (FLASH_SCK   ),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.irq_5        (1'b0        ),
		.irq_6        (1'b0        ),
		.irq_7        (1'b0        ),

		.iomem_valid  (iomem_valid ),
		.iomem_ready  (iomem_ready ),
		.iomem_wstrb  (iomem_wstrb ),
		.iomem_addr   (iomem_addr  ),
		.iomem_wdata  (iomem_wdata ),
		.iomem_rdata  (iomem_rdata )
	);
endmodule
