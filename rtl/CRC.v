`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 19:34:37
// Design Name: 
// Module Name: CRC
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


module CRC (
    input wire [31:0] reg_rs_1, // Input data payload
    input wire [15:0] reg_rs_2, // Current 16-bit seed or chained previous CRC
    input wire [1:0]  crc_sel,  // Mode Select: 2'b00 = 8-bit, 2'b01 = 16-bit, 2'b10 = 32-bit
    output reg [31:0] rd    // Zero-extended 16-bit CRC output result
);

    wire [15:0] crc8_out;
    wire [15:0] crc16_out;
    wire [15:0] crc32_out;

    // ------------------------------------------------------------------------
    // 8-bit Input Mode Engine (Processes reg_rs_1[7:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h8005),
        .CRC_SIZE(16),
        .DATA_WIDTH(8),
        .REF_IN(1),
        .REF_OUT(1),
        .XOR_OUT(64'hFFFF)
    ) u_crc8 (
        .crc_in(reg_rs_2),
        .data_i(reg_rs_1[7:0]),
        .crc_o(crc8_out)
    );

    // ------------------------------------------------------------------------
    // 16-bit Input Mode Engine (Processes reg_rs_1[15:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h8005),
        .CRC_SIZE(16),
        .DATA_WIDTH(16),
        .REF_IN(1),
        .REF_OUT(1),
        .XOR_OUT(64'hFFFF)
    ) u_crc16 (
        .crc_in(reg_rs_2),
        .data_i(reg_rs_1[15:0]),
        .crc_o(crc16_out)
    );

    // ------------------------------------------------------------------------
    // 32-bit Input Mode Engine (Processes reg_rs_1[31:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h8005),
        .CRC_SIZE(16),
        .DATA_WIDTH(32),
        .REF_IN(1),
        .REF_OUT(1),
        .XOR_OUT(64'hFFFF)
    ) u_crc32 (
        .crc_in(reg_rs_2),
        .data_i(reg_rs_1[31:0]),
        .crc_o(crc32_out)
    );

    // ------------------------------------------------------------------------
    // Output Select Multiplexer
    // ------------------------------------------------------------------------
    always @(*) begin
        case (crc_sel)
            2'b00:   rd = {16'h0000, crc8_out};  // 8-bit Input
            2'b01:   rd = {16'h0000, crc16_out}; // 16-bit Input
            2'b10:   rd = {16'h0000, crc32_out}; // 32-bit Input
            default: rd = 32'h0000_0000;
        endcase
    end

endmodule