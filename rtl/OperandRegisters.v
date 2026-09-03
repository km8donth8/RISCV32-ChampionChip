`timescale 1ns / 1ps
`default_nettype none

// captures both async register-file read ports during DECODE so
// rs1 and rs2 remain stable for remaining multicycle execution states
module OperandRegisters (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_enable,
    input  wire [31:0] rs1_data_i,
    input  wire [31:0] rs2_data_i,
    output reg  [31:0] operand_a_o,
    output reg  [31:0] operand_b_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            operand_a_o <= 32'h0000_0000;
            operand_b_o <= 32'h0000_0000;
        end else if (write_enable) begin
            operand_a_o <= rs1_data_i;
            operand_b_o <= rs2_data_i;
        end
    end
endmodule

`default_nettype wire