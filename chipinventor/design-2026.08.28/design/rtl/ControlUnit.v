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