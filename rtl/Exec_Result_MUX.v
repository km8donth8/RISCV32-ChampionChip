`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.09.2026 19:12:02
// Design Name: 
// Module Name: Exec_Result_MUX
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


module Exec_Result_MUX (
    input  wire [31:0] alu_result,
    input  wire [31:0] mult_result,
    input  wire [31:0] crc_result,
    input  wire [1:0]  exec_result_sel,

    output reg  [31:0] exec_result
);

always @(*) begin
    case (exec_result_sel)
        2'b00: exec_result = alu_result;
        2'b01: exec_result = mult_result;
        2'b10: exec_result = crc_result;
        default: exec_result = 32'h00000000;
    endcase
end

endmodule