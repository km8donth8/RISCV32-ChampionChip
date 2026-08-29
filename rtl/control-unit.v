`timescale 1ns / 1ps
/* Control Unit for RISCV Multi Cycle
will add more stuff here

MUX selections:
exec_result_sel_o  00 = ALU, 01 = Multiplier, 10 = CRC
wb_sel_o:          00=ALUOut, 01=MDR, 10=current PC+4
mem_addr_sel_o:     0=current PC, 1=ALUOut/effective address
mem_addr_sel_o:     0=current PC, 1=ALUOut/effective address

alu already defines:
alu_a_sel_o: 0=registered rs1, 1=current PC
alu_b_sel_o: 0=registered rs2, 1=extended immediate

reset is active low */

module ControlUnit (
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

  // extension/comparator controls
  , output reg          o_halt
  , output reg          o_illegal
  , output reg          o_state
);
  // 
  //  Instruction fields and opcodes    
  //

  wire [6:0] opcode = i_instruction[6:0];
  wire [2:0] funct3 = i_instruction[14:12];
  wire [6:0] funct7 = i_instructiion[31:25];

  , output reg OP_LOAD = 7'b0000011;
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

    assign state_o = state_q;
  
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
                        if ((instruction_i == 32'h00000073) ||
                            (instruction_i == 32'h00100073))
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
        pc_write_o          = 1'b0;
        ir_write_o          = 1'b0;
        operand_write_o     = 1'b0;
        aluout_write_o      = 1'b0;
        mdr_write_o         = 1'b0;
        reg_write_o         = 1'b0;

        pc_sel_o            = 1'b0;
        pc_lsb_clear_o      = 1'b0;

        alu_a_sel_o         = 1'b0;
        alu_b_sel_o         = 1'b0;
        alu_control_o       = ALU_ADD;

        exec_result_sel_o   = EXEC_ALU;
        wb_sel_o            = WB_ALUOUT;
        mem_addr_sel_o      = 1'b0;

        mem_read_o          = 1'b0;
        mem_write_o         = 1'b0;
        lsu_op_o            = LSU_LW;

        mult_sel_o          = 4'h0;
        crc_sel_o           = 2'b00;
        branch_sel_o        = funct3;

        halt_o              = 1'b0;
        illegal_o           = 1'b0;

        case (state_q)
            ST_FETCH: begin
                mem_addr_sel_o = 1'b0;       // current PC
                mem_read_o     = 1'b1;
                lsu_op_o       = LSU_LW;     // pass complete IMEM word
                ir_write_o     = 1'b1;
            end

            ST_DECODE: begin
                operand_write_o = 1'b1;      // Capture both rs1 and rs2
            end

            ST_EXEC_REG: begin
                alu_a_sel_o       = 1'b0;
                alu_b_sel_o       = 1'b0;
                alu_control_o     = decode_base_alu(funct3, funct7);
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_IMM: begin
                alu_a_sel_o       = 1'b0;
                alu_b_sel_o       = 1'b1;
                alu_control_o     = decode_imm_alu(funct3, funct7);
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_MUL: begin
                mult_sel_o        = {1'b0, funct3};
                exec_result_sel_o = EXEC_MUL;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_CRC: begin
                crc_sel_o         = funct3[1:0];
                exec_result_sel_o = EXEC_CRC;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_LUI: begin
                alu_b_sel_o       = 1'b1;
                alu_control_o     = ALU_PASS_B;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_AUIPC: begin
                alu_a_sel_o       = 1'b1;    // current instruction PC
                alu_b_sel_o       = 1'b1;    // uimm
                alu_control_o     = ALU_ADD;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_EXEC_MEM_ADDR: begin
                alu_a_sel_o       = 1'b0;    // rs1
                alu_b_sel_o       = 1'b1;    // load/store immediate
                alu_control_o     = ALU_ADD;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_LOAD_REQUEST: begin
                mem_addr_sel_o = 1'b1;       // ALUOut effective addr
                mem_read_o     = 1'b1;
                lsu_op_o       = decode_lsu(opcode, funct3);
            end

            ST_LOAD_CAPTURE: begin
                // works for both combinational and sync read DMEM, mdr captures response by prev req cycle
                mem_addr_sel_o = 1'b1;
                mem_read_o     = 1'b1;
                lsu_op_o       = decode_lsu(opcode, funct3);
                mdr_write_o    = 1'b1;
            end

            ST_LOAD_WB: begin
                wb_sel_o    = WB_MDR;
                reg_write_o = 1'b1;
                pc_sel_o    = 1'b0;
                pc_write_o  = 1'b1;
            end

            ST_STORE_WRITE: begin
                mem_addr_sel_o = 1'b1;
                mem_write_o    = 1'b1;
                lsu_op_o       = decode_lsu(opcode, funct3);
                pc_sel_o       = 1'b0;
                pc_write_o     = 1'b1;
            end

            ST_BRANCH_TARGET: begin
                alu_a_sel_o       = 1'b1;    // current PC
                alu_b_sel_o       = 1'b1;    // bimm
                alu_control_o     = ALU_ADD;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
                branch_sel_o      = funct3;
            end

            ST_BRANCH_COMMIT: begin
                branch_sel_o = funct3;
                pc_sel_o     = branch_taken_i;
                pc_write_o   = 1'b1;         // target/sequential PC+4
            end

            ST_JAL_TARGET: begin
                alu_a_sel_o       = 1'b1;    // current PC
                alu_b_sel_o       = 1'b1;    // jimm
                alu_control_o     = ALU_ADD;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_JAL_COMMIT: begin
                wb_sel_o    = WB_PC4;
                reg_write_o = 1'b1;
                pc_sel_o    = 1'b1;
                pc_write_o  = 1'b1;
            end

            ST_JALR_TARGET: begin
                alu_a_sel_o       = 1'b0;    // rs1
                alu_b_sel_o       = 1'b1;    // iimm
                alu_control_o     = ALU_ADD;
                exec_result_sel_o = EXEC_ALU;
                aluout_write_o    = 1'b1;
            end

            ST_JALR_COMMIT: begin
                wb_sel_o       = WB_PC4;
                reg_write_o    = 1'b1;
                pc_sel_o       = 1'b1;
                pc_lsb_clear_o = 1'b1;
                pc_write_o     = 1'b1;
            end

            ST_ALU_WB: begin
                wb_sel_o    = WB_ALUOUT;
                reg_write_o = 1'b1;
                pc_sel_o    = 1'b0;
                pc_write_o  = 1'b1;
            end

            ST_FENCE_COMMIT: begin
                // no datapath action
                pc_sel_o   = 1'b0;
                pc_write_o = 1'b1;
            end

            ST_HALT: begin
                halt_o = 1'b1;
            end

            ST_ILLEGAL: begin
                illegal_o = 1'b1;
                halt_o    = 1'b1;
            end

            default: begin
                illegal_o = 1'b1;
                halt_o    = 1'b1;
            end
        endcase
    end

endmodule



            