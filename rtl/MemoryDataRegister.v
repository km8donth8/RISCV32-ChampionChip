`timescale 1ns / 1ps
`default_nettype none

// captures LSU-formatted response after sync DMEM read
// keeps the load value stable until following LOAD_WB state.
module MemoryDataRegister (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_enable,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_o <= 32'h0000_0000;
        else if (write_enable)
            data_o <= data_i;
    end
endmodule

`default_nettype wire