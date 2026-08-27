`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:10:37
// Design Name: 
// Module Name: IMEM
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




module IMEM #(
    parameter WORDS = 1048576 // 4 MB / 4 bytes per word (0x00400000 to 0x007FFFFC)
)(
    input  wire        clk,
    input  wire [31:0] imem_addr,   // Relative address from decoder (0x00000000 - 0x003FFFFC)
    input  wire        read_enable,
    output wire [31:0] imem_output
);

    // Memory array (Word-addressable)
    reg [31:0] mem [0:WORDS-1];

    // Initialize memory to zero before reading hex firmware
    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
        $readmemh("firmware.hex", mem);
    end

    // Word indexing: Bits [21:2] select words 0 to 1,048,575
    wire [19:0] word_idx = imem_addr[21:2];

    assign imem_output = (read_enable) ? mem[word_idx] : 32'h00000000;

endmodule