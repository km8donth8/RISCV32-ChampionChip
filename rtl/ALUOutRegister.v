`timescale 1ns / 1ps
`default_nettype none

// Retains selected ALU, multiplier, CRC result between EXECUTE and
// later memory, PC-commit, or register-writeback state.
module ALUOutRegister (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_enable,
    input  wire [31:0] result_i,
    output reg  [31:0] result_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_o <= 32'h0000_0000;
        else if (write_enable)
            result_o <= result_i;
    end
endmodule

`default_nettype wire