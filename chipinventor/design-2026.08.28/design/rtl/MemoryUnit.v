`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:39:11
// Design Name: 
// Module Name: MemoryUnit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MemoryUnit #(
    parameter FIRMWARE = "firmware.hex"
)(
    input  wire        clk,
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,     // rs2 data from core for stores
    input  wire [31:0] core_address_o,  // Memory address from core
    output wire [31:0] core_data_i      // Formatted load data to core
);

    // -------------------------------------------------------------------------
    // Internal Wires for Interconnects
    // -------------------------------------------------------------------------
    // LSU to Address Decoder
    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;

    // Address Decoder to IMEM
    wire [31:0] imem_addr;
    wire        imem_read_en;

    // Address Decoder to DMEM
    wire [31:0] dmem_addr;
    wire        dmem_read_en;
    wire        dmem_write_en;
    wire [3:0]  dmem_bw;

    // MUX and Memory Read Outputs
    wire        addr_decoder_sel;
    wire [31:0] imem_out;
    wire [31:0] dmem_out;
    wire [31:0] mux_mem_data_out;

    // -------------------------------------------------------------------------
    // 1. Read Data MUX (0: IMEM, 1: DMEM)
    // -------------------------------------------------------------------------
    assign mux_mem_data_out = (addr_decoder_sel) ? dmem_out : imem_out;

    // -------------------------------------------------------------------------
    // 2. Load-Store Unit (LSU) Instance
    // -------------------------------------------------------------------------
    LSU u_lsu (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),

        .mem_address_i (lsu_mem_addr),
        .mem_data_i    (lsu_mem_data),
        .byte_write_i  (lsu_byte_write),
        .mem_data_o    (mux_mem_data_out)
    );

    // -------------------------------------------------------------------------
    // 3. Address Decoder Instance
    // -------------------------------------------------------------------------
    AddressDecoder u_addr_decoder (
        .addr_i          (lsu_mem_addr),
        .read_enable_i   (read_enable),
        .write_enable_i  (write_enable),
        .bw_i            (lsu_byte_write),

        .imem_addr_o     (imem_addr),
        .imem_read_en_o  (imem_read_en),

        .dmem_addr_o     (dmem_addr),
        .dmem_read_en_o  (dmem_read_en),
        .dmem_write_en_o (dmem_write_en),
        .dmem_bw_o       (dmem_bw),

        .addr_decoder_sel(addr_decoder_sel)
    );

    // -------------------------------------------------------------------------
    // 4. Instruction Memory (IMEM) Instance
    // -------------------------------------------------------------------------
    IMEM #(
        .WORDS(1048576),
        .FIRMWARE(FIRMWARE)
    ) u_imem (
        .clk        (clk),
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    // -------------------------------------------------------------------------
    // 5. Data Memory (DMEM) Instance
    // -------------------------------------------------------------------------
    DMEM #(
        .WORDS(2048)
    ) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

endmodule