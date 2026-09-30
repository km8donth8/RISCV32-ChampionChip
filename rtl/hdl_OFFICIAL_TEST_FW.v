

//  ---------- INLCUDED BLOCK: ALU_equipe41  ---------- 
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

module ALU_equipe41(
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



//  ---------- INLCUDED BLOCK: CRC_equipe41  ---------- 
module CRC_equipe41(
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



//  ---------- INLCUDED BLOCK: BranchComparator_equipe41  ---------- 
module BranchComparator_equipe41(
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



//  ---------- INLCUDED BLOCK: ImmediateGenerator_equipe41  ---------- 
module ImmediateGenerator_equipe41(
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

    // reference from the format in riscv instructions
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



//  ---------- INLCUDED BLOCK: Multiplier_equipe41  ---------- 
`define MUL 4'h0
`define MULH 4'h1
`define MULHSU 4'h2
`define MULHU 4'h3
module Multiplier_equipe41 (
    input  [31:0] reg_rs_1,
    input  [31:0] reg_rs_2,
    input  [3:0]  mult_sel,
    output reg [31:0] rd
);

    // Determine sign bit extensions
    wire a_is_signed = (mult_sel == `MUL) || (mult_sel == `MULH) || (mult_sel == `MULHSU);
    wire b_is_signed = (mult_sel == `MUL) || (mult_sel == `MULH);

    // Sign- or Zero-extend to 33 bits
    wire signed [32:0] op_a = $signed({a_is_signed & reg_rs_1[31], reg_rs_1});
    wire signed [32:0] op_b = $signed({b_is_signed & reg_rs_2[31], reg_rs_2});

    // 33x33 signed multiplication gives a 66-bit result
    wire signed [65:0] prod = op_a * op_b;

    always @(*) begin
        case (mult_sel)
            `MUL:    rd = prod[31:0];
            `MULH, 
            `MULHSU, 
            `MULHU:  rd = prod[63:32];
            default: rd = 32'h0;
        endcase
    end

endmodule



//  ---------- INLCUDED BLOCK: ProgramCounter_equipe41  ---------- 
module ProgramCounter_equipe41(
    // Inputs (always wire in module port declarations)
    input wire [31:0] i_ALU_output,  // Branch / Jump target address input
    input wire        PC_sel,        // MUX select control signal (0 = PC+4, 1 = Target)
    input wire        clk,
    input wire        PC_write, 
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
        end else if(PC_write) begin
            r_PC_Output <= w_PC_Next;
        end
    end

    // Continuous assignments require output signals to be 'wire'
    assign o_PC_Output = r_PC_Output;
    assign o_PC_Plus_4 = r_PC_Output + 4;

endmodule



//  ---------- INLCUDED BLOCK: RegisterFile_equipe41  ---------- 
module RegisterFile_equipe41 #(
    parameter DATA_MEM_SIZE = 2**13
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



//  ---------- INLCUDED BLOCK: PC_Target_Align_equipe41  ---------- 
module PC_Target_Align_equipe41 (
    input  wire [31:0] alu_out,
    input  wire        pc_lsb_clear,

    output wire [31:0] pc_target
);

assign pc_target = pc_lsb_clear
                 ? {alu_out[31:1], 1'b0}
                 : alu_out;

endmodule



//  ---------- INLCUDED BLOCK: ControlUnit_equipe41  ---------- 
module ControlUnit_equipe41 (
    input wire          clk
  , input wire          rst_n
  , input wire [31:0]   i_instruction
  , input wire          i_branch_taken
  
  // sequential datapath enables

  , output reg          o_pc_write
  , output reg          o_ir_write  
  , output reg          o_operand_write
  , output reg          o_aluout_write
  , output reg          o_mdr_write 
  , output reg          o_reg_write

  // pc path

  , output reg          o_pc_sel        
  , output reg          o_pc_lsb_clear

  // alu controls

  , output reg          o_alu_a_sel
  , output reg          o_alu_b_sel
  , output reg [3:0]    o_alu_control

  // datapath mux controls including exec result
  , output reg [1:0]    o_exec_result_sel
  , output reg [1:0]    o_wb_sel
  , output reg          o_mem_addr_sel

  // mem/LSU controls
  , output reg          o_mem_read
  , output reg          o_mem_write
  , output reg [2:0]    o_lsu_op

  // mult/crc/branch controls
  , output reg [3:0]    o_mult_sel
  , output reg [1:0]    o_crc_sel
  , output reg [2:0]    o_branch_sel

  // extension/comparator controls
  , output reg          o_halt
//   , output reg          o_illegal
//   , output wire [5:0]   o_state
);

  reg o_illegal;
  wire [5:0] o_state;
  // 
  //  Instruction fields and opcodes    
  //

  wire [6:0] opcode = i_instruction[6:0];
  wire [2:0] funct3 = i_instruction[14:12];
  wire [6:0] funct7 = i_instruction[31:25];

   localparam [6:0] OP_LOAD = 7'b0000011;
   localparam [6:0] OP_FENCE  = 7'b0001111;
   localparam [6:0] OP_IMM    = 7'b0010011;
   localparam [6:0] OP_AUIPC  = 7'b0010111;
   localparam [6:0] OP_STORE  = 7'b0100011;
   localparam [6:0] OP_REG    = 7'b0110011;
   localparam [6:0] OP_LUI    = 7'b0110111;
   localparam [6:0] OP_BRANCH = 7'b1100011;
   localparam [6:0] OP_JALR   = 7'b1100111;
   localparam [6:0] OP_JAL    = 7'b1101111;
   localparam [6:0] OP_SYSTEM = 7'b1110011;

   // ALU encodings according to guide
    localparam [3:0] ALU_PASS_B = 4'h0;
    localparam [3:0] ALU_ADD    = 4'h1;
    localparam [3:0] ALU_SUB    = 4'h2;
    localparam [3:0] ALU_AND    = 4'h3;
    localparam [3:0] ALU_OR     = 4'h4;
    localparam [3:0] ALU_XOR    = 4'h5;
    localparam [3:0] ALU_SLL    = 4'h6;
    localparam [3:0] ALU_SRL    = 4'h7;
    localparam [3:0] ALU_SRA    = 4'h8;
    localparam [3:0] ALU_SLT    = 4'h9;
    localparam [3:0] ALU_SLTU   = 4'hA;

    localparam [1:0] EXEC_ALU = 2'b00;
    localparam [1:0] EXEC_MUL = 2'b01;
    localparam [1:0] EXEC_CRC = 2'b10;

    localparam [1:0] WB_ALUOUT = 2'b00;
    localparam [1:0] WB_MDR    = 2'b01;
    localparam [1:0] WB_PC4    = 2'b10;

   // LSU operation encoding, NOT SAME AS FUNCT3 for explicit mapping
    localparam [2:0] LSU_LW  = 3'b000;
    localparam [2:0] LSU_LH  = 3'b001;
    localparam [2:0] LSU_LB  = 3'b010;
    localparam [2:0] LSU_LHU = 3'b011;
    localparam [2:0] LSU_LBU = 3'b100;
    localparam [2:0] LSU_SW  = 3'b101;
    localparam [2:0] LSU_SH  = 3'b110;
    localparam [2:0] LSU_SB  = 3'b111;
 
  //
  // FSM STATES
  //

    localparam [5:0] ST_FETCH          = 6'd0;
    localparam [5:0] ST_DECODE         = 6'd1;
    localparam [5:0] ST_EXEC_REG       = 6'd2;
    localparam [5:0] ST_EXEC_IMM       = 6'd3;
    localparam [5:0] ST_EXEC_MUL       = 6'd4;
    localparam [5:0] ST_EXEC_CRC       = 6'd5;
    localparam [5:0] ST_EXEC_LUI       = 6'd6;
    localparam [5:0] ST_EXEC_AUIPC     = 6'd7;
    localparam [5:0] ST_EXEC_MEM_ADDR  = 6'd8;
    localparam [5:0] ST_LOAD_REQUEST   = 6'd9;
    localparam [5:0] ST_LOAD_CAPTURE   = 6'd10;
    localparam [5:0] ST_LOAD_WB        = 6'd11;
    localparam [5:0] ST_STORE_WRITE    = 6'd12;
    localparam [5:0] ST_BRANCH_TARGET  = 6'd13;
    localparam [5:0] ST_BRANCH_COMMIT  = 6'd14;
    localparam [5:0] ST_JAL_TARGET     = 6'd15;
    localparam [5:0] ST_JAL_COMMIT     = 6'd16;
    localparam [5:0] ST_JALR_TARGET    = 6'd17;
    localparam [5:0] ST_JALR_COMMIT    = 6'd18;
    localparam [5:0] ST_ALU_WB         = 6'd19;
    localparam [5:0] ST_FENCE_COMMIT   = 6'd20;
    localparam [5:0] ST_HALT           = 6'd21;
    localparam [5:0] ST_ILLEGAL        = 6'd22;

    reg [5:0] state_q;
    reg [5:0] state_d;

    assign o_state = state_q;
  
  // 
  // decode helpers
  //

    function valid_base_reg;
        input [2:0] f3;
        input [6:0] f7;
        begin
            if (f7 == 7'b0000000)
                valid_base_reg = 1'b1;
            else if ((f7 == 7'b0100000) &&
                     ((f3 == 3'b000) || (f3 == 3'b101)))
                valid_base_reg = 1'b1;
            else
                valid_base_reg = 1'b0;
        end
    endfunction

    function valid_imm;
        input [2:0] f3;
        input [6:0] f7;
        begin
            case (f3)
                3'b001: valid_imm = (f7 == 7'b0000000); // SLLI
                3'b101: valid_imm = (f7 == 7'b0000000) ||
                                    (f7 == 7'b0100000); // SRLI/SRAI
                default: valid_imm = 1'b1;
            endcase
        end
    endfunction 
    
    function valid_load;
        input [2:0] f3;
        begin
            valid_load = (f3 == 3'b000) || (f3 == 3'b001) ||
                         (f3 == 3'b010) || (f3 == 3'b100) ||
                         (f3 == 3'b101);
        end
    endfunction

    function valid_store;
        input [2:0] f3;
        begin
            valid_store = (f3 == 3'b000) || (f3 == 3'b001) ||
                          (f3 == 3'b010);
        end
    endfunction

    function valid_branch;
        input [2:0] f3;
        begin
            valid_branch = (f3 == 3'b000) || (f3 == 3'b001) ||
                           (f3 == 3'b100) || (f3 == 3'b101) ||
                           (f3 == 3'b110) || (f3 == 3'b111);
        end
    endfunction
    
    function [3:0] decode_base_alu;
        input [2:0] f3;
        input [6:0] f7;
        begin
            case (f3)
                3'b000: decode_base_alu = (f7 == 7'b0100000) ? ALU_SUB : ALU_ADD;
                3'b001: decode_base_alu = ALU_SLL;
                3'b010: decode_base_alu = ALU_SLT;
                3'b011: decode_base_alu = ALU_SLTU;
                3'b100: decode_base_alu = ALU_XOR;
                3'b101: decode_base_alu = (f7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                3'b110: decode_base_alu = ALU_OR;
                3'b111: decode_base_alu = ALU_AND;
                default: decode_base_alu = ALU_ADD;
            endcase
        end
    endfunction

    function [3:0] decode_imm_alu;
        input [2:0] f3;
        input [6:0] f7;
        begin
            case (f3)
                3'b000: decode_imm_alu = ALU_ADD;
                3'b001: decode_imm_alu = ALU_SLL;
                3'b010: decode_imm_alu = ALU_SLT;
                3'b011: decode_imm_alu = ALU_SLTU;
                3'b100: decode_imm_alu = ALU_XOR;
                3'b101: decode_imm_alu = (f7 == 7'b0100000) ? ALU_SRA : ALU_SRL;
                3'b110: decode_imm_alu = ALU_OR;
                3'b111: decode_imm_alu = ALU_AND;
                default: decode_imm_alu = ALU_ADD;
            endcase
        end
    endfunction

    function [2:0] decode_lsu;
        input [6:0] op;
        input [2:0] f3;
        begin
            if (op == OP_LOAD) begin
                case (f3)
                    3'b000: decode_lsu = LSU_LB;
                    3'b001: decode_lsu = LSU_LH;
                    3'b010: decode_lsu = LSU_LW;
                    3'b100: decode_lsu = LSU_LBU;
                    3'b101: decode_lsu = LSU_LHU;
                    default: decode_lsu = LSU_LW;
                endcase
            end else begin
                case (f3)
                    3'b000: decode_lsu = LSU_SB;
                    3'b001: decode_lsu = LSU_SH;
                    3'b010: decode_lsu = LSU_SW;
                    default: decode_lsu = LSU_SW;
                endcase
            end
        end
    endfunction

    //
    // state register
    // 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= ST_FETCH;
        else
            state_q <= state_d;
    end

    //
    // next state logic & instruction validation
    //

    always @(*) begin
        state_d = ST_ILLEGAL;

        case (state_q)
            ST_FETCH: state_d = ST_DECODE;

            ST_DECODE: begin
                case (opcode)
                    OP_REG: begin
                        if ((funct7 == 7'b0000001) && (funct3 <= 3'b011))
                            state_d = ST_EXEC_MUL;
                        else if ((funct7 == 7'b1000000) && (funct3 <= 3'b010))
                            state_d = ST_EXEC_CRC;
                        else if (valid_base_reg(funct3, funct7))
                            state_d = ST_EXEC_REG;
                        else
                            state_d = ST_ILLEGAL;
                    end

                    OP_IMM:
                        state_d = valid_imm(funct3, funct7) ? ST_EXEC_IMM : ST_ILLEGAL;

                    OP_LOAD:
                        state_d = valid_load(funct3) ? ST_EXEC_MEM_ADDR : ST_ILLEGAL;

                    OP_STORE:
                        state_d = valid_store(funct3) ? ST_EXEC_MEM_ADDR : ST_ILLEGAL;

                    OP_BRANCH:
                        state_d = valid_branch(funct3) ? ST_BRANCH_TARGET : ST_ILLEGAL;

                    OP_JALR:
                        state_d = (funct3 == 3'b000) ? ST_JALR_TARGET : ST_ILLEGAL;

                    OP_JAL:   state_d = ST_JAL_TARGET;
                    OP_LUI:   state_d = ST_EXEC_LUI;
                    OP_AUIPC: state_d = ST_EXEC_AUIPC;

                    OP_FENCE:
                        state_d = (funct3 == 3'b000) ? ST_FENCE_COMMIT : ST_ILLEGAL;

                    OP_SYSTEM: begin
                        // Ecall and Ebreak enters HALT state
                        if ((i_instruction == 32'h00000073) ||
                            (i_instruction == 32'h00100073))
                            state_d = ST_HALT;
                        else
                            state_d = ST_ILLEGAL;
                    end

                    default: state_d = ST_ILLEGAL;
                endcase
            end

            ST_EXEC_REG,
            ST_EXEC_IMM,
            ST_EXEC_MUL,
            ST_EXEC_CRC,
            ST_EXEC_LUI,
            ST_EXEC_AUIPC:    state_d = ST_ALU_WB;

            ST_EXEC_MEM_ADDR: state_d = (opcode == OP_LOAD) ?
                                       ST_LOAD_REQUEST : ST_STORE_WRITE;
            ST_LOAD_REQUEST:  state_d = ST_LOAD_CAPTURE;
            ST_LOAD_CAPTURE:  state_d = ST_LOAD_WB;
            ST_LOAD_WB:       state_d = ST_FETCH;
            ST_STORE_WRITE:   state_d = ST_FETCH;

            ST_BRANCH_TARGET: state_d = ST_BRANCH_COMMIT;
            ST_BRANCH_COMMIT: state_d = ST_FETCH;

            ST_JAL_TARGET:    state_d = ST_JAL_COMMIT;
            ST_JAL_COMMIT:    state_d = ST_FETCH;
            ST_JALR_TARGET:   state_d = ST_JALR_COMMIT;
            ST_JALR_COMMIT:   state_d = ST_FETCH;

            ST_ALU_WB:        state_d = ST_FETCH;
            ST_FENCE_COMMIT:  state_d = ST_FETCH;
            ST_HALT:          state_d = ST_HALT;
            ST_ILLEGAL:       state_d = ST_ILLEGAL;

            default:          state_d = ST_ILLEGAL;
        endcase
    end

    //
    // Moore output logic
    //

     always @(*) begin
        o_pc_write          = 1'b0;
        o_ir_write          = 1'b0;
        o_operand_write     = 1'b0;
        o_aluout_write      = 1'b0;
        o_mdr_write         = 1'b0;
        o_reg_write         = 1'b0;

        o_pc_sel            = 1'b0;
        o_pc_lsb_clear      = 1'b0;

        o_alu_a_sel         = 1'b0;
        o_alu_b_sel         = 1'b0;
        o_alu_control       = ALU_ADD;

        o_exec_result_sel   = EXEC_ALU;
        o_wb_sel            = WB_ALUOUT;
        o_mem_addr_sel      = 1'b0;

        o_mem_read          = 1'b0;
        o_mem_write         = 1'b0;
        o_lsu_op            = LSU_LW;

        o_mult_sel           = 4'h0;
        o_crc_sel            = 2'b00;
        o_branch_sel         = funct3;

        o_halt               = 1'b0;
        o_illegal            = 1'b0;

        case (state_q)
        ST_FETCH: begin
            o_mem_addr_sel = 1'b0;       // current PC
            o_mem_read     = 1'b1;
            o_lsu_op       = LSU_LW;     // pass complete IMEM word
            o_ir_write     = 1'b1;
        end

        ST_DECODE: begin
        o_operand_write = 1'b1;      // capture both rs1 and rs2
        end

        ST_EXEC_REG: begin
            o_alu_a_sel       = 1'b0;
            o_alu_b_sel       = 1'b0;
            o_alu_control     = decode_base_alu(funct3, funct7);
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_IMM: begin
            o_alu_a_sel       = 1'b0;
            o_alu_b_sel       = 1'b1;
            o_alu_control     = decode_imm_alu(funct3, funct7);
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_MUL: begin
            o_mult_sel        = {1'b0, funct3};
            o_exec_result_sel = EXEC_MUL;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_CRC: begin
            o_crc_sel         = funct3[1:0];
            o_exec_result_sel = EXEC_CRC;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_LUI: begin
            o_alu_b_sel       = 1'b1;
            o_alu_control     = ALU_PASS_B;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_AUIPC: begin
            o_alu_a_sel       = 1'b1;    // current instruction PC
            o_alu_b_sel       = 1'b1;    // U-immediate
            o_alu_control     = ALU_ADD;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_EXEC_MEM_ADDR: begin
            o_alu_a_sel       = 1'b0;    // rs1
            o_alu_b_sel       = 1'b1;    // load/store immediate
            o_alu_control     = ALU_ADD;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_LOAD_REQUEST: begin
            o_mem_addr_sel = 1'b1;       // ALUOut effective addr
            o_mem_read     = 1'b1;
            o_lsu_op       = decode_lsu(opcode, funct3);
        end

        ST_LOAD_CAPTURE: begin
            o_mem_addr_sel = 1'b1;
            o_mem_read     = 1'b1;
            o_lsu_op       = decode_lsu(opcode, funct3);
            o_mdr_write    = 1'b1;
        end

        ST_LOAD_WB: begin
            o_wb_sel    = WB_MDR;
            o_reg_write = 1'b1;
            o_pc_sel    = 1'b0;
            o_pc_write  = 1'b1;
        end

        ST_STORE_WRITE: begin
            o_mem_addr_sel = 1'b1;
            o_mem_write    = 1'b1;
            o_lsu_op       = decode_lsu(opcode, funct3);
            o_pc_sel       = 1'b0;
            o_pc_write     = 1'b1;
        end

        ST_BRANCH_TARGET: begin
            o_alu_a_sel       = 1'b1;    // current PC
            o_alu_b_sel       = 1'b1;    // B-immediate
            o_alu_control     = ALU_ADD;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
            o_branch_sel      = funct3;
        end

        ST_BRANCH_COMMIT: begin
            o_branch_sel = funct3;
            o_pc_sel     = i_branch_taken;
            o_pc_write   = 1'b1;         // target or sequential PC+4
        end

        ST_JAL_TARGET: begin
            o_alu_a_sel       = 1'b1;    // current PC
            o_alu_b_sel       = 1'b1;    // J-immediate
            o_alu_control     = ALU_ADD;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_JAL_COMMIT: begin
            o_wb_sel    = WB_PC4;
            o_reg_write = 1'b1;
            o_pc_sel    = 1'b1;
            o_pc_write  = 1'b1;
        end

        ST_JALR_TARGET: begin
            o_alu_a_sel       = 1'b0;    // rs1
            o_alu_b_sel       = 1'b1;    // I-immediate
            o_alu_control     = ALU_ADD;
            o_exec_result_sel = EXEC_ALU;
            o_aluout_write    = 1'b1;
        end

        ST_JALR_COMMIT: begin
            o_wb_sel       = WB_PC4;
            o_reg_write    = 1'b1;
            o_pc_sel       = 1'b1;
            o_pc_lsb_clear = 1'b1;
            o_pc_write     = 1'b1;
        end

        ST_ALU_WB: begin
            o_wb_sel    = WB_ALUOUT;
            o_reg_write = 1'b1;
            o_pc_sel    = 1'b0;
            o_pc_write  = 1'b1;
        end

        ST_FENCE_COMMIT: begin
            o_pc_sel   = 1'b0;
            o_pc_write = 1'b1;
        end

        ST_HALT: begin
            o_halt = 1'b1;
        end

        ST_ILLEGAL: begin
            o_illegal = 1'b1;
            o_halt    = 1'b1;
        end

        default: begin
            o_illegal = 1'b1;
            o_halt    = 1'b1;
        end
    endcase
  end
endmodule
 
 
`default_nettype wire



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



//  ---------- INLCUDED BLOCK: Exec_Result_MUX  ---------- 
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



//  ---------- INLCUDED BLOCK: WB_MUX  ---------- 
module WB_MUX (
    input  wire [31:0] alu_out,
    input  wire [31:0] mdr,
    input  wire [31:0] pc_plus4,
    input  wire [1:0]  wb_sel,

    output reg  [31:0] wb_data
);

always @(*) begin
    case (wb_sel)
        2'b00: wb_data = alu_out;
        2'b01: wb_data = mdr;
        2'b10: wb_data = pc_plus4;
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



//  ---------- INLCUDED BLOCK: GPIO_equipe41  ---------- 
// ============================================================================
// BLOCK: GPIO_equipe41   (ChipInventor block - Stage 3, Team 41)
// PIN Controller, ChampionCHIP Block Guide section 1
//
// Registers (base 0xF0000000, word aligned):
//   0x0 DATAOUT [7:0] RW  level driven on output pins
//   0x4 DATAIN  [7:0] R   level read on input pins (output pins read 0)
//   0x8 DATADIR [7:0] RW  1 = output, 0 = input (reset: all inputs)
//   any other offset in the window is reserved (reads 0, writes ignored)
//
// Connect:  sel_i   <- MemoryUnit_SoC_equipe41.gpio_sel
//           we_i    <- MemoryUnit_SoC_equipe41.periph_we
//           addr_i  <- MemoryUnit_SoC_equipe41.periph_addr
//           wdata_i <- MemoryUnit_SoC_equipe41.periph_wdata
//           rdata_o -> MemoryUnit_SoC_equipe41.gpio_rdata
//           gpio_in / gpio_out / gpio_oe <-> top-level pins
// ============================================================================
module GPIO_equipe41 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sel_i,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    input  wire [7:0]  gpio_in,
    output wire [7:0]  gpio_out,
    output wire [7:0]  gpio_oe
);

    reg  [7:0] r_dataout;
    reg  [7:0] r_datadir;
    reg  [7:0] r_sync1;
    reg  [7:0] r_sync2;
    wire [9:0] reg_idx = addr_i[11:2];    // word index inside the 4 KB window

    // register writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_dataout <= 8'h00;
            r_datadir <= 8'h00;
        end else if (sel_i && we_i) begin
            if (reg_idx == 10'd0) r_dataout <= wdata_i[7:0];
            if (reg_idx == 10'd2) r_datadir <= wdata_i[7:0];
        end
    end

    // 2-flip-flop input synchroniser
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_sync1 <= 8'h00;
            r_sync2 <= 8'h00;
        end else begin
            r_sync1 <= gpio_in;
            r_sync2 <= r_sync1;
        end
    end

    wire [7:0] w_datain = r_sync2 & ~r_datadir;   // input buffer only on inputs

    assign gpio_oe  = r_datadir;                   // output buffer enable
    assign gpio_out = r_dataout & r_datadir;       // driven only on outputs

    // register reads
    always @(*) begin
        rdata_o = 32'h00000000;
        if (sel_i) begin
            case (reg_idx)
                10'd0:   rdata_o = {24'h000000, r_dataout};
                10'd1:   rdata_o = {24'h000000, w_datain};
                10'd2:   rdata_o = {24'h000000, r_datadir};
                default: rdata_o = 32'h00000000;
            endcase
        end
    end

endmodule



//  ---------- INLCUDED BLOCK: UART_equipe41  ---------- 
// ============================================================================
// BLOCK: UART_equipe41   (ChipInventor block - Stage 3, Team 41)
// Serial Controller, ChampionCHIP Block Guide section 2
//
// Registers (base 0xF1000000, word aligned):
//   0x0 TXDATA  [7:0] RW  byte to send
//   0x4 RXDATA  [7:0] R   last byte received
//   0x8 CONTROL bit2 TXDONE (R, 1 at reset) | bit1 RXDONE (RW, write 0 to clear)
//               | bit0 TRANSMIT (W, self-clearing)
// 8-N-1, LSB first, 115200 baud, full duplex, no oversampling.
// RX checks the stop bit: a frame whose stop bit is low (framing error) is
// dropped (RXDONE not set) and the receiver waits for the idle line.
// Offsets other than 0x0/0x4/0x8 inside the window are reserved (read 0).
// CLK_FREQ_HZ must equal the real clock frequency (testbench uses 50 MHz).
//
// Connect:  sel_i   <- MemoryUnit_SoC_equipe41.uart_sel
//           we_i    <- MemoryUnit_SoC_equipe41.periph_we
//           addr_i  <- MemoryUnit_SoC_equipe41.periph_addr
//           wdata_i <- MemoryUnit_SoC_equipe41.periph_wdata
//           rdata_o -> MemoryUnit_SoC_equipe41.uart_rdata
//           rx_i <- top-level pin uart_rx_i ,  tx_o -> top-level pin uart_tx_o
// ============================================================================
module UART_equipe41 #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,

    // bus side
    input  wire        sel_i,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,

    // serial pins
    input  wire        rx_i,
    output reg         tx_o
);

    localparam integer CLKS_PER_BIT  = (CLK_FREQ_HZ + BAUD_RATE/2) / BAUD_RATE;  // rounded
    localparam integer HALF_BIT      = CLKS_PER_BIT / 2;
    localparam integer CW            = 16;   // counter width (CLKS_PER_BIT < 65536)

    localparam OFF_TXDATA  = 10'd0;   // 0x000
    localparam OFF_RXDATA  = 10'd1;   // 0x004
    localparam OFF_CONTROL = 10'd2;   // 0x008  (all other offsets reserved)

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;
    localparam R_WAIT  = 3'd4;        // RX only: framing error, wait for idle line

    // ------------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------------
    reg [7:0] r_txdata;
    reg [7:0] r_rxdata;
    reg       r_transmit;   // CONTROL[0]
    reg       r_rxdone;     // CONTROL[1]
    reg       r_txdone;     // CONTROL[2]

    wire [9:0] reg_idx = addr_i[11:2];    // word index inside the 4 KB window
    wire wr_txdata  = sel_i && we_i && (reg_idx == OFF_TXDATA);
    wire wr_control = sel_i && we_i && (reg_idx == OFF_CONTROL);

    // ------------------------------------------------------------------
    // TX datapath
    // ------------------------------------------------------------------
    reg [1:0]    tx_state;
    reg [CW-1:0] tx_cnt;
    reg [2:0]    tx_bit;
    reg [7:0]    tx_shift;          // FIFOtx
    reg          tx_frame_done;     // 1-cycle pulse at end of stop bit

    // ------------------------------------------------------------------
    // RX datapath
    // ------------------------------------------------------------------
    reg          rx_s1, rx_s2;      // synchroniser (line idles high)
    reg [2:0]    rx_state;
    reg [CW-1:0] rx_cnt;
    reg [2:0]    rx_bit;
    reg [7:0]    rx_shift;          // FIFOrx
    reg          rx_frame_done;     // 1-cycle pulse when a byte is complete

    // ---------------- TXDATA ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          r_txdata <= 8'h00;
        else if (wr_txdata)  r_txdata <= wdata_i[7:0];
    end

    // ---------------- TRANSMIT: set by SW, cleared next cycle ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                          r_transmit <= 1'b0;
        else if (wr_control && wdata_i[0])   r_transmit <= 1'b1;
        else                                 r_transmit <= 1'b0;
    end

    wire tx_start = r_transmit && (tx_state == S_IDLE);

    // ---------------- TXDONE: HW owned ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              r_txdone <= 1'b1;
        else if (tx_start)       r_txdone <= 1'b0;
        else if (tx_frame_done)  r_txdone <= 1'b1;
    end

    // ---------------- RXDONE: set by HW, cleared by SW writing 0 --------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              r_rxdone <= 1'b0;
        else if (rx_frame_done)  r_rxdone <= 1'b1;        // HW set has priority
        else if (wr_control)     r_rxdone <= wdata_i[1];
    end

    // ---------------- TX state machine ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state      <= S_IDLE;
            tx_cnt        <= {CW{1'b0}};
            tx_bit        <= 3'd0;
            tx_shift      <= 8'h00;
            tx_o          <= 1'b1;
            tx_frame_done <= 1'b0;
        end else begin
            tx_frame_done <= 1'b0;
            case (tx_state)
                S_IDLE: begin
                    tx_o <= 1'b1;
                    if (tx_start) begin
                        tx_shift <= r_txdata;         // load FIFOtx
                        tx_cnt   <= {CW{1'b0}};
                        tx_o     <= 1'b0;             // start bit
                        tx_state <= S_START;
                    end
                end
                S_START: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt   <= {CW{1'b0}};
                        tx_bit   <= 3'd0;
                        tx_o     <= tx_shift[0];      // LSB first
                        tx_state <= S_DATA;
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
                S_DATA: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt <= {CW{1'b0}};
                        if (tx_bit == 3'd7) begin
                            tx_o     <= 1'b1;         // stop bit
                            tx_state <= S_STOP;
                        end else begin
                            tx_bit   <= tx_bit + 1'b1;
                            tx_o     <= tx_shift[tx_bit + 1'b1];
                        end
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
                S_STOP: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt        <= {CW{1'b0}};
                        tx_state      <= S_IDLE;
                        tx_frame_done <= 1'b1;
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
            endcase
        end
    end

    // ---------------- RX state machine ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s1 <= 1'b1;
            rx_s2 <= 1'b1;
        end else begin
            rx_s1 <= rx_i;
            rx_s2 <= rx_s1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state      <= S_IDLE;
            rx_cnt        <= {CW{1'b0}};
            rx_bit        <= 3'd0;
            rx_shift      <= 8'h00;
            r_rxdata      <= 8'h00;
            rx_frame_done <= 1'b0;
        end else begin
            rx_frame_done <= 1'b0;
            case (rx_state)
                S_IDLE: begin
                    rx_cnt <= {CW{1'b0}};
                    if (!rx_s2) rx_state <= S_START;          // falling edge
                end
                S_START: begin                                // go to bit centre
                    if (rx_cnt == HALF_BIT - 1) begin
                        rx_cnt <= {CW{1'b0}};
                        if (!rx_s2) begin                     // valid start bit
                            rx_bit   <= 3'd0;
                            rx_state <= S_DATA;
                        end else rx_state <= S_IDLE;          // glitch
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                S_DATA: begin                                 // 1 sample / bit
                    if (rx_cnt == CLKS_PER_BIT - 1) begin
                        rx_cnt   <= {CW{1'b0}};
                        rx_shift <= {rx_s2, rx_shift[7:1]};   // LSB first
                        if (rx_bit == 3'd7) rx_state <= S_STOP;
                        else                rx_bit   <= rx_bit + 1'b1;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                S_STOP: begin
                    if (rx_cnt == CLKS_PER_BIT - 1) begin     // centre of stop
                        rx_cnt <= {CW{1'b0}};
                        if (rx_s2) begin                      // valid stop bit
                            r_rxdata      <= rx_shift;
                            rx_frame_done <= 1'b1;
                            rx_state      <= S_IDLE;
                        end else begin                        // framing error:
                            rx_state      <= R_WAIT;          // drop the byte
                        end
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                R_WAIT: begin                                 // resync: wait until
                    if (rx_s2) rx_state <= S_IDLE;            // the line is idle
                end
                default: rx_state <= S_IDLE;
            endcase
        end
    end

    // ---------------- register reads ----------------
    always @(*) begin
        rdata_o = 32'h0000_0000;
        if (sel_i) begin
            case (reg_idx)
                OFF_TXDATA:  rdata_o = {24'h0, r_txdata};
                OFF_RXDATA:  rdata_o = {24'h0, r_rxdata};
                OFF_CONTROL: rdata_o = {29'h0, r_txdone, r_rxdone, r_transmit};
                default:     rdata_o = 32'h0000_0000;
            endcase
        end
    end

endmodule



//  ---------- INLCUDED BLOCK: MemoryUnit_SoC_equipe41  ---------- 
// ============================================================================
// BLOCK: MemoryUnit_SoC_equipe41   (ChipInventor block - Stage 3, Team 41)
// IMEM FIRMWARE IN THIS FILE: official GPIO/UART test firmware (TollGuard block commented out)
//
// Replaces the Stage 2 block MemoryUnit_ff_equipe41. The six core-side ports
// are IDENTICAL to Stage 2, so connect them to the same wires as before:
//   core_data_i    -> IR_Register.mem_rdata and MDR_Register.mem_rdata
//   core_address_o <- Memory_Address_MUX.mem_addr
//   core_data_o    <- B_Register.B
//   read_enable    <- ControlUnit_equipe41.o_mem_read
//   write_enable   <- ControlUnit_equipe41.o_mem_write
//   op_size_o      <- ControlUnit_equipe41.o_lsu_op
// New peripheral bus ports (to GPIO_equipe41 and UART_equipe41):
//   periph_addr, periph_wdata, periph_we  -> both GPIO and UART
//   gpio_sel -> GPIO.sel_i      uart_sel -> UART.sel_i
//   gpio_rdata <- GPIO.rdata_o  uart_rdata <- UART.rdata_o
//
// Memory map: IMEM 0x00400000-0x007FFFFF | DMEM 0x10010000-0x10011FFF
//             GPIO 0xF0000000-0xF0000FFF | UART 0xF1000000-0xF1000FFF
//
// To change firmware: replace the lines between "FIRMWARE START" and
// "FIRMWARE END" with the contents of the new firmware.txt.
// ============================================================================
module MemoryUnit_SoC_equipe41 (
    input  wire        clk,
    // core side (same as Stage 2)
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,
    input  wire [31:0] core_address_o,
    output wire [31:0] core_data_i,
    // peripheral bus (new in Stage 3)
    output wire [31:0] periph_addr,
    output wire [31:0] periph_wdata,
    output wire        periph_we,
    output wire        gpio_sel,
    output wire        uart_sel,
    input  wire [31:0] gpio_rdata,
    input  wire [31:0] uart_rdata
);

    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;
    wire [31:0] imem_addr, dmem_addr, imem_out, dmem_out;
    wire        imem_read_en, dmem_read_en, dmem_write_en;
    wire [3:0]  dmem_bw;
    wire [1:0]  region_sel;              // 0 IMEM, 1 DMEM, 2 GPIO, 3 UART
    reg  [31:0] mux_mem_data_out;
    reg         dmem_sel_q;

    assign periph_addr  = lsu_mem_addr;
    assign periph_wdata = lsu_mem_data;

    // DMEM answers one cycle after the request (as in Stage 2)
    always @(posedge clk) dmem_sel_q <= (region_sel == 2'd1);

    always @(*) begin
        case (region_sel)
            2'd1:    mux_mem_data_out = dmem_sel_q ? dmem_out : 32'h00000000;
            2'd2:    mux_mem_data_out = gpio_rdata;
            2'd3:    mux_mem_data_out = uart_rdata;
            default: mux_mem_data_out = imem_out;
        endcase
    end

    LSU_s3_equipe41 u_lsu (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),
        .mem_address_i (lsu_mem_addr),
        .mem_data_i    (lsu_mem_data),
        .byte_write_i  (lsu_byte_write),
        .mem_data_o    (mux_mem_data_out)
    );

    AddressDecoder_s3_equipe41 u_dec (
        .addr_i         (lsu_mem_addr),
        .read_enable_i  (read_enable),
        .write_enable_i (write_enable),
        .bw_i           (lsu_byte_write),
        .imem_addr_o    (imem_addr),
        .imem_read_en_o (imem_read_en),
        .dmem_addr_o    (dmem_addr),
        .dmem_read_en_o (dmem_read_en),
        .dmem_write_en_o(dmem_write_en),
        .dmem_bw_o      (dmem_bw),
        .gpio_sel_o     (gpio_sel),
        .uart_sel_o     (uart_sel),
        .periph_we_o    (periph_we),
        .region_sel_o   (region_sel)
    );

    IMEM_s3_equipe41 u_imem (
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    DMEM_s3_equipe41 #(.WORDS(2048)) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

endmodule

// ----------------------------------------------------------------------------
// Address decoder: Stage 2 IMEM/DMEM windows + GPIO and UART windows
// ----------------------------------------------------------------------------
module AddressDecoder_s3_equipe41 (
    input  wire [31:0] addr_i,
    input  wire        read_enable_i,
    input  wire        write_enable_i,
    input  wire [3:0]  bw_i,
    output reg  [31:0] imem_addr_o,
    output reg         imem_read_en_o,
    output reg  [31:0] dmem_addr_o,
    output reg         dmem_read_en_o,
    output reg         dmem_write_en_o,
    output reg  [3:0]  dmem_bw_o,
    output reg         gpio_sel_o,
    output reg         uart_sel_o,
    output reg         periph_we_o,
    output reg  [1:0]  region_sel_o
);
    always @(*) begin
        imem_addr_o     = 32'h00000000;
        imem_read_en_o  = 1'b0;
        dmem_addr_o     = 32'h00000000;
        dmem_read_en_o  = 1'b0;
        dmem_write_en_o = 1'b0;
        dmem_bw_o       = 4'b0000;
        gpio_sel_o      = 1'b0;
        uart_sel_o      = 1'b0;
        periph_we_o     = 1'b0;
        region_sel_o    = 2'd0;
        if (addr_i >= 32'h00400000 && addr_i <= 32'h007FFFFF) begin
            imem_addr_o    = addr_i - 32'h00400000;
            imem_read_en_o = read_enable_i;
            region_sel_o   = 2'd0;
        end else if (addr_i >= 32'h10010000 && addr_i <= 32'h10011FFF) begin
            dmem_addr_o     = addr_i - 32'h10010000;
            dmem_read_en_o  = read_enable_i;
            dmem_write_en_o = write_enable_i;
            dmem_bw_o       = bw_i;
            region_sel_o    = 2'd1;
        end else if (addr_i >= 32'hF0000000 && addr_i <= 32'hF0000FFF) begin
            gpio_sel_o   = 1'b1;
            periph_we_o  = write_enable_i & bw_i[0];   // word regs: lane 0 must be written
            region_sel_o = 2'd2;
        end else if (addr_i >= 32'hF1000000 && addr_i <= 32'hF1000FFF) begin
            uart_sel_o   = 1'b1;
            periph_we_o  = write_enable_i & bw_i[0];   // word regs: lane 0 must be written
            region_sel_o = 2'd3;
        end
    end
endmodule

// ----------------------------------------------------------------------------
// IMEM: combinational ROM. Lines are pasted verbatim from firmware.txt.
// ----------------------------------------------------------------------------
module IMEM_s3_equipe41 (
    input  wire [31:0] imem_addr,          // decoder-relative address
    input  wire        read_enable,
    output wire [31:0] imem_output
);
    wire [31:0] i_Address = imem_addr + 32'h00400000;
    reg  [31:0] r_Instruction;

    always @(*) begin
        case (i_Address)
            // ===== FIRMWARE START (official GPIO/UART test firmware, 21 words) =====
            32'h00400000: r_Instruction = 32'hF0000437;
            32'h00400004: r_Instruction = 32'hF10004B7;
            32'h00400008: r_Instruction = 32'h00842283;
            32'h0040000C: r_Instruction = 32'h0F02E293;
            32'h00400010: r_Instruction = 32'h00542423;
            32'h00400014: r_Instruction = 32'h00442283;
            32'h00400018: r_Instruction = 32'h00429293;
            32'h0040001C: r_Instruction = 32'h00542023;
            32'h00400020: r_Instruction = 32'h0084A283;
            32'h00400024: r_Instruction = 32'h0022F293;
            32'h00400028: r_Instruction = 32'hFE028CE3;
            32'h0040002C: r_Instruction = 32'h0004A423;
            32'h00400030: r_Instruction = 32'h0044A303;
            32'h00400034: r_Instruction = 32'h0084A283;
            32'h00400038: r_Instruction = 32'h0042F293;
            32'h0040003C: r_Instruction = 32'hFE028CE3;
            32'h00400040: r_Instruction = 32'h0064A023;
            32'h00400044: r_Instruction = 32'h0084A303;
            32'h00400048: r_Instruction = 32'h00136313;
            32'h0040004C: r_Instruction = 32'h0064A423;
            32'h00400050: r_Instruction = 32'hFC5FF06F;
            // ===== FIRMWARE END =====
             // // ===== FIRMWARE START (TollGuard application firmware, 113 words) =====
            // 32'h00400000: r_Instruction = 32'hF0000437;
            // 32'h00400004: r_Instruction = 32'hF10004B7;
            // 32'h00400008: r_Instruction = 32'h0F000293;
            // 32'h0040000C: r_Instruction = 32'h00542423;
            // 32'h00400010: r_Instruction = 32'h0004A423;
            // 32'h00400014: r_Instruction = 32'h08000293;
            // 32'h00400018: r_Instruction = 32'h00542023;
            // 32'h0040001C: r_Instruction = 32'h00442283;
            // 32'h00400020: r_Instruction = 32'h0082F293;
            // 32'h00400024: r_Instruction = 32'hFE028CE3;
            // 32'h00400028: r_Instruction = 32'h00442903;
            // 32'h0040002C: r_Instruction = 32'h00042023;
            // 32'h00400030: r_Instruction = 32'h000109B7;
            // 32'h00400034: r_Instruction = 32'hFFF98993;
            // 32'h00400038: r_Instruction = 32'h00000A13;
            // 32'h0040003C: r_Instruction = 32'h00000B13;
            // 32'h00400040: r_Instruction = 32'h02000B93;
            // 32'h00400044: r_Instruction = 32'h124000EF;
            // 32'h00400048: r_Instruction = 32'h813509B3;
            // 32'h0040004C: r_Instruction = 32'h01651533;
            // 32'h00400050: r_Instruction = 32'h00AA6A33;
            // 32'h00400054: r_Instruction = 32'h008B0B13;
            // 32'h00400058: r_Instruction = 32'hFF7B16E3;
            // 32'h0040005C: r_Instruction = 32'h10C000EF;
            // 32'h00400060: r_Instruction = 32'h813509B3;
            // 32'h00400064: r_Instruction = 32'h00050A93;
            // 32'h00400068: r_Instruction = 32'h100000EF;
            // 32'h0040006C: r_Instruction = 32'h813509B3;
            // 32'h00400070: r_Instruction = 32'h00851513;
            // 32'h00400074: r_Instruction = 32'h00AAEAB3;
            // 32'h00400078: r_Instruction = 32'h0F0000EF;
            // 32'h0040007C: r_Instruction = 32'h00050B93;
            // 32'h00400080: r_Instruction = 32'h0E8000EF;
            // 32'h00400084: r_Instruction = 32'h00851513;
            // 32'h00400088: r_Instruction = 32'h00ABEBB3;
            // 32'h0040008C: r_Instruction = 32'h07799A63;
            // 32'h00400090: r_Instruction = 32'h3E800293;
            // 32'h00400094: r_Instruction = 32'h0752EA63;
            // 32'h00400098: r_Instruction = 32'h00397293;
            // 32'h0040009C: r_Instruction = 32'h00229293;
            // 32'h004000A0: r_Instruction = 32'h00000317;
            // 32'h004000A4: r_Instruction = 32'h10430313;
            // 32'h004000A8: r_Instruction = 32'h00530333;
            // 32'h004000AC: r_Instruction = 32'h00032383;
            // 32'h004000B0: r_Instruction = 32'h01032E03;
            // 32'h004000B4: r_Instruction = 32'h035E0E33;
            // 32'h004000B8: r_Instruction = 32'h01C385B3;
            // 32'h004000BC: r_Instruction = 32'h00497293;
            // 32'h004000C0: r_Instruction = 32'h00028E63;
            // 32'h004000C4: r_Instruction = 32'h000142B7;
            // 32'h004000C8: r_Instruction = 32'h02558333;
            // 32'h004000CC: r_Instruction = 32'h0255B3B3;
            // 32'h004000D0: r_Instruction = 32'h01035313;
            // 32'h004000D4: r_Instruction = 32'h01039393;
            // 32'h004000D8: r_Instruction = 32'h007365B3;
            // 32'h004000DC: r_Instruction = 32'h00BA6A63;
            // 32'h004000E0: r_Instruction = 32'h40BA0633;
            // 32'h004000E4: r_Instruction = 32'h00000513;
            // 32'h004000E8: r_Instruction = 32'h01000693;
            // 32'h004000EC: r_Instruction = 32'h02C0006F;
            // 32'h004000F0: r_Instruction = 32'h000A0613;
            // 32'h004000F4: r_Instruction = 32'h00100513;
            // 32'h004000F8: r_Instruction = 32'h02000693;
            // 32'h004000FC: r_Instruction = 32'h01C0006F;
            // 32'h00400100: r_Instruction = 32'h00200513;
            // 32'h00400104: r_Instruction = 32'h0080006F;
            // 32'h00400108: r_Instruction = 32'h00300513;
            // 32'h0040010C: r_Instruction = 32'h00000593;
            // 32'h00400110: r_Instruction = 32'h00000613;
            // 32'h00400114: r_Instruction = 32'h04000693;
            // 32'h00400118: r_Instruction = 32'h00D42023;
            // 32'h0040011C: r_Instruction = 32'h00058C13;
            // 32'h00400120: r_Instruction = 32'h00060C93;
            // 32'h00400124: r_Instruction = 32'h060000EF;
            // 32'h00400128: r_Instruction = 32'h0FFC7513;
            // 32'h0040012C: r_Instruction = 32'h058000EF;
            // 32'h00400130: r_Instruction = 32'h008C5513;
            // 32'h00400134: r_Instruction = 32'h0FF57513;
            // 32'h00400138: r_Instruction = 32'h04C000EF;
            // 32'h0040013C: r_Instruction = 32'h00000B13;
            // 32'h00400140: r_Instruction = 32'h02000B93;
            // 32'h00400144: r_Instruction = 32'h016CD533;
            // 32'h00400148: r_Instruction = 32'h0FF57513;
            // 32'h0040014C: r_Instruction = 32'h038000EF;
            // 32'h00400150: r_Instruction = 32'h008B0B13;
            // 32'h00400154: r_Instruction = 32'hFF7B18E3;
            // 32'h00400158: r_Instruction = 32'h00442283;
            // 32'h0040015C: r_Instruction = 32'h0082F293;
            // 32'h00400160: r_Instruction = 32'hFE029CE3;
            // 32'h00400164: r_Instruction = 32'hEB1FF06F;
            // 32'h00400168: r_Instruction = 32'h0084A283;
            // 32'h0040016C: r_Instruction = 32'h0022F293;
            // 32'h00400170: r_Instruction = 32'hFE028CE3;
            // 32'h00400174: r_Instruction = 32'h0004A423;
            // 32'h00400178: r_Instruction = 32'h0044A503;
            // 32'h0040017C: r_Instruction = 32'h0FF57513;
            // 32'h00400180: r_Instruction = 32'h00008067;
            // 32'h00400184: r_Instruction = 32'h0084A283;
            // 32'h00400188: r_Instruction = 32'h0042F293;
            // 32'h0040018C: r_Instruction = 32'hFE028CE3;
            // 32'h00400190: r_Instruction = 32'h00A4A023;
            // 32'h00400194: r_Instruction = 32'h0084A303;
            // 32'h00400198: r_Instruction = 32'h00136313;
            // 32'h0040019C: r_Instruction = 32'h0064A423;
            // 32'h004001A0: r_Instruction = 32'h00008067;
            // 32'h004001A4: r_Instruction = 32'h00000032;
            // 32'h004001A8: r_Instruction = 32'h00000064;
            // 32'h004001AC: r_Instruction = 32'h00000096;
            // 32'h004001B0: r_Instruction = 32'h0000001E;
            // 32'h004001B4: r_Instruction = 32'h0000000C;
            // 32'h004001B8: r_Instruction = 32'h00000018;
            // 32'h004001BC: r_Instruction = 32'h00000024;
            // 32'h004001C0: r_Instruction = 32'h00000006;
            default: r_Instruction = 32'h00000000;
        endcase
    end

    assign imem_output = read_enable ? r_Instruction : 32'h00000000;
endmodule

// ----------------------------------------------------------------------------
// LSU and DMEM: Stage 2 logic, renamed so they cannot clash with the
// Stage 2 MemoryUnit_ff_equipe41 block if it is still in the project.
// ----------------------------------------------------------------------------
module LSU_s3_equipe41(
    // RISC-V Core Interface
    input  wire [31:0] core_data_o,     // rs2 data for stores
    input  wire [31:0] core_address_o,  // Target memory address
    input  wire [2:0]  op_size_o,       // LSU operation code
    output reg  [31:0] core_data_i,     // rd formatted data for loads

    // Address Decoder Interface
    output reg  [31:0] mem_address_i,   // Full 32-bit address passed to Decoder
    output reg  [31:0] mem_data_i,      // Lane-shifted store data
    output reg  [3:0]  byte_write_i,    // 4-bit byte-write mask
    input  wire [31:0] mem_data_o       // 32-bit word read from memory
);

    localparam c_LW  = 3'b000;
    localparam c_LH  = 3'b001;
    localparam c_LB  = 3'b010;
    localparam c_LHU = 3'b011;
    localparam c_LBU = 3'b100;
    localparam c_SW  = 3'b101;
    localparam c_SH  = 3'b110;
    localparam c_SB  = 3'b111;

    wire [1:0] offset = core_address_o[1:0];

    // Select target byte from memory word based on offset
    reg [7:0] selected_byte;
    always @(*) begin
        case(offset)
            2'b00: selected_byte = mem_data_o[7:0];
            2'b01: selected_byte = mem_data_o[15:8];
            2'b10: selected_byte = mem_data_o[23:16];
            2'b11: selected_byte = mem_data_o[31:24];
        endcase
    end

    // Select target half-word from memory word based on offset
    reg [15:0] selected_half;
    always @(*) begin
        case(offset[1])
            1'b0: selected_half = mem_data_o[15:0];
            1'b1: selected_half = mem_data_o[31:16];
        endcase
    end

    // 1. Address Passthrough
    always @(*) begin
        mem_address_i = core_address_o;
    end

    // 2. Store Data Alignment & Byte Write Generation
    always @(*) begin
        case(op_size_o)
            c_SW: begin
                byte_write_i = 4'b1111;
                mem_data_i   = core_data_o;
            end
            c_SH: begin
                case(offset[1])
                    1'b0: begin
                        byte_write_i = 4'b0011;
                        mem_data_i   = {16'h0000, core_data_o[15:0]};
                    end
                    1'b1: begin
                        byte_write_i = 4'b1100;
                        mem_data_i   = {core_data_o[15:0], 16'h0000};
                    end
                endcase
            end
            c_SB: begin
                case(offset)
                    2'b00: begin
                        byte_write_i = 4'b0001;
                        mem_data_i   = {24'h000000, core_data_o[7:0]};
                    end
                    2'b01: begin
                        byte_write_i = 4'b0010;
                        mem_data_i   = {16'h0000, core_data_o[7:0], 8'h00};
                    end
                    2'b10: begin
                        byte_write_i = 4'b0100;
                        mem_data_i   = {8'h00, core_data_o[7:0], 16'h0000};
                    end
                    2'b11: begin
                        byte_write_i = 4'b1000;
                        mem_data_i   = {core_data_o[7:0], 24'h000000};
                    end
                endcase
            end
            default: begin
                byte_write_i = 4'b0000;
                mem_data_i   = 32'h00000000;
            end
        endcase
    end

    // 3. Load Data Formatting (Sign / Zero Extension)
    always @(*) begin
        case(op_size_o)
            c_LW:  core_data_i = mem_data_o;
            c_LH:  core_data_i = {{16{selected_half[15]}}, selected_half};
            c_LB:  core_data_i = {{24{selected_byte[7]}}, selected_byte};
            c_LHU: core_data_i = {16'h0000, selected_half};
            c_LBU: core_data_i = {24'h000000, selected_byte};
            default: core_data_i = 32'h00000000;
        endcase
    end

endmodule

module DMEM_s3_equipe41 #(
    parameter WORDS = 4// 8 kB / 4 bytes per word
)(
    input  wire        clk,
    input  wire [31:0] dmem_addr,    // Relative address from decoder
    input  wire [31:0] dmem_data_i,  // Shifted store payload from LSU
    input  wire [3:0]  bw,           // Byte-write mask from decoder
    input  wire        write_enable,
    input  wire        read_enable,
    output reg  [31:0] dmem_output   // Changed from wire to reg
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
    localparam ADDR_WIDTH = $clog2(WORDS);
    wire [ADDR_WIDTH-1:0] word_idx = dmem_addr[(ADDR_WIDTH + 1) : 2];

    // Synchronous Write & Read Operations
    always @(posedge clk) begin
        if (write_enable) begin
            if (bw[0]) mem_b0[word_idx] <= dmem_data_i[7:0];
            if (bw[1]) mem_b1[word_idx] <= dmem_data_i[15:8];
            if (bw[2]) mem_b2[word_idx] <= dmem_data_i[23:16];
            if (bw[3]) mem_b3[word_idx] <= dmem_data_i[31:24];
        end

        // Synchronous Read Output
        if (read_enable) begin
            dmem_output <= {mem_b3[word_idx], mem_b2[word_idx], mem_b1[word_idx], mem_b0[word_idx]};
        end else begin
            dmem_output <= 32'h00000000;
        end
    end

endmodule


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module stage3_top_old (

  input wire clk,
  input wire rst_n,
  output wire o_halt,
  input wire [7:0] gpio_in,
  input wire uart_rx_i,
  output wire [7:0] gpio_out,
  output wire [7:0] gpio_oe,
  output wire uart_tx_o

);

//Internal Wires
 wire w_1;
 wire [31:0] w_2;
 wire [31:0] w_3;
 wire w_4;
 wire [31:0] w_5;
 wire [31:0] w_6;
 wire [31:0] w_7;
 wire [31:0] w_8;
 wire [31:0] w_9;
 wire [1:0] w_10;
 wire [31:0] w_11;
 wire [31:0] w_12;
 wire [1:0] w_13;
 wire [31:0] w_14;
 wire [31:0] w_15;
 wire w_17;
 wire [31:0] w_18;
 wire [31:0] w_19;
 wire [31:0] w_20;
 wire [3:0] w_21;
 wire w_23;
 wire w_24;
 wire [31:0] w_25;
 wire w_26;
 wire [31:0] w_27;
 wire [31:0] w_28;
 wire [31:0] w_29;
 wire [2:0] w_32;
 wire w_33;
 wire [1:0] w_36;
 wire w_37;
 wire [31:0] w_38;
 wire [31:0] w_42;
 wire w_46;
 wire [31:0] w_47;
 wire [31:0] w_50;
 wire w_52;
 wire w_53;
 wire w_54;
 wire [3:0] w_55;
 wire w_56;
 wire w_57;
 wire [2:0] w_58;
 wire w_63;
 wire w_64;
 wire [31:0] w_65;
 wire [31:0] w_66;
 wire [31:0] w_67;
 wire w_68;
 wire [31:0] w_72;

//Instances of Modules
ALU_OUT_Register blk4367_2 (
         .clk (clk),
         .rst_n (rst_n),
         .alu_write (w_1),
         .alu_q (w_2),
         .alu_out (w_3)
     );

MDR_Register blk4370_5 (
         .clk (clk),
         .rst_n (rst_n),
         .mdr_write (w_4),
         .mem_rdata (w_5),
         .mdr (w_6)
     );

Exec_Result_MUX blk4371_6 (
         .exec_result (w_2),
         .alu_result (w_7),
         .mult_result (w_8),
         .crc_result (w_9),
         .exec_result_sel (w_10)
     );

WB_MUX blk4372_7 (
         .mdr (w_6),
         .alu_out (w_11),
         .pc_plus4 (w_12),
         .wb_sel (w_13),
         .wb_data (w_14)
     );

Memory_Address_MUX blk4373_8 (
         .pc (w_15),
         .alu_out (w_11),
         .mem_addr_sel (w_17),
         .mem_addr (w_18)
     );

Multiplier_equipe41 blk4299_9 (
         .rd (w_8),
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .mult_sel (w_21)
     );

ProgramCounter_equipe41 blk4300_10 (
         .clk (clk),
         .rst_n (rst_n),
         .o_PC_Plus_4 (w_12),
         .o_PC_Output (w_15),
         .i_ALU_output (w_11),
         .PC_sel (w_23),
         .PC_write (w_24)
     );

RegisterFile_equipe41 #(.DATA_MEM_SIZE(2**13)) blk4352_11 (
         .clk (clk),
         .rst_n (rst_n),
         .reg_rd_data (w_14),
         .reg_write (w_26),
         .instruction (w_27),
         .reg_rs_1_data (w_28),
         .reg_rs_2_data (w_29)
     );

BranchComparator_equipe41 blk4296_12 (
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .Branch_Sel (w_32),
         .o_Branch_Taken (w_33)
     );

CRC_equipe41 blk4295_13 (
         .rd (w_9),
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .crc_sel (w_36)
     );

A_Register blk4369_15 (
         .clk (clk),
         .rst_n (rst_n),
         .A (w_19),
         .rs1_data (w_28),
         .ab_write (w_37)
     );

B_Register blk4366_16 (
         .clk (clk),
         .rst_n (rst_n),
         .B (w_20),
         .rs2_data (w_29),
         .ab_write (w_37)
     );

PC_Target_Align_equipe41 blk4353_18 (
         .alu_out (w_3),
         .pc_target (w_11),
         .pc_lsb_clear (w_46)
     );

ImmediateGenerator_equipe41 blk4297_19 (
         .instruction (w_27),
         .extended_immediate (w_50)
     );

ControlUnit_equipe41 blk4354_26 (
         .clk (clk),
         .rst_n (rst_n),
         .o_halt (o_halt),
         .o_aluout_write (w_1),
         .o_mdr_write (w_4),
         .o_exec_result_sel (w_10),
         .o_wb_sel (w_13),
         .o_mem_addr_sel (w_17),
         .o_mult_sel (w_21),
         .o_pc_sel (w_23),
         .o_pc_write (w_24),
         .o_reg_write (w_26),
         .o_branch_sel (w_32),
         .i_branch_taken (w_33),
         .o_crc_sel (w_36),
         .o_operand_write (w_37),
         .o_pc_lsb_clear (w_46),
         .i_instruction (w_27),
         .o_ir_write (w_52),
         .o_alu_a_sel (w_53),
         .o_alu_b_sel (w_54),
         .o_alu_control (w_55),
         .o_mem_read (w_56),
         .o_mem_write (w_57),
         .o_lsu_op (w_58)
     );

IR_Register blk4368_28 (
         .clk (clk),
         .rst_n (rst_n),
         .ir (w_27),
         .ir_write (w_52),
         .mem_rdata (w_5)
     );

ALU_equipe41 blk4294_30 (
         .Q (w_7),
         .pc_output (w_15),
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .immediate (w_50),
         .A_sel (w_53),
         .B_sel (w_54),
         .ALU_control (w_55)
     );

GPIO_equipe41 blk4794_35 (
         .clk (clk),
         .rst_n (rst_n),
         .gpio_in (gpio_in[7:0]),
         .gpio_out (gpio_out[7:0]),
         .gpio_oe (gpio_oe[7:0]),
         .sel_i (w_63),
         .we_i (w_64),
         .addr_i (w_65),
         .wdata_i (w_66),
         .rdata_o (w_67)
     );

UART_equipe41 blk4795_36 (
         .clk (clk),
         .rst_n (rst_n),
         .rx_i (uart_rx_i),
         .tx_o (uart_tx_o),
         .sel_i (w_68),
         .we_i (w_64),
         .addr_i (w_65),
         .wdata_i (w_66),
         .rdata_o (w_72)
     );

MemoryUnit_SoC_equipe41 blk4796_37 (
         .clk (clk),
         .core_data_i (w_5),
         .core_address_o (w_18),
         .core_data_o (w_20),
         .read_enable (w_56),
         .write_enable (w_57),
         .op_size_o (w_58),
         .gpio_sel (w_63),
         .periph_we (w_64),
         .periph_addr (w_65),
         .periph_wdata (w_66),
         .gpio_rdata (w_67),
         .uart_sel (w_68),
         .uart_rdata (w_72)
     );


endmodule
