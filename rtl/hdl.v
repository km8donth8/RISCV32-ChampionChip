

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

module Multiplier_equipe41(
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



//  ---------- INLCUDED BLOCK: MemoryUnit_ff_equipe41  ---------- 
module MemoryUnit_ff_equipe41(
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
    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;

    wire [31:0] imem_addr;
    wire        imem_read_en;

    wire [31:0] dmem_addr;
    wire        dmem_read_en;
    wire        dmem_write_en;
    wire [3:0]  dmem_bw;

    wire        addr_decoder_sel;
    wire [31:0] imem_out;
    wire [31:0] dmem_out;
    wire [31:0] mux_mem_data_out;

    // Register decoder select to match the 1-cycle memory read latency
    reg addr_decoder_sel_q;
    always @(posedge clk) begin
        addr_decoder_sel_q <= addr_decoder_sel;
    end

    // -------------------------------------------------------------------------
    // 1. Read Data MUX (Mixed Latency: Async IMEM vs. Sync DMEM)
    // -------------------------------------------------------------------------
    // - If current cycle is accessing DMEM (addr_decoder_sel = 1), wait for 
    //   addr_decoder_sel_q to select dmem_out on the next cycle.
    // - If accessing IMEM (addr_decoder_sel = 0), route imem_out combinationally.
    // -------------------------------------------------------------------------
    assign mux_mem_data_out = (addr_decoder_sel) ? ((addr_decoder_sel_q) ? dmem_out : 32'h00000000) 
                                                  : imem_out;

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
      .WORDS(1048576)
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

module LSU(
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

module IMEM #(
    parameter WORDS = 4//1048576
)(
    input  wire        clk,
    input  wire [31:0] imem_addr,   // Address input
    input  wire        read_enable,
    output wire [31:0] imem_output
);

    reg [31:0] instruction;

    always @(*) begin
        if (read_enable) begin
            case (imem_addr)
                32'h00000000: instruction = 32'h123452B7;
                32'h00000004: instruction = 32'h12345337;
                32'h00000008: instruction = 32'h3E629463;
                32'h0000000C: instruction = 32'h00001297;
                32'h00000010: instruction = 32'h3E028063;
                32'h00000014: instruction = 32'h00A00293;
                32'h00000018: instruction = 32'hFFD28313;
                32'h0000001C: instruction = 32'h00700393;
                32'h00000020: instruction = 32'h3C731863;
                32'h00000024: instruction = 32'h006283B3;
                32'h00000028: instruction = 32'h01100E13;
                32'h0000002C: instruction = 32'h3DC39263;
                32'h00000030: instruction = 32'h405E03B3;
                32'h00000034: instruction = 32'h3A639E63;
                32'h00000038: instruction = 32'h0FF00293;
                32'h0000003C: instruction = 32'h0F02C313;
                32'h00000040: instruction = 32'h00F00393;
                32'h00000044: instruction = 32'h3A731663;
                32'h00000048: instruction = 32'h7002E313;
                32'h0000004C: instruction = 32'h7FF00393;
                32'h00000050: instruction = 32'h3A731063;
                32'h00000054: instruction = 32'h0F02F313;
                32'h00000058: instruction = 32'h0F000393;
                32'h0000005C: instruction = 32'h38731A63;
                32'h00000060: instruction = 32'h0AA00293;
                32'h00000064: instruction = 32'h05500313;
                32'h00000068: instruction = 32'h0062C3B3;
                32'h0000006C: instruction = 32'h0FF00E13;
                32'h00000070: instruction = 32'h39C39063;
                32'h00000074: instruction = 32'h0062E3B3;
                32'h00000078: instruction = 32'h37C39C63;
                32'h0000007C: instruction = 32'h0062F3B3;
                32'h00000080: instruction = 32'h36039863;
                32'h00000084: instruction = 32'h00100293;
                32'h00000088: instruction = 32'h00429313;
                32'h0000008C: instruction = 32'h01000393;
                32'h00000090: instruction = 32'h36731063;
                32'h00000094: instruction = 32'h0023D313;
                32'h00000098: instruction = 32'h00400E13;
                32'h0000009C: instruction = 32'h35C31A63;
                32'h000000A0: instruction = 32'hFF000293;
                32'h000000A4: instruction = 32'h4022D313;
                32'h000000A8: instruction = 32'hFFC00393;
                32'h000000AC: instruction = 32'h34731263;
                32'h000000B0: instruction = 32'h00100293;
                32'h000000B4: instruction = 32'h00400313;
                32'h000000B8: instruction = 32'h006293B3;
                32'h000000BC: instruction = 32'h01000E13;
                32'h000000C0: instruction = 32'h33C39863;
                32'h000000C4: instruction = 32'h00200313;
                32'h000000C8: instruction = 32'h006E53B3;
                32'h000000CC: instruction = 32'h00400E93;
                32'h000000D0: instruction = 32'h33D39063;
                32'h000000D4: instruction = 32'hFF000293;
                32'h000000D8: instruction = 32'h4062D3B3;
                32'h000000DC: instruction = 32'hFFC00E93;
                32'h000000E0: instruction = 32'h31D39863;
                32'h000000E4: instruction = 32'h00A00293;
                32'h000000E8: instruction = 32'h0142A313;
                32'h000000EC: instruction = 32'h00100393;
                32'h000000F0: instruction = 32'h30731063;
                32'h000000F4: instruction = 32'hFF600293;
                32'h000000F8: instruction = 32'h0142B313;
                32'h000000FC: instruction = 32'h2E031A63;
                32'h00000100: instruction = 32'h00A00293;
                32'h00000104: instruction = 32'h01400313;
                32'h00000108: instruction = 32'h0062A3B3;
                32'h0000010C: instruction = 32'h00100E13;
                32'h00000110: instruction = 32'h2FC39063;
                32'h00000114: instruction = 32'h005333B3;
                32'h00000118: instruction = 32'h2C039C63;
                32'h0000011C: instruction = 32'h0FC10417;
                32'h00000120: instruction = 32'hEE440413;
                32'h00000124: instruction = 32'h12345337;
                32'h00000128: instruction = 32'h67830313;
                32'h0000012C: instruction = 32'h00642023;
                32'h00000130: instruction = 32'h0000B3B7;
                32'h00000134: instruction = 32'hABB38393;
                32'h00000138: instruction = 32'h00741223;
                32'h0000013C: instruction = 32'h0CC00E13;
                32'h00000140: instruction = 32'h01C40423;
                32'h00000144: instruction = 32'h00042E83;
                32'h00000148: instruction = 32'h2A6E9463;
                32'h0000014C: instruction = 32'h00441F03;
                32'h00000150: instruction = 32'hFFFFBFB7;
                32'h00000154: instruction = 32'hABBF8F93;
                32'h00000158: instruction = 32'h29FF1C63;
                32'h0000015C: instruction = 32'h00445F03;
                32'h00000160: instruction = 32'h0000BFB7;
                32'h00000164: instruction = 32'hABBF8F93;
                32'h00000168: instruction = 32'h29FF1463;
                32'h0000016C: instruction = 32'h00840F03;
                32'h00000170: instruction = 32'hFCC00F93;
                32'h00000174: instruction = 32'h27FF1E63;
                32'h00000178: instruction = 32'h00844F03;
                32'h0000017C: instruction = 32'h0CC00F93;
                32'h00000180: instruction = 32'h27FF1863;
                32'h00000184: instruction = 32'h00500293;
                32'h00000188: instruction = 32'h00A00313;
                32'h0000018C: instruction = 32'h00500393;
                32'h00000190: instruction = 32'hFF600E13;
                32'h00000194: instruction = 32'hFF600E93;
                32'h00000198: instruction = 32'h00728463;
                32'h0000019C: instruction = 32'h2540006F;
                32'h000001A0: instruction = 32'h01DE0463;
                32'h000001A4: instruction = 32'h24C0006F;
                32'h000001A8: instruction = 32'h00629463;
                32'h000001AC: instruction = 32'h2440006F;
                32'h000001B0: instruction = 32'h01C29463;
                32'h000001B4: instruction = 32'h23C0006F;
                32'h000001B8: instruction = 32'h0062C463;
                32'h000001BC: instruction = 32'h2340006F;
                32'h000001C0: instruction = 32'h005E4463;
                32'h000001C4: instruction = 32'h22C0006F;
                32'h000001C8: instruction = 32'h00535463;
                32'h000001CC: instruction = 32'h2240006F;
                32'h000001D0: instruction = 32'h01C2D463;
                32'h000001D4: instruction = 32'h21C0006F;
                32'h000001D8: instruction = 32'h0062E463;
                32'h000001DC: instruction = 32'h2140006F;
                32'h000001E0: instruction = 32'h01C2E463;
                32'h000001E4: instruction = 32'h20C0006F;
                32'h000001E8: instruction = 32'h00537463;
                32'h000001EC: instruction = 32'h2040006F;
                32'h000001F0: instruction = 32'h005E7463;
                32'h000001F4: instruction = 32'h1FC0006F;
                32'h000001F8: instruction = 32'h00800F6F;
                32'h000001FC: instruction = 32'h1F40006F;
                32'h00000200: instruction = 32'h00000F97;
                32'h00000204: instruction = 32'h010F8F93;
                32'h00000208: instruction = 32'h000F8067;
                32'h0000020C: instruction = 32'h1E40006F;
                32'h00000210: instruction = 32'h00100013;
                32'h00000214: instruction = 32'h1C001E63;
                32'h00000218: instruction = 32'hDEADC2B7;
                32'h0000021C: instruction = 32'hEEF28293;
                32'h00000220: instruction = 32'h00028313;
                32'h00000224: instruction = 32'h00030393;
                32'h00000228: instruction = 32'h00038F93;
                32'h0000022C: instruction = 32'hDEADC2B7;
                32'h00000230: instruction = 32'hEEF28293;
                32'h00000234: instruction = 32'h1A5F9E63;
                32'h00000238: instruction = 32'h000185B7;
                32'h0000023C: instruction = 32'h6A058593;
                32'h00000240: instruction = 32'h00200613;
                32'h00000244: instruction = 32'hEE6B36B7;
                32'h00000248: instruction = 32'h80068693;
                32'h0000024C: instruction = 32'h000312B7;
                32'h00000250: instruction = 32'hD4028293;
                32'h00000254: instruction = 32'hDCD65337;
                32'h00000258: instruction = 32'hFFF00393;
                32'h0000025C: instruction = 32'h00100E13;
                32'h00000260: instruction = 32'h02C58533;
                32'h00000264: instruction = 32'h18551663;
                32'h00000268: instruction = 32'h02C68533;
                32'h0000026C: instruction = 32'h18651263;
                32'h00000270: instruction = 32'h02C59533;
                32'h00000274: instruction = 32'h16051E63;
                32'h00000278: instruction = 32'h02C69533;
                32'h0000027C: instruction = 32'h16751A63;
                32'h00000280: instruction = 32'h02C6B533;
                32'h00000284: instruction = 32'h17C51663;
                32'h00000288: instruction = 32'h02C6A533;
                32'h0000028C: instruction = 32'h16751263;
                32'h00000290: instruction = 32'h02D62533;
                32'h00000294: instruction = 32'h15C51E63;
                32'h00000298: instruction = 32'h000028B7;
                32'h0000029C: instruction = 32'hE8288893;
                32'h000002A0: instruction = 32'h00010437;
                32'h000002A4: instruction = 32'hFFF40413;
                32'h000002A8: instruction = 32'h01200493;
                32'h000002AC: instruction = 32'h03400913;
                32'h000002B0: instruction = 32'h05600993;
                32'h000002B4: instruction = 32'h07800A13;
                32'h000002B8: instruction = 32'h09000A93;
                32'h000002BC: instruction = 32'h0AB00B13;
                32'h000002C0: instruction = 32'h0CD00B93;
                32'h000002C4: instruction = 32'h0EF00C13;
                32'h000002C8: instruction = 32'h80848433;
                32'h000002CC: instruction = 32'h80890433;
                32'h000002D0: instruction = 32'h80898433;
                32'h000002D4: instruction = 32'h808A0433;
                32'h000002D8: instruction = 32'h808A8433;
                32'h000002DC: instruction = 32'h808B0433;
                32'h000002E0: instruction = 32'h808B8433;
                32'h000002E4: instruction = 32'h808C0433;
                32'h000002E8: instruction = 32'h11141463;
                32'h000002EC: instruction = 32'h000102B7;
                32'h000002F0: instruction = 32'hFFF28293;
                32'h000002F4: instruction = 32'h00001337;
                32'h000002F8: instruction = 32'h23430313;
                32'h000002FC: instruction = 32'h000053B7;
                32'h00000300: instruction = 32'h67838393;
                32'h00000304: instruction = 32'h00009E37;
                32'h00000308: instruction = 32'h0ABE0E13;
                32'h0000030C: instruction = 32'h0000DEB7;
                32'h00000310: instruction = 32'hDEFE8E93;
                32'h00000314: instruction = 32'h805312B3;
                32'h00000318: instruction = 32'h805392B3;
                32'h0000031C: instruction = 32'h805E12B3;
                32'h00000320: instruction = 32'h805E92B3;
                32'h00000324: instruction = 32'h0D129663;
                32'h00000328: instruction = 32'h00010537;
                32'h0000032C: instruction = 32'hFFF50513;
                32'h00000330: instruction = 32'h123455B7;
                32'h00000334: instruction = 32'h67858593;
                32'h00000338: instruction = 32'h90ABD637;
                32'h0000033C: instruction = 32'hDEF60613;
                32'h00000340: instruction = 32'h80A5A533;
                32'h00000344: instruction = 32'h80A62533;
                32'h00000348: instruction = 32'h0B151463;
                32'h0000034C: instruction = 32'h00000297;
                32'h00000350: instruction = 32'h0AC28293;
                32'h00000354: instruction = 32'h0002A303;
                32'h00000358: instruction = 32'h0042A383;
                32'h0000035C: instruction = 32'h00010537;
                32'h00000360: instruction = 32'hFFF50513;
                32'h00000364: instruction = 32'h80A32533;
                32'h00000368: instruction = 32'h80A3A533;
                32'h0000036C: instruction = 32'h000028B7;
                32'h00000370: instruction = 32'hE8288893;
                32'h00000374: instruction = 32'h07151E63;
                32'h00000378: instruction = 32'h01400293;
                32'h0000037C: instruction = 32'h00A00313;
                32'h00000380: instruction = 32'h006283B3;
                32'h00000384: instruction = 32'h40628E33;
                32'h00000388: instruction = 32'h03C38EB3;
                32'h0000038C: instruction = 32'h12C00F13;
                32'h00000390: instruction = 32'h07EE9063;
                32'h00000394: instruction = 32'h00000297;
                32'h00000398: instruction = 32'h06C28293;
                32'h0000039C: instruction = 32'h0FC10317;
                32'h000003A0: instruction = 32'hC7430313;
                32'h000003A4: instruction = 32'h00300393;
                32'h000003A8: instruction = 32'h0002AE03;
                32'h000003AC: instruction = 32'h01C32023;
                32'h000003B0: instruction = 32'h00428293;
                32'h000003B4: instruction = 32'h00430313;
                32'h000003B8: instruction = 32'hFFF38393;
                32'h000003BC: instruction = 32'hFE0396E3;
                32'h000003C0: instruction = 32'h0FC10317;
                32'h000003C4: instruction = 32'hC5030313;
                32'h000003C8: instruction = 32'h00032E03;
                32'h000003CC: instruction = 32'h11111EB7;
                32'h000003D0: instruction = 32'h111E8E93;
                32'h000003D4: instruction = 32'h01DE1E63;
                32'h000003D8: instruction = 32'h00832E03;
                32'h000003DC: instruction = 32'h33333EB7;
                32'h000003E0: instruction = 32'h333E8E93;
                32'h000003E4: instruction = 32'h01DE1663;
                32'h000003E8: instruction = 32'h00000213;
                32'h000003EC: instruction = 32'h0000006F;
                32'h000003F0: instruction = 32'hFFF00213;
                32'h000003F4: instruction = 32'h0000006F;
                32'h000003F8: instruction = 32'h12345678;
                32'h000003FC: instruction = 32'h90ABCDEF;
                32'h00000400: instruction = 32'h11111111;
                32'h00000404: instruction = 32'h22222222;
                32'h00000408: instruction = 32'h33333333;

                default:     instruction = 32'h00000013; // NOP (addi x0, x0, 0)
            endcase
        end else begin
            instruction = 32'h00000000;
        end
    end

    assign imem_output = instruction;

endmodule

module DMEM #(
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

module top (

  input wire clk,
  input wire rst_n,
  output wire o_halt

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

MemoryUnit_ff_equipe41 blk4428_31 (
         .clk (clk),
         .core_data_i (w_5),
         .core_address_o (w_18),
         .core_data_o (w_20),
         .read_enable (w_56),
         .write_enable (w_57),
         .op_size_o (w_58)
     );


endmodule
