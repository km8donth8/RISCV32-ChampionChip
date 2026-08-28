`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.08.2026 21:55:15
// Design Name: 
// Module Name: RegisterFile
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
module RegisterFile #(
    parameter DATA_MEM_SIZE = 2**10
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        reg_write,
    input  wire [31:0] reg_rd_data,
    input  wire [31:0] instruction,
    output wire [31:0] reg_rs_1_data,
    output wire [31:0] reg_rs_2_data
);

    // Constants
    localparam SP_INDEX         = 5'd2;
    localparam GP_INDEX         = 5'd3;
    localparam GP_INITIAL_VALUE = 32'h1001_0000;
    localparam SP_INITIAL_VALUE = GP_INITIAL_VALUE + DATA_MEM_SIZE - 4;

    // Instruction field decoding
    wire [4:0] reg_rd_addr   = instruction[11:7];
    wire [4:0] reg_rs_1_addr = instruction[19:15];
    wire [4:0] reg_rs_2_addr = instruction[24:20];

    // 32 General-Purpose 32-bit Registers (x0 to x31)
    reg [31:0] regs [0:31];

    integer i;

    // --- SYNCHRONOUS WRITES & RESET ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                case (i)
                    SP_INDEX: regs[i] <= SP_INITIAL_VALUE;
                    GP_INDEX: regs[i] <= GP_INITIAL_VALUE;
                    default:  regs[i] <= 32'h0000_0000;
                endcase
            end
        end else begin
            // Synchronous Write (x0 write protected)
            if (reg_write && (reg_rd_addr != 5'b00000)) begin
                regs[reg_rd_addr] <= reg_rd_data;
            end
        end
    end

    // --- ASYNCHRONOUS READS ---
    // General Purpose Register outputs (x0 strictly hardwired to 0)
    assign reg_rs_1_data = (reg_rs_1_addr == 5'b00000) ? 32'h0 : regs[reg_rs_1_addr];
    assign reg_rs_2_data = (reg_rs_2_addr == 5'b00000) ? 32'h0 : regs[reg_rs_2_addr];

endmodule