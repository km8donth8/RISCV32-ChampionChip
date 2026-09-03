`timescale 1ns / 1ps
`default_nettype none

// holds instruction for every state after FETCH,
// IMEM result is captured only when controller asserts write_enable (IMEM async read)
module InstructionRegister (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_enable,
    input  wire [31:0] instruction_i,
    output reg  [31:0] instruction_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            instruction_o <= 32'h0000_0013; // ADDI x0,x0,0 (NOP)
        else if (write_enable)
            instruction_o <= instruction_i;
    end
endmodule

`default_nettype wire
