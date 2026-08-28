`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.08.2026 14:14:31
// Design Name: 
// Module Name: ALU
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

//NOTE: ALU control signals
//funct7 [31:25] - lsb used
//funct3 [14:12] - all 3 used
//opcode [6:0] - fixed for R-type
//funct7[25] + funct3[14:12]

`define c_ALU_OP_PASS_B    4'h0
`define c_ALU_OP_ADD    4'h1
`define c_ALU_OP_SUB    4'h2
`define c_ALU_OP_AND    4'h3
`define c_ALU_OP_OR     4'h4
`define c_ALU_OP_XOR    4'h5
`define c_ALU_OP_SLL    4'h6
`define c_ALU_OP_SRL    4'h7
`define c_ALU_OP_MRS    4'h8
`define c_ALU_OP_SLT    4'h9
`define c_ALU_OP_SLTU    4'hA

module ALU(
    input wire [31:0] reg_rs_1,
    input wire [31:0] reg_rs_2,
    input wire [31:0] pc_output,
    input wire [31:0] immediate,
    input wire [3:0] ALU_control,
    input wire A_sel,
    input wire B_sel,
    output reg signed [31:0] Q
    );
    wire signed [31:0] A_Mux;

    wire signed [31:0] B_Mux;

    assign A_Mux = (A_sel) ? pc_output : reg_rs_1;
    
    assign B_Mux = (B_sel) ? immediate : reg_rs_2; 

    always @ (*) begin
        case (ALU_control)
            `c_ALU_OP_PASS_B:    Q = B_Mux;
            `c_ALU_OP_ADD:    Q = A_Mux + B_Mux;
            `c_ALU_OP_SUB:    Q = A_Mux - B_Mux;
            `c_ALU_OP_AND:    Q = A_Mux & B_Mux;
            `c_ALU_OP_OR:     Q = A_Mux | B_Mux;
            `c_ALU_OP_XOR:    Q = A_Mux ^ B_Mux;
            `c_ALU_OP_SLL:    Q = A_Mux << B_Mux[4:0]; //B stores the shifting value
            `c_ALU_OP_SRL:    Q = A_Mux >> B_Mux[4:0];
            `c_ALU_OP_MRS:    Q = A_Mux >>> B_Mux[4:0]; // Performs arithmetic right shift properly since A_Mux is signed
            `c_ALU_OP_SLT:    Q = (A_Mux < B_Mux) ? 32'h1 : 32'h0;
            `c_ALU_OP_SLTU:   Q = ($unsigned(A_Mux) < $unsigned(B_Mux)) ? 32'h1 : 32'h0; // Explicitly cast to unsigned
            default:          Q = 32'h0; // Prevents unwanted latches
            
        endcase
    end


endmodule