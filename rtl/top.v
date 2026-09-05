

//  ---------- INLCUDED BLOCK: AddressDecoder  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 00:13:47
// Design Name: 
// Module Name: AddressDecoder
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


module AddressDecoder (
    input  wire [31:0] addr_i,          // Address from LSU / MUX
    input  wire        read_enable_i,   // Read signal from Control Unit
    input  wire        write_enable_i,  // Write signal from Control Unit
    input  wire [3:0]  bw_i,            // Byte-write mask from LSU

    output reg  [31:0] imem_addr_o,     // Local address offset for IMEM
    output reg         imem_read_en_o,  // IMEM read enable
    
    output reg  [31:0] dmem_addr_o,     // Local address offset for DMEM
    output reg         dmem_read_en_o,  // DMEM read enable
    output reg         dmem_write_en_o, // DMEM write enable
    output reg  [3:0]  dmem_bw_o,       // Byte-write mask forwarded to DMEM
    
    output reg         addr_decoder_sel // MUX select (0: IMEM, 1: DMEM)
);

    // Memory Range Constants
    localparam IMEM_BASE = 32'h00400000;
    localparam IMEM_HIGH = 32'h007FFFFF; // 4 MB Range

    localparam DMEM_BASE = 32'h10010000;
    localparam DMEM_HIGH = 32'h10011FFF; // 8 kB Range (0x2000 bytes)

    always @(*) begin
        // Default Outputs
        imem_addr_o      = 32'h0;
        imem_read_en_o   = 1'b0;
        dmem_addr_o      = 32'h0;
        dmem_read_en_o   = 1'b0;
        dmem_write_en_o  = 1'b0;
        dmem_bw_o        = 4'b0000;
        addr_decoder_sel = 1'b0;

        // IMEM Address Decoding
        if (addr_i >= IMEM_BASE && addr_i <= IMEM_HIGH) begin
            imem_addr_o      = addr_i - IMEM_BASE; // Map 0x00400000 -> 0x00000000
            imem_read_en_o   = read_enable_i;
            addr_decoder_sel = 1'b0;
        end
        // DMEM Address Decoding
        else if (addr_i >= DMEM_BASE && addr_i <= DMEM_HIGH) begin
            dmem_addr_o      = addr_i - DMEM_BASE; // Map 0x10010000 -> 0x00000000
            dmem_read_en_o   = read_enable_i;
            dmem_write_en_o  = write_enable_i;
            dmem_bw_o        = bw_i;
            addr_decoder_sel = 1'b1;
        end
    end

endmodule



//  ---------- INLCUDED BLOCK: ALU  ---------- 
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



//  ---------- INLCUDED BLOCK: BranchComparator  ---------- 
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



//  ---------- INLCUDED BLOCK: ControlUnit  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ControlUnit.v - multicycle FSM for the RV32I_Zmmul_Xicrc core
//
// States (one clock each):
//   FETCH      : IR <= MEM[PC]
//   DECODE     : A <= rs1, B <= rs2
//   EXECUTE    : ALU_out <= ALU(A/PC, B/imm)      (also mult / crc / branch compare)
//   MEM_LOAD   : MDR <= MEM[ALU_out]
//   MEM_STORE  : MEM[ALU_out] <= B ; PC <= PC+4
//   BRANCH     : PC <= taken ? ALU_out : PC+4
//   WRITEBACK  : rd <= wb_mux ; PC <= (jal/jalr) ? ALU_out : PC+4
//   SYS        : fence / ecall -> no operation, PC <= PC+4
//   HALT       : ebreak -> stay here forever (halt = 1)
//
// Select codes follow the Block Guide: ALU Table 9, MULT Table 10, CRC Table 11.
//////////////////////////////////////////////////////////////////////////////////
module ControlUnit(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] instruction,   // contents of the IR
    input  wire        branch_taken,  // from BranchComparator
    // datapath register enables
    output reg         ir_write,
    output reg         ab_write,      // A (rs1) and B (rs2) registers
    output reg         alu_write,     // ALU output register
    output reg         mdr_write,     // memory data register
    output reg         pc_write,
    output reg         pc_sel,        // 0 = PC+4, 1 = ALU_out (jump / branch target)
    output reg         reg_write,
    output reg  [2:0]  wb_sel,        // 0 ALU_out, 1 MDR, 2 MULT, 3 CRC, 4 PC+4
    output reg  [3:0]  alu_control,   // Table 9
    output reg         a_sel,         // ALU A: 0 = rs1, 1 = PC
    output reg         b_sel,         // ALU B: 0 = rs2, 1 = immediate
    output reg         mem_addr_sel,  // memory address: 0 = PC (fetch), 1 = ALU_out (load/store)
    output reg         mem_read,
    output reg         mem_write,
    output reg  [2:0]  op_size,       // LSU op codes (LW=0,LH=1,LB=2,LHU=3,LBU=4,SW=5,SH=6,SB=7)
    output wire [3:0]  mult_sel,      // Table 10
    output wire [1:0]  crc_sel,       // Table 11
    output wire [2:0]  branch_sel,    // funct3
    output reg         halt,
    output reg  [3:0]  state
);
    // ---- opcodes ----------------------------------------------------------
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_FENCE  = 7'b0001111;
    localparam OP_SYSTEM = 7'b1110011;

    // ---- ALU codes (Table 9) ---------------------------------------------
    localparam ALU_PASS_B = 4'h0, ALU_ADD = 4'h1, ALU_SUB = 4'h2, ALU_AND = 4'h3,
               ALU_OR = 4'h4, ALU_XOR = 4'h5, ALU_SLL = 4'h6, ALU_SRL = 4'h7,
               ALU_SRA = 4'h8, ALU_SLT = 4'h9, ALU_SLTU = 4'hA;

    // ---- states ------------------------------------------------------------
    localparam S_FETCH = 4'd0, S_DECODE = 4'd1, S_EXECUTE = 4'd2, S_MEM_LOAD = 4'd3,
               S_MEM_STORE = 4'd4, S_BRANCH = 4'd5, S_WRITEBACK = 4'd6, S_SYS = 4'd7,
               S_HALT = 4'd8;

    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire       is_mult = (opcode == OP_RTYPE) && (funct7 == 7'b0000001);
    wire       is_crc  = (opcode == OP_RTYPE) && (funct7 == 7'b1000000);
    wire       is_ebreak = (opcode == OP_SYSTEM) && (instruction[20] == 1'b1);

    assign mult_sel   = {2'b00, funct3[1:0]};   // mul=0 mulh=1 mulhsu=2 mulhu=3
    assign crc_sel    = funct3[1:0];            // crcb=0 crch=1 crcw=2
    assign branch_sel = funct3;

    // ALU code from funct3 (alt = SUB / SRA variant)
    function [3:0] alu_from_funct3(input [2:0] f3, input alt);
        case (f3)
            3'b000: alu_from_funct3 = alt ? ALU_SUB : ALU_ADD;
            3'b001: alu_from_funct3 = ALU_SLL;
            3'b010: alu_from_funct3 = ALU_SLT;
            3'b011: alu_from_funct3 = ALU_SLTU;
            3'b100: alu_from_funct3 = ALU_XOR;
            3'b101: alu_from_funct3 = alt ? ALU_SRA : ALU_SRL;
            3'b110: alu_from_funct3 = ALU_OR;
            default: alu_from_funct3 = ALU_AND;
        endcase
    endfunction

    wire [3:0] rtype_alu = alu_from_funct3(funct3, instruction[30]);
    wire [3:0] itype_alu = alu_from_funct3(funct3, (funct3 == 3'b101) ? instruction[30] : 1'b0);

    // LSU op_size from funct3
    reg [2:0] load_size, store_size;
    always @(*) begin
        case (funct3)
            3'b000:  load_size = 3'b010; // lb
            3'b001:  load_size = 3'b001; // lh
            3'b010:  load_size = 3'b000; // lw
            3'b100:  load_size = 3'b100; // lbu
            3'b101:  load_size = 3'b011; // lhu
            default: load_size = 3'b000;
        endcase
        case (funct3)
            3'b000:  store_size = 3'b111; // sb
            3'b001:  store_size = 3'b110; // sh
            default: store_size = 3'b101; // sw
        endcase
    end

    // ---- state register ----------------------------------------------------
    reg [3:0] next_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_FETCH;
        else        state <= next_state;
    end

    // ---- next state + outputs ---------------------------------------------
    always @(*) begin
        // defaults: nothing enabled
        ir_write = 0; ab_write = 0; alu_write = 0; mdr_write = 0;
        pc_write = 0; pc_sel = 0; reg_write = 0; wb_sel = 3'd0;
        alu_control = ALU_ADD; a_sel = 0; b_sel = 0;
        mem_addr_sel = 0; mem_read = 0; mem_write = 0; op_size = 3'b000;
        halt = 0;
        next_state = S_FETCH;

        case (state)
            S_FETCH: begin
                mem_addr_sel = 0; mem_read = 1; op_size = 3'b000; // read a word at PC
                ir_write = 1;
                next_state = S_DECODE;
            end

            S_DECODE: begin
                ab_write = 1;
                case (opcode)
                    OP_RTYPE, OP_ITYPE, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR,
                    OP_BRANCH, OP_LOAD, OP_STORE: next_state = S_EXECUTE;
                    OP_SYSTEM: next_state = is_ebreak ? S_HALT : S_SYS;
                    default:   next_state = S_SYS;   // fence and anything unknown: no-op
                endcase
            end

            S_EXECUTE: begin
                alu_write = 1;
                case (opcode)
                    OP_RTYPE:  begin alu_control = rtype_alu; a_sel = 0; b_sel = 0; next_state = S_WRITEBACK; end
                    OP_ITYPE:  begin alu_control = itype_alu; a_sel = 0; b_sel = 1; next_state = S_WRITEBACK; end
                    OP_LUI:    begin alu_control = ALU_PASS_B; a_sel = 0; b_sel = 1; next_state = S_WRITEBACK; end
                    OP_AUIPC:  begin alu_control = ALU_ADD; a_sel = 1; b_sel = 1; next_state = S_WRITEBACK; end
                    OP_JAL:    begin alu_control = ALU_ADD; a_sel = 1; b_sel = 1; next_state = S_WRITEBACK; end
                    OP_JALR:   begin alu_control = ALU_ADD; a_sel = 0; b_sel = 1; next_state = S_WRITEBACK; end
                    OP_BRANCH: begin alu_control = ALU_ADD; a_sel = 1; b_sel = 1; next_state = S_BRANCH; end
                    OP_LOAD:   begin alu_control = ALU_ADD; a_sel = 0; b_sel = 1; next_state = S_MEM_LOAD; end
                    OP_STORE:  begin alu_control = ALU_ADD; a_sel = 0; b_sel = 1; next_state = S_MEM_STORE; end
                    default:   next_state = S_FETCH;
                endcase
            end

            S_MEM_LOAD: begin
                mem_addr_sel = 1; mem_read = 1; op_size = load_size;
                mdr_write = 1;
                next_state = S_WRITEBACK;
            end

            S_MEM_STORE: begin
                mem_addr_sel = 1; mem_write = 1; op_size = store_size;
                pc_write = 1; pc_sel = 0;
                next_state = S_FETCH;
            end

            S_BRANCH: begin
                pc_write = 1; pc_sel = branch_taken;
                next_state = S_FETCH;
            end

            S_WRITEBACK: begin
                reg_write = 1;
                case (opcode)
                    OP_RTYPE: wb_sel = is_mult ? 3'd2 : (is_crc ? 3'd3 : 3'd0);
                    OP_LOAD:  wb_sel = 3'd1;
                    OP_JAL, OP_JALR: wb_sel = 3'd4;
                    default:  wb_sel = 3'd0;
                endcase
                pc_write = 1;
                pc_sel = (opcode == OP_JAL) || (opcode == OP_JALR);
                next_state = S_FETCH;
            end

            S_SYS: begin
                pc_write = 1; pc_sel = 0;
                next_state = S_FETCH;
            end

            S_HALT: begin
                halt = 1;
                next_state = S_HALT;
            end

            default: next_state = S_FETCH;
        endcase
    end
endmodule



//  ---------- INLCUDED BLOCK: CRC  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 19:34:37
// Design Name: 
// Module Name: CRC
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


// module CRC (
//     input wire [31:0] reg_rs_1, // Input data payload
//     input wire [15:0] reg_rs_2, // Current 16-bit seed or chained previous CRC
//     input wire [1:0]  crc_sel,  // Mode Select: 2'b00 = 8-bit, 2'b01 = 16-bit, 2'b10 = 32-bit
//     output reg [31:0] rd    // Zero-extended 16-bit CRC output result
// );

//     wire [15:0] crc8_out;
//     wire [15:0] crc16_out;
//     wire [15:0] crc32_out;

//     // ------------------------------------------------------------------------
//     // 8-bit Input Mode Engine (Processes reg_rs_1[7:0])
//     // ------------------------------------------------------------------------
//     crc_calc #(
//         .POLY(64'h1021),
//         .CRC_SIZE(16),
//         .DATA_WIDTH(8),
//         .REF_IN(0),
//         .REF_OUT(0),
//         .XOR_OUT(64'h0000)
//     ) u_crc8 (
//         .crc_in(reg_rs_2),
//         .data_i(reg_rs_1[7:0]),
//         .crc_o(crc8_out)
//     );

//     // ------------------------------------------------------------------------
//     // 16-bit Input Mode Engine (Processes reg_rs_1[15:0])
//     // ------------------------------------------------------------------------
//     crc_calc #(
//         .POLY(64'h1021),
//         .CRC_SIZE(16),
//         .DATA_WIDTH(16),
//         .REF_IN(0),
//         .REF_OUT(0),
//         .XOR_OUT(64'h0000)
//     ) u_crc16 (
//         .crc_in(reg_rs_2),
//         .data_i(reg_rs_1[15:0]),
//         .crc_o(crc16_out)
//     );

//     // ------------------------------------------------------------------------
//     // 32-bit Input Mode Engine (Processes reg_rs_1[31:0])
//     // ------------------------------------------------------------------------
//     crc_calc #(
//         .POLY(64'h1021),
//         .CRC_SIZE(16),
//         .DATA_WIDTH(32),
//         .REF_IN(0),
//         .REF_OUT(0),
//         .XOR_OUT(64'h0000)
//     ) u_crc32 (
//         .crc_in(reg_rs_2),
//         .data_i(reg_rs_1[31:0]),
//         .crc_o(crc32_out)
//     );

//     // ------------------------------------------------------------------------
//     // Output Select Multiplexer
//     // ------------------------------------------------------------------------
//     always @(*) begin
//         case (crc_sel)
//             2'b00:   rd = {16'h0000, crc8_out};  // 8-bit Input
//             2'b01:   rd = {16'h0000, crc16_out}; // 16-bit Input
//             2'b10:   rd = {16'h0000, crc32_out}; // 32-bit Input
//             default: rd = 32'h0000_0000;
//         endcase
//     end

// endmodule


module CRC (
    input wire [31:0] reg_rs_1, // Input data payload
    input wire [31:0] reg_rs_2, // 32-bit register input (uses [15:0] as seed/chained CRC)
    input wire [1:0]  crc_sel,  // Mode Select: 2'b00 = 8-bit, 2'b01 = 16-bit, 2'b10 = 32-bit
    output reg [31:0] rd        // Zero-extended 16-bit CRC output result
);

    wire [15:0] crc8_out;
    wire [15:0] crc16_out;
    wire [15:0] crc32_out;

    // ------------------------------------------------------------------------
    // 8-bit Input Mode Engine (Processes reg_rs_1[7:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h1021),
        .CRC_SIZE(16),
        .DATA_WIDTH(8),
        .REF_IN(0),
        .REF_OUT(0),
        .XOR_OUT(64'h0000)
    ) u_crc8 (
        .crc_in(reg_rs_2[15:0]),
        .data_i(reg_rs_1[7:0]),
        .crc_o(crc8_out)
    );

    // ------------------------------------------------------------------------
    // 16-bit Input Mode Engine (Processes reg_rs_1[15:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h1021),
        .CRC_SIZE(16),
        .DATA_WIDTH(16),
        .REF_IN(0),
        .REF_OUT(0),
        .XOR_OUT(64'h0000)
    ) u_crc16 (
        .crc_in(reg_rs_2[15:0]),
        .data_i(reg_rs_1[15:0]),
        .crc_o(crc16_out)
    );

    // ------------------------------------------------------------------------
    // 32-bit Input Mode Engine (Processes reg_rs_1[31:0])
    // ------------------------------------------------------------------------
    crc_calc #(
        .POLY(64'h1021),
        .CRC_SIZE(16),
        .DATA_WIDTH(32),
        .REF_IN(0),
        .REF_OUT(0),
        .XOR_OUT(64'h0000)
    ) u_crc32 (
        .crc_in(reg_rs_2[15:0]),
        .data_i(reg_rs_1[31:0]),
        .crc_o(crc32_out)
    );

    // ------------------------------------------------------------------------
    // Output Select Multiplexer
    // ------------------------------------------------------------------------
    always @(*) begin
        case (crc_sel)
            2'b00:   rd = {16'h0000, crc8_out};  // 8-bit Input
            2'b01:   rd = {16'h0000, crc16_out}; // 16-bit Input
            2'b10:   rd = {16'h0000, crc32_out}; // 32-bit Input
            default: rd = 32'h0000_0000;
        endcase
    end

endmodule



//  ---------- INLCUDED BLOCK: crc_calc  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 20:30:06
// Design Name: 
// Module Name: crc_calc
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

module crc_calc #(
    parameter [63:0]  POLY       = 64'h8005,
    parameter integer CRC_SIZE   = 16,
    parameter integer DATA_WIDTH = 8,
    parameter integer REF_IN     = 1,
    parameter integer REF_OUT    = 1,
    parameter [63:0]  XOR_OUT    = 64'hFFFF
)(
    input  [CRC_SIZE - 1 : 0]   crc_in,   // Seed or previous CRC result from reg_rs_2
    input  [DATA_WIDTH - 1 : 0] data_i,   // Data payload segment
    output [CRC_SIZE - 1 : 0]   crc_o     // Calculated 16-bit CRC output
);

    // Un-XOR the incoming seed state so output results can chain directly back into crc_in
    wire [CRC_SIZE - 1 : 0] current_state = crc_in ^ XOR_OUT[CRC_SIZE - 1 : 0];

    reg [CRC_SIZE - 1 : 0] crc_next;
    reg [CRC_SIZE - 1 : 0] crc_prev;

    integer i, j;

    assign crc_o = crc_next ^ XOR_OUT[CRC_SIZE - 1 : 0];

    generate
        if (REF_OUT) begin : g_ref_out
            if (REF_IN) begin : g_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[CRC_SIZE - 1] = crc_prev[0] ^ data_i[i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j] ^ crc_prev[0] ^ data_i[i];
                            else
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j];
                        end
                        crc_prev = crc_next;
                    end
                end
            end else begin : g_n_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[0] = crc_prev[CRC_SIZE - 1] ^ data_i[i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[j] = crc_prev[j - 1] ^ crc_prev[CRC_SIZE - 1] ^ data_i[i];
                            else
                                crc_next[j] = crc_prev[j - 1];
                        end
                        crc_prev = crc_next;
                    end
                end
            end
        end else begin : g_n_ref_out
            if (REF_IN) begin : g_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[CRC_SIZE - 1] = crc_prev[0] ^ data_i[DATA_WIDTH - 1 - i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j] ^ crc_prev[0] ^ data_i[DATA_WIDTH - 1 - i];
                            else
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j];
                        end
                        crc_prev = crc_next;
                    end
                end
            end else begin : g_n_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[0] = crc_prev[CRC_SIZE - 1] ^ data_i[DATA_WIDTH - 1 - i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[j] = crc_prev[j - 1] ^ crc_prev[CRC_SIZE - 1] ^ data_i[DATA_WIDTH - 1 - i];
                            else
                                crc_next[j] = crc_prev[j - 1];
                        end
                        crc_prev = crc_next;
                    end
                end
            end
        end
    endgenerate

endmodule



//  ---------- INLCUDED BLOCK: DMEM  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:09:48
// Design Name: 
// Module Name: DMEM
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

module DMEM #(
    parameter WORDS = 2048 // 8 kB / 4 bytes per word
)(
    input  wire        clk,
    input  wire [31:0] dmem_addr,    // Relative address from decoder
    input  wire [31:0] dmem_data_i,  // Shifted store payload from LSU
    input  wire [3:0]  bw,           // Byte-write mask from decoder
    input  wire        write_enable,
    input  wire        read_enable,
    output wire [31:0] dmem_output
);

    // Memory array: 4 byte lanes per word
    reg [7:0] mem_b0 [0:WORDS-1];
    reg [7:0] mem_b1 [0:WORDS-1];
    reg [7:0] mem_b2 [0:WORDS-1];
    reg [7:0] mem_b3 [0:WORDS-1];

    // Initialize memory to zero to prevent 'x' propagation in simulation
    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            mem_b0[i] = 8'h00;
            mem_b1[i] = 8'h00;
            mem_b2[i] = 8'h00;
            mem_b3[i] = 8'h00;
        end
    end

    // Word indexing: Ignore lower 2 offset bits (Range: 0 to 2047)
    wire [10:0] word_idx = dmem_addr[12:2];

    // Synchronous Byte-Lane Write Operations
    always @(posedge clk) begin
        if (write_enable) begin
            if (bw[0]) mem_b0[word_idx] <= dmem_data_i[7:0];
            if (bw[1]) mem_b1[word_idx] <= dmem_data_i[15:8];
            if (bw[2]) mem_b2[word_idx] <= dmem_data_i[23:16];
            if (bw[3]) mem_b3[word_idx] <= dmem_data_i[31:24];
        end
    end

    // Combinational Read Output
    assign dmem_output = (read_enable) ? 
                         {mem_b3[word_idx], mem_b2[word_idx], mem_b1[word_idx], mem_b0[word_idx]} : 
                         32'h00000000;

endmodule



//  ---------- INLCUDED BLOCK: IMEM  ---------- 
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
    parameter WORDS = 1048576, // 4 MB / 4 bytes per word (0x00400000 to 0x007FFFFC)
    parameter FIRMWARE = "firmware.hex" // hex file loaded at simulation start
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
        $readmemh(FIRMWARE, mem);
    end

    // Word indexing: Bits [21:2] select words 0 to 1,048,575
    wire [19:0] word_idx = imem_addr[21:2];

    assign imem_output = (read_enable) ? mem[word_idx] : 32'h00000000;

endmodule



//  ---------- INLCUDED BLOCK: ImmediateGenerator  ---------- 
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



//  ---------- INLCUDED BLOCK: MemoryUnit  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:39:11
// Design Name: 
// Module Name: MemoryUnit
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


module MemoryUnit #(
    parameter FIRMWARE = "firmware.hex"
)(
    input  wire        clk,
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,     // rs2 data from core for stores
    input  wire [31:0] core_address_o,  // Memory address from core
    output wire [31:0] core_data_i      // Formatted load data to core
);

    // -------------------------------------------------------------------------
    // Internal Wires for Interconnects
    // -------------------------------------------------------------------------
    // LSU to Address Decoder
    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;

    // Address Decoder to IMEM
    wire [31:0] imem_addr;
    wire        imem_read_en;

    // Address Decoder to DMEM
    wire [31:0] dmem_addr;
    wire        dmem_read_en;
    wire        dmem_write_en;
    wire [3:0]  dmem_bw;

    // MUX and Memory Read Outputs
    wire        addr_decoder_sel;
    wire [31:0] imem_out;
    wire [31:0] dmem_out;
    wire [31:0] mux_mem_data_out;

    // -------------------------------------------------------------------------
    // 1. Read Data MUX (0: IMEM, 1: DMEM)
    // -------------------------------------------------------------------------
    assign mux_mem_data_out = (addr_decoder_sel) ? dmem_out : imem_out;

    // -------------------------------------------------------------------------
    // 2. Load-Store Unit (LSU) Instance
    // -------------------------------------------------------------------------
    LSU u_lsu (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),

        .mem_address_i (lsu_mem_addr),
        .mem_data_i    (lsu_mem_data),
        .byte_write_i  (lsu_byte_write),
        .mem_data_o    (mux_mem_data_out)
    );

    // -------------------------------------------------------------------------
    // 3. Address Decoder Instance
    // -------------------------------------------------------------------------
    AddressDecoder u_addr_decoder (
        .addr_i          (lsu_mem_addr),
        .read_enable_i   (read_enable),
        .write_enable_i  (write_enable),
        .bw_i            (lsu_byte_write),

        .imem_addr_o     (imem_addr),
        .imem_read_en_o  (imem_read_en),

        .dmem_addr_o     (dmem_addr),
        .dmem_read_en_o  (dmem_read_en),
        .dmem_write_en_o (dmem_write_en),
        .dmem_bw_o       (dmem_bw),

        .addr_decoder_sel(addr_decoder_sel)
    );

    // -------------------------------------------------------------------------
    // 4. Instruction Memory (IMEM) Instance
    // -------------------------------------------------------------------------
    IMEM #(
        .WORDS(1048576),
        .FIRMWARE(FIRMWARE)
    ) u_imem (
        .clk        (clk),
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    // -------------------------------------------------------------------------
    // 5. Data Memory (DMEM) Instance
    // -------------------------------------------------------------------------
    DMEM #(
        .WORDS(2048)
    ) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

endmodule



//  ---------- INLCUDED BLOCK: Multiplier  ---------- 
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 10:55:44
// Design Name: 
// Module Name: Multiplier
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


`define MUL 4'h0
`define MULH 4'h1
`define MULHSU 4'h2
`define MULHU 4'h3

module Multiplier(
    input [31:0] reg_rs_1,
    input [31:0] reg_rs_2,
    input  [3:0]  mult_sel,
    output reg [31:0] rd
    );
    //All 3 values are always calculated just use mux to selct the values
    wire signed [63:0] mul_ss; // Signed x Signed => Signed
    wire signed [63:0] mul_su; // Signed x Unsigned => Signed
    wire        [63:0] mul_uu; // Unsigned x Unsigned => Unsigned

    // Compute 64-bit intermediate products
    assign mul_ss = $signed(reg_rs_1) * $signed(reg_rs_2);
    assign mul_su = $signed({reg_rs_1[31], reg_rs_1}) * $signed({1'b0, reg_rs_2}); // Zero-extend rs2 to prevent sign treatment
    assign mul_uu = $unsigned(reg_rs_1) * $unsigned(reg_rs_2);

    always @(*) begin
        case (mult_sel)
            `MUL: rd = mul_ss[31:0];  // MUL  : lower 32 bits (Signed or Unsigned give same lower bits)
            `MULH: rd = mul_ss[63:32]; // MULH : upper 32 bits (Signed * Signed)
            `MULHSU: rd = mul_su[63:32]; // MULHSU: upper 32 bits (Signed * Unsigned)
            `MULHU: rd = mul_uu[63:32]; // MULHU: upper 32 bits (Unsigned * Unsigned)
            default: rd = 32'h0;
        endcase
    end 
endmodule



//  ---------- INLCUDED BLOCK: ProgramCounter  ---------- 
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
    input wire        PC_write,      // Write enable: PC only changes when the control unit says so (multicycle)
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
        end else if (PC_write) begin
            r_PC_Output <= w_PC_Next;
        end
    end

    // Continuous assignments require output signals to be 'wire'
    assign o_PC_Output = r_PC_Output;
    assign o_PC_Plus_4 = r_PC_Output + 4;

endmodule



//  ---------- INLCUDED BLOCK: RegisterFile  ---------- 
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



//  ---------- INLCUDED BLOCK: IR_Register  ---------- 
module IR_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ir_write,
    input  wire [31:0] mem_rdata,
    output reg  [31:0] ir
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ir <= 32'h00000000;
    else if (ir_write)
        ir <= mem_rdata;
end

endmodule



//  ---------- INLCUDED BLOCK: A_Register  ---------- 
module A_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ab_write,
    input  wire [31:0] rs1_data,
    output reg  [31:0] A
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        A <= 32'h00000000;
    else if (ab_write)
        A <= rs1_data;
end

endmodule



//  ---------- INLCUDED BLOCK: B_Register  ---------- 
module B_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ab_write,
    input  wire [31:0] rs2_data,
    output reg  [31:0] B
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        B <= 32'h00000000;
    else if (ab_write)
        B <= rs2_data;
end

endmodule



//  ---------- INLCUDED BLOCK: ALU_OUT_Register  ---------- 
module ALU_OUT_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        alu_write,
    input  wire [31:0] alu_q,
    output reg  [31:0] alu_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_out <= 32'h00000000;
    else if (alu_write)
        alu_out <= alu_q;
end

endmodule



//  ---------- INLCUDED BLOCK: MDR_Register  ---------- 
module MDR_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mdr_write,
    input  wire [31:0] mem_rdata,
    output reg  [31:0] mdr
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        mdr <= 32'h00000000;
    else if (mdr_write)
        mdr <= mem_rdata;
end

endmodule



//  ---------- INLCUDED BLOCK: WB_MUX  ---------- 
module WB_MUX (
    input  wire [31:0] alu_out,
    input  wire [31:0] mdr,
    input  wire [31:0] mult_result,
    input  wire [31:0] crc_result,
    input  wire [31:0] pc_plus4,
    input  wire [2:0]  wb_sel,

    output reg  [31:0] wb_data
);

always @(*) begin
    case (wb_sel)
        3'd0: wb_data = alu_out;
        3'd1: wb_data = mdr;
        3'd2: wb_data = mult_result;
        3'd3: wb_data = crc_result;
        3'd4: wb_data = pc_plus4;
        default: wb_data = 32'h00000000;
    endcase
end

endmodule



//  ---------- INLCUDED BLOCK: Memory_Address_MUX  ---------- 
module Memory_Address_MUX (
    input  wire [31:0] pc,
    input  wire [31:0] alu_out,
    input  wire        mem_addr_sel,
    output wire [31:0] mem_addr
);

assign mem_addr = mem_addr_sel ? alu_out : pc;

endmodule



//  ---------- INLCUDED BLOCK: PC_Target_Align  ---------- 
module PC_Target_Align (
    input  wire [31:0] alu_out,
    output wire [31:0] pc_target
);

assign pc_target = {alu_out[31:1], 1'b0};

endmodule


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

  input wire clk,
  input wire rst_n,
  output wire o_halt

);

//Internal Wires
 wire [31:0] w_1;
 wire w_2;
 wire w_3;
 wire [31:0] w_4;
 wire [31:0] w_6;
 wire [31:0] w_7;
 wire w_8;
 wire [31:0] w_9;
 wire w_10;
 wire w_11;
 wire [2:0] w_12;
 wire [31:0] w_13;
 wire [31:0] w_14;
 wire w_16;
 wire [31:0] w_17;
 wire [31:0] w_20;
 wire w_21;
 wire w_22;
 wire w_23;
 wire w_25;
 wire w_26;
 wire [2:0] w_27;
 wire [3:0] w_28;
 wire w_29;
 wire w_30;
 wire [3:0] w_31;
 wire [1:0] w_32;
 wire [2:0] w_33;
 wire [31:0] w_34;
 wire [31:0] w_35;
 wire [31:0] w_36;
 wire [31:0] w_37;
 wire [31:0] w_38;
 wire [31:0] w_45;
 wire [31:0] w_46;
 wire [31:0] w_50;

//Instances of Modules
ProgramCounter blk3198_1 (
         .clk (clk),
         .rst_n (rst_n),
         .i_ALU_output (w_1),
         .PC_sel (w_2),
         .PC_write (w_3),
         .o_PC_Output (w_4),
         .o_PC_Plus_4 (w_6)
     );

Memory_Address_MUX blk3208_3 (
         .pc (w_4),
         .alu_out (w_7),
         .mem_addr_sel (w_8),
         .mem_addr (w_9)
     );

MemoryUnit #(.FIRMWARE("firmware.hex")) blk3196_4 (
         .clk (clk),
         .core_address_o (w_9),
         .write_enable (w_10),
         .read_enable (w_11),
         .op_size_o (w_12),
         .core_data_o (w_13),
         .core_data_i (w_14)
     );

ALU_OUT_Register blk3205_6 (
         .clk (clk),
         .rst_n (rst_n),
         .alu_out (w_7),
         .alu_write (w_16),
         .alu_q (w_17)
     );

ControlUnit blk3189_7 (
         .clk (clk),
         .rst_n (rst_n),
         .halt (o_halt),
         .pc_sel (w_2),
         .pc_write (w_3),
         .mem_addr_sel (w_8),
         .mem_write (w_10),
         .mem_read (w_11),
         .op_size (w_12),
         .alu_write (w_16),
         .instruction (w_20),
         .branch_taken (w_21),
         .ir_write (w_22),
         .ab_write (w_23),
         .mdr_write (w_25),
         .reg_write (w_26),
         .wb_sel (w_27),
         .alu_control (w_28),
         .a_sel (w_29),
         .b_sel (w_30),
         .mult_sel (w_31),
         .crc_sel (w_32),
         .branch_sel (w_33)
     );

WB_MUX blk3207_9 (
         .pc_plus4 (w_6),
         .alu_out (w_7),
         .wb_sel (w_27),
         .mdr (w_34),
         .mult_result (w_35),
         .crc_result (w_36),
         .wb_data (w_37)
     );

B_Register blk3204_10 (
         .clk (clk),
         .rst_n (rst_n),
         .B (w_13),
         .ab_write (w_23),
         .rs2_data (w_38)
     );

IR_Register blk3202_11 (
         .clk (clk),
         .rst_n (rst_n),
         .mem_rdata (w_14),
         .ir (w_20),
         .ir_write (w_22)
     );

RegisterFile #(.DATA_MEM_SIZE(8192)) blk3199_13 (
         .clk (clk),
         .rst_n (rst_n),
         .reg_write (w_26),
         .reg_rd_data (w_37),
         .reg_rs_2_data (w_38),
         .instruction (w_20),
         .reg_rs_1_data (w_45)
     );

A_Register blk3203_17 (
         .clk (clk),
         .rst_n (rst_n),
         .ab_write (w_23),
         .rs1_data (w_45),
         .A (w_46)
     );

ALU blk3187_18 (
         .pc_output (w_4),
         .Q (w_17),
         .ALU_control (w_28),
         .A_sel (w_29),
         .B_sel (w_30),
         .reg_rs_2 (w_13),
         .reg_rs_1 (w_46),
         .immediate (w_50)
     );

BranchComparator blk3188_19 (
         .o_Branch_Taken (w_21),
         .Branch_Sel (w_33),
         .reg_rs_2 (w_13),
         .reg_rs_1 (w_46)
     );

Multiplier blk3197_20 (
         .mult_sel (w_31),
         .rd (w_35),
         .reg_rs_2 (w_13),
         .reg_rs_1 (w_46)
     );

CRC blk3190_21 (
         .crc_sel (w_32),
         .rd (w_36),
         .reg_rs_2 (w_13),
         .reg_rs_1 (w_46)
     );

PC_Target_Align blk3211_23 (
         .pc_target (w_1),
         .alu_out (w_7)
     );

ImmediateGenerator blk3194_25 (
         .instruction (w_20),
         .extended_immediate (w_50)
     );

MDR_Register blk3206_26 (
         .clk (clk),
         .rst_n (rst_n),
         .mem_rdata (w_14),
         .mdr_write (w_25),
         .mdr (w_34)
     );

AddressDecoder blk3186_27 (

     );

DMEM #(.WORDS(2048)) blk3192_28 (

     );

IMEM #(.WORDS(1048576), .FIRMWARE("firmware.hex")) blk3193_29 (

     );

crc_calc blk3191_30 (

     );


endmodule
