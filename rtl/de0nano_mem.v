/*
 * On-chip SRAM for the PicoSoC DE0-Nano port.
 *
 * Simulation (-DSIMULATION): inferred array, $readmemh("fw/firmware.mem")
 * when BOOT_FROM_RAM is defined (presence-only).
 *
 * Synthesis (Quartus, PR-2): altsyncram + ../fw/firmware.mif so update_mif
 * works. That path is compiled only without -DSIMULATION.
 *
 * picosoc.v instantiates `PICOSOC_MEM #(.WORDS(MEM_WORDS)) and does not
 * pass INIT_FILE — init is internal and follows the same BOOT_FROM_RAM ifdef.
 *
 * Copyright (C) 2026 PicoSoC DE0-Nano port authors
 * Based on PicoSoC picosoc_mem (ISC, Claire Xenia Wolf).
 */

module de0nano_mem #(
	parameter integer WORDS = 8192
) (
	input             clk,
	input       [3:0] wen,
	input      [21:0] addr,
	input      [31:0] wdata,
	output     [31:0] rdata
);
	localparam integer AW = $clog2(WORDS);
`ifdef SIMULATION
	reg [31:0] mem [0:WORDS-1];
	initial begin
`ifdef BOOT_FROM_RAM
		$readmemh("fw/firmware.mem", mem);
`endif
	end
	reg [31:0] rdata_q;
	assign rdata = rdata_q;
	always @(posedge clk) begin
		rdata_q <= mem[addr[AW-1:0]];
		if (wen[0]) mem[addr[AW-1:0]][ 7: 0] <= wdata[ 7: 0];
		if (wen[1]) mem[addr[AW-1:0]][15: 8] <= wdata[15: 8];
		if (wen[2]) mem[addr[AW-1:0]][23:16] <= wdata[23:16];
		if (wen[3]) mem[addr[AW-1:0]][31:24] <= wdata[31:24];
	end
`else
`ifdef BOOT_FROM_RAM
	localparam INIT_FILE = "../fw/firmware.mif";
`else
	localparam INIT_FILE = "UNUSED";
`endif
	wire [AW-1:0] addr_w = addr[AW-1:0];
	altsyncram #(
		.operation_mode         ("SINGLE_PORT"),
		.width_a                (32),
		.widthad_a              (AW),
		.numwords_a             (WORDS),
		.width_byteena_a        (4),
		.byte_size              (8),
		.outdata_reg_a          ("CLOCK0"),
		.ram_block_type         ("M9K"),
		.init_file              (INIT_FILE),
		.init_file_layout       ("PORT_A"),
		.intended_device_family ("Cyclone IV E")
	) ram (
		.clock0         (clk),
		.address_a      (addr_w),
		.wren_a         (|wen),
		.byteena_a      (wen),
		.data_a         (wdata),
		.q_a            (rdata),
		.aclr0          (1'b0),
		.aclr1          (1'b0),
		.addressstall_a (1'b0),
		.rden_a         (1'b1),
		.address_b      ({AW{1'b0}}),
		.addressstall_b (1'b0),
		.byteena_b      (4'b0),
		.clock1         (1'b1),
		.clocken0       (1'b1),
		.clocken1       (1'b1),
		.clocken2       (1'b1),
		.clocken3       (1'b1),
		.data_b         (32'b0),
		.eccstatus      (),
		.q_b            (),
		.rden_b         (1'b1),
		.wren_b         (1'b0)
	);
`endif
endmodule
