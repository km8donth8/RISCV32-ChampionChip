`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 15:24:05
// Design Name: 
// Module Name: ImmediateGenerator
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


module ImmediateGenerator(
    input wire [31:0] instruction,
    output reg [31:0] extended_immediate

    );

    /* Instruction Opcodes */
    
    // I-TYPE
    localparam c_OPCODE_JALR = 7'b1100111;
    localparam c_OPCODE_IMME_ALU = 7'b0010011;
    localparam c_OPCODE_SYS = 7'b1110011;
    localparam c_OPCODE_FENCE = 7'b0001111;

    // U-TYPE
    localparam c_OPCODE_LUI = 7'b0110111;
    localparam c_OPCODE_AUIPC = 7'b0010111;

    // S-TYPE
    localparam c_OPCODE_STORE  = 7'b0100011;
    
    // B-TYPE
    localparam c_OPCODE_BRANCH = 7'b1100011;

    // J-TYPE
    localparam c_OPCODE_JAL = 7'b1101111;


    wire [11:0] w_I_Type_Imm = instruction[31:20];
    wire [11:0] w_S_Type_Imm = {instruction[31:25], instruction[11:7]};
    wire [12:0] w_B_Type_Imm = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [20:0] w_J_Type_Imm = {instruction[31], instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], 1'b0};
    wire [31:0] w_U_Type_Imm = {instruction[31:12], 12'b0};

    always @ (*) begin
        case (instruction[6:0])
            c_OPCODE_JAL: 
                extended_immediate = $signed(w_J_Type_Imm);
            c_OPCODE_BRANCH: 
                extended_immediate = $signed(w_B_Type_Imm);
            c_OPCODE_STORE: 
                extended_immediate = $signed(w_S_Type_Imm);
            c_OPCODE_LUI, c_OPCODE_AUIPC: 
                extended_immediate = w_U_Type_Imm;
            default: 
                extended_immediate = $signed(w_I_Type_Imm);
        endcase
    end
endmodule
