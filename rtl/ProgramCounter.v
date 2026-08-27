`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.08.2026 12:48:54
// Design Name: 
// Module Name: ProgramCounter
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

module ProgramCounter(
    // Inputs (always wire in module port declarations)
    input wire [31:0] i_ALU_output,  // Branch / Jump target address input
    input wire        PC_sel,        // MUX select control signal (0 = PC+4, 1 = Target)
    input wire        clk,
    input wire        rst_n,

    // Outputs (wire because they are driven by 'assign' statements below)
    output wire [31:0] o_PC_Output, 
    output wire [31:0] o_PC_Plus_4
);
    localparam c_PC_INITIAL_VALUE = 32'h0040_0000;

    reg  [31:0] r_PC_Output;
    wire [31:0] w_PC_Next;

    // 2-to-1 Multiplexer for Next PC selection
    assign w_PC_Next = (PC_sel) ? i_ALU_output : o_PC_Plus_4;

    /* Program Counter (PC) Register */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_PC_Output <= c_PC_INITIAL_VALUE;
        end else begin
            r_PC_Output <= w_PC_Next;
        end
    end

    // Continuous assignments require output signals to be 'wire'
    assign o_PC_Output = r_PC_Output;
    assign o_PC_Plus_4 = r_PC_Output + 4;

endmodule

