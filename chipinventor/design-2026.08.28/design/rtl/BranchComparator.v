`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 15:56:54
// Design Name: 
// Module Name: BranchComparator
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


module BranchComparator(
    input signed [31:0] reg_rs_1,
    input signed [31:0] reg_rs_2,
    input [2:0] Branch_Sel,         // Matches funct3 [14:12] from the instruction
    output reg o_Branch_Taken
);

    /* Branch Funct3 Codes */
    localparam c_BEQ  = 3'b000;
    localparam c_BNE  = 3'b001;
    localparam c_BLT  = 3'b100;
    localparam c_BGE  = 3'b101;
    localparam c_BLTU = 3'b110;
    localparam c_BGEU = 3'b111;

    /* Comparison Logic */
    wire w_Branch_Equal              = (reg_rs_1 == reg_rs_2);
    wire w_Branch_Less_Than_Signed   = (reg_rs_1 < reg_rs_2);
    wire w_Branch_Less_Than_Unsigned = ($unsigned(reg_rs_1) < $unsigned(reg_rs_2));

    always @ (*) begin
        case (Branch_Sel)
            c_BEQ:  o_Branch_Taken = w_Branch_Equal;
            c_BNE:  o_Branch_Taken = !w_Branch_Equal;
            c_BLT:  o_Branch_Taken = w_Branch_Less_Than_Signed;
            c_BGE:  o_Branch_Taken = !w_Branch_Less_Than_Signed;
            c_BLTU: o_Branch_Taken = w_Branch_Less_Than_Unsigned;
            c_BGEU: o_Branch_Taken = !w_Branch_Less_Than_Unsigned;
            default: o_Branch_Taken = 1'b0;
        endcase
    end

endmodule