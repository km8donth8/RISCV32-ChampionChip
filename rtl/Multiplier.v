`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 10:55:44
// Design Name: 
// Module Name: Multiplier
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


`define MUL 4'h0
`define MULH 4'h1
`define MULHSU 4'h2
`define MULHU 4'h3

module Multiplier(
    input [31:0] reg_rs_1,
    input [31:0] reg_rs_2,
    input  [3:0]  mult_sel,
    output reg [31:0] rd
    );
    //All 3 values are always calculated just use mux to selct the values
    wire signed [63:0] mul_ss; // Signed x Signed => Signed
    wire signed [63:0] mul_su; // Signed x Unsigned => Signed
    wire        [63:0] mul_uu; // Unsigned x Unsigned => Unsigned

    // Compute 64-bit intermediate products
    assign mul_ss = $signed(reg_rs_1) * $signed(reg_rs_2);
    assign mul_su = $signed({reg_rs_1[31], reg_rs_1}) * $signed({1'b0, reg_rs_2}); // Zero-extend rs2 to prevent sign treatment
    assign mul_uu = $unsigned(reg_rs_1) * $unsigned(reg_rs_2);

    always @(*) begin
        case (mult_sel)
            `MUL: rd = mul_ss[31:0];  // MUL  : lower 32 bits (Signed or Unsigned give same lower bits)
            `MULH: rd = mul_ss[63:32]; // MULH : upper 32 bits (Signed * Signed)
            `MULHSU: rd = mul_su[63:32]; // MULHSU: upper 32 bits (Signed * Unsigned)
            `MULHU: rd = mul_uu[63:32]; // MULHU: upper 32 bits (Unsigned * Unsigned)
            default: rd = 32'h0;
        endcase
    end 
endmodule
