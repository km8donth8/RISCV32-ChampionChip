`timescale 1ns / 1ps
`default_nettype none

module tb_ControlUnit;

    reg         clk;
    reg         rst_n;
    reg [31:0]  i_instruction;
    reg         i_branch_taken;

    wire        o_pc_write;
    wire        o_ir_write;
    wire        o_operand_write;
    wire        o_aluout_write;
    wire        o_mdr_write;
    wire        o_reg_write;
    wire        o_pc_sel;
    wire        o_pc_lsb_clear;
    wire        o_alu_a_sel;
    wire        o_alu_b_sel;
    wire [3:0]  o_alu_control;
    wire [1:0]  o_exec_result_sel;
    wire [1:0]  o_wb_sel;
    wire        o_mem_addr_sel;
    wire        o_mem_read;
    wire        o_mem_write;
    wire [2:0]  o_lsu_op;
    wire [3:0]  o_mult_sel;
    wire [1:0]  o_crc_sel;
    wire [2:0]  o_branch_sel;
    wire        o_halt;
    wire        o_illegal;
    wire [5:0]  o_state;

    integer errors;
    integer tests;

    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_FENCE  = 7'b0001111;
    localparam [6:0] OP_IMM    = 7'b0010011;
    localparam [6:0] OP_AUIPC  = 7'b0010111;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_REG    = 7'b0110011;
    localparam [6:0] OP_LUI    = 7'b0110111;
    localparam [6:0] OP_BRANCH = 7'b1100011;
    localparam [6:0] OP_JALR   = 7'b1100111;
    localparam [6:0] OP_JAL    = 7'b1101111;

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

    localparam [2:0] LSU_LW  = 3'b000;
    localparam [2:0] LSU_LH  = 3'b001;
    localparam [2:0] LSU_LB  = 3'b010;
    localparam [2:0] LSU_LHU = 3'b011;
    localparam [2:0] LSU_LBU = 3'b100;
    localparam [2:0] LSU_SW  = 3'b101;
    localparam [2:0] LSU_SH  = 3'b110;
    localparam [2:0] LSU_SB  = 3'b111;

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

    ControlUnit dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .i_instruction     (i_instruction),
        .i_branch_taken    (i_branch_taken),
        .o_pc_write        (o_pc_write),
        .o_ir_write        (o_ir_write),
        .o_operand_write   (o_operand_write),
        .o_aluout_write    (o_aluout_write),
        .o_mdr_write       (o_mdr_write),
        .o_reg_write       (o_reg_write),
        .o_pc_sel          (o_pc_sel),
        .o_pc_lsb_clear    (o_pc_lsb_clear),
        .o_alu_a_sel       (o_alu_a_sel),
        .o_alu_b_sel       (o_alu_b_sel),
        .o_alu_control     (o_alu_control),
        .o_exec_result_sel (o_exec_result_sel),
        .o_wb_sel          (o_wb_sel),
        .o_mem_addr_sel    (o_mem_addr_sel),
        .o_mem_read        (o_mem_read),
        .o_mem_write       (o_mem_write),
        .o_lsu_op          (o_lsu_op),
        .o_mult_sel        (o_mult_sel),
        .o_crc_sel         (o_crc_sel),
        .o_branch_sel      (o_branch_sel),
        .o_halt            (o_halt),
        .o_illegal         (o_illegal),
        .o_state           (o_state)
    );

    always #5 clk = ~clk;

    function [31:0] make_r;
        input [6:0] f7;
        input [2:0] f3;
        input [6:0] op;
        begin
            make_r = {f7, 5'd2, 5'd1, f3, 5'd3, op};
        end
    endfunction

    function [31:0] make_i;
        input [11:0] imm;
        input [2:0]  f3;
        input [6:0]  op;
        begin
            make_i = {imm, 5'd1, f3, 5'd3, op};
        end
    endfunction

    function [31:0] make_s;
        input [11:0] imm;
        input [2:0]  f3;
        begin
            make_s = {imm[11:5], 5'd2, 5'd1, f3, imm[4:0], OP_STORE};
        end
    endfunction

    function [31:0] make_branch;
        input [2:0] f3;
        begin
            // The controller only decodes opcode/funct3, so a zero offset is enough.
            make_branch = {7'b0000000, 5'd2, 5'd1, f3, 5'b00000, OP_BRANCH};
        end
    endfunction

    task step_clock;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task expect_state;
        input [5:0] expected;
        input [8*32-1:0] label;
        begin
            if (o_state !== expected) begin
                $display("ERROR: %0s: state=%0d, expected=%0d at t=%0t",
                         label, o_state, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task expect_bit;
        input actual;
        input expected;
        input [8*32-1:0] label;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s: value=%b, expected=%b at t=%0t",
                         label, actual, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task expect_2;
        input [1:0] actual;
        input [1:0] expected;
        input [8*32-1:0] label;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s: value=%b, expected=%b at t=%0t",
                         label, actual, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task expect_3;
        input [2:0] actual;
        input [2:0] expected;
        input [8*32-1:0] label;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s: value=%b, expected=%b at t=%0t",
                         label, actual, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task expect_4;
        input [3:0] actual;
        input [3:0] expected;
        input [8*32-1:0] label;
        begin
            if (actual !== expected) begin
                $display("ERROR: %0s: value=%h, expected=%h at t=%0t",
                         label, actual, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task check_fetch;
        begin
            expect_state(ST_FETCH, "FETCH state");
            expect_bit(o_ir_write, 1'b1, "FETCH ir_write");
            expect_bit(o_mem_read, 1'b1, "FETCH mem_read");
            expect_bit(o_mem_write, 1'b0, "FETCH mem_write");
            expect_bit(o_mem_addr_sel, 1'b0, "FETCH memory address=PC");
            expect_3(o_lsu_op, LSU_LW, "FETCH LSU word operation");
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            i_instruction = 32'h00000013;
            i_branch_taken = 1'b0;
            #2;
            expect_state(ST_FETCH, "asynchronous reset");
            @(negedge clk);
            rst_n = 1'b1;
            #1;
            check_fetch;
        end
    endtask

    task begin_instruction;
        input [31:0] instruction;
        input [8*32-1:0] label;
        begin
            check_fetch;
            i_instruction = instruction;
            #1;
            step_clock;
            expect_state(ST_DECODE, label);
            expect_bit(o_operand_write, 1'b1, "DECODE operand_write");
            expect_bit(o_reg_write, 1'b0, "DECODE no register write");
            expect_bit(o_mem_write, 1'b0, "DECODE no memory write");
        end
    endtask

    task finish_alu_writeback;
        begin
            step_clock;
            expect_state(ST_ALU_WB, "ALU writeback state");
            expect_2(o_wb_sel, WB_ALUOUT, "ALU writeback source");
            expect_bit(o_reg_write, 1'b1, "ALU writeback reg_write");
            expect_bit(o_pc_write, 1'b1, "ALU writeback pc_write");
            expect_bit(o_pc_sel, 1'b0, "ALU writeback selects PC+4");
            expect_bit(o_mem_write, 1'b0, "ALU writeback no memory write");
            step_clock;
            check_fetch;
        end
    endtask

    task test_reg;
        input [6:0] f7;
        input [2:0] f3;
        input [3:0] expected_alu;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_r(f7, f3, OP_REG), label);
            step_clock;
            expect_state(ST_EXEC_REG, label);
            expect_bit(o_alu_a_sel, 1'b0, "R-type ALU A=rs1");
            expect_bit(o_alu_b_sel, 1'b0, "R-type ALU B=rs2");
            expect_4(o_alu_control, expected_alu, label);
            expect_2(o_exec_result_sel, EXEC_ALU, "R-type execution source");
            expect_bit(o_aluout_write, 1'b1, "R-type saves ALU result");
            finish_alu_writeback;
        end
    endtask

    task test_imm;
        input [11:0] imm;
        input [2:0] f3;
        input [3:0] expected_alu;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_i(imm, f3, OP_IMM), label);
            step_clock;
            expect_state(ST_EXEC_IMM, label);
            expect_bit(o_alu_a_sel, 1'b0, "I-type ALU A=rs1");
            expect_bit(o_alu_b_sel, 1'b1, "I-type ALU B=immediate");
            expect_4(o_alu_control, expected_alu, label);
            expect_2(o_exec_result_sel, EXEC_ALU, "I-type execution source");
            expect_bit(o_aluout_write, 1'b1, "I-type saves ALU result");
            finish_alu_writeback;
        end
    endtask

    task test_mul;
        input [2:0] f3;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_r(7'b0000001, f3, OP_REG), label);
            step_clock;
            expect_state(ST_EXEC_MUL, label);
            expect_4(o_mult_sel, {1'b0, f3}, label);
            expect_2(o_exec_result_sel, EXEC_MUL, "multiplier execution source");
            expect_bit(o_aluout_write, 1'b1, "multiplier result capture");
            finish_alu_writeback;
        end
    endtask

    task test_crc;
        input [2:0] f3;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_r(7'b1000000, f3, OP_REG), label);
            step_clock;
            expect_state(ST_EXEC_CRC, label);
            expect_2(o_crc_sel, f3[1:0], label);
            expect_2(o_exec_result_sel, EXEC_CRC, "CRC execution source");
            expect_bit(o_aluout_write, 1'b1, "CRC result capture");
            finish_alu_writeback;
        end
    endtask

    task test_load;
        input [2:0] f3;
        input [2:0] expected_lsu;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_i(12'h004, f3, OP_LOAD), label);
            step_clock;
            expect_state(ST_EXEC_MEM_ADDR, label);
            expect_bit(o_alu_a_sel, 1'b0, "load address A=rs1");
            expect_bit(o_alu_b_sel, 1'b1, "load address B=immediate");
            expect_4(o_alu_control, ALU_ADD, "load effective address addition");
            expect_bit(o_aluout_write, 1'b1, "load effective address capture");
            step_clock;
            expect_state(ST_LOAD_REQUEST, label);
            expect_bit(o_mem_addr_sel, 1'b1, "load address=ALUOut");
            expect_bit(o_mem_read, 1'b1, "load memory request");
            expect_3(o_lsu_op, expected_lsu, label);
            step_clock;
            expect_state(ST_LOAD_CAPTURE, label);
            expect_bit(o_mem_read, 1'b1, "load capture keeps read enabled");
            expect_bit(o_mdr_write, 1'b1, "load MDR capture");
            expect_3(o_lsu_op, expected_lsu, label);
            step_clock;
            expect_state(ST_LOAD_WB, label);
            expect_2(o_wb_sel, WB_MDR, "load writeback source=MDR");
            expect_bit(o_reg_write, 1'b1, "load register write");
            expect_bit(o_pc_write, 1'b1, "load advances PC");
            step_clock;
            check_fetch;
        end
    endtask

    task test_store;
        input [2:0] f3;
        input [2:0] expected_lsu;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(make_s(12'h004, f3), label);
            step_clock;
            expect_state(ST_EXEC_MEM_ADDR, label);
            expect_bit(o_alu_a_sel, 1'b0, "store address A=rs1");
            expect_bit(o_alu_b_sel, 1'b1, "store address B=immediate");
            expect_4(o_alu_control, ALU_ADD, "store effective address addition");
            expect_bit(o_aluout_write, 1'b1, "store effective address capture");
            step_clock;
            expect_state(ST_STORE_WRITE, label);
            expect_bit(o_mem_addr_sel, 1'b1, "store address=ALUOut");
            expect_bit(o_mem_write, 1'b1, "store memory write");
            expect_bit(o_mem_read, 1'b0, "store no memory read");
            expect_bit(o_reg_write, 1'b0, "store no register write");
            expect_bit(o_pc_write, 1'b1, "store advances PC");
            expect_3(o_lsu_op, expected_lsu, label);
            step_clock;
            check_fetch;
        end
    endtask

    task test_branch;
        input [2:0] f3;
        input taken;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            i_branch_taken = taken;
            begin_instruction(make_branch(f3), label);
            i_branch_taken = taken;
            step_clock;
            expect_state(ST_BRANCH_TARGET, label);
            expect_bit(o_alu_a_sel, 1'b1, "branch target A=PC");
            expect_bit(o_alu_b_sel, 1'b1, "branch target B=immediate");
            expect_4(o_alu_control, ALU_ADD, "branch target addition");
            expect_bit(o_aluout_write, 1'b1, "branch target capture");
            expect_3(o_branch_sel, f3, label);
            step_clock;
            expect_state(ST_BRANCH_COMMIT, label);
            expect_bit(o_pc_write, 1'b1, "branch writes PC");
            expect_bit(o_pc_sel, taken, label);
            expect_bit(o_reg_write, 1'b0, "branch no register write");
            expect_3(o_branch_sel, f3, label);
            step_clock;
            i_branch_taken = 1'b0;
            check_fetch;
        end
    endtask

    task test_lui;
        begin
            tests = tests + 1;
            begin_instruction({20'h12345, 5'd3, OP_LUI}, "LUI");
            step_clock;
            expect_state(ST_EXEC_LUI, "LUI execute");
            expect_bit(o_alu_b_sel, 1'b1, "LUI B=immediate");
            expect_4(o_alu_control, ALU_PASS_B, "LUI passes immediate");
            expect_bit(o_aluout_write, 1'b1, "LUI result capture");
            finish_alu_writeback;
        end
    endtask

    task test_auipc;
        begin
            tests = tests + 1;
            begin_instruction({20'h12345, 5'd3, OP_AUIPC}, "AUIPC");
            step_clock;
            expect_state(ST_EXEC_AUIPC, "AUIPC execute");
            expect_bit(o_alu_a_sel, 1'b1, "AUIPC A=PC");
            expect_bit(o_alu_b_sel, 1'b1, "AUIPC B=immediate");
            expect_4(o_alu_control, ALU_ADD, "AUIPC addition");
            expect_bit(o_aluout_write, 1'b1, "AUIPC result capture");
            finish_alu_writeback;
        end
    endtask

    task test_jal;
        begin
            tests = tests + 1;
            begin_instruction({25'h0010003, OP_JAL}, "JAL");
            step_clock;
            expect_state(ST_JAL_TARGET, "JAL target");
            expect_bit(o_alu_a_sel, 1'b1, "JAL A=PC");
            expect_bit(o_alu_b_sel, 1'b1, "JAL B=immediate");
            expect_4(o_alu_control, ALU_ADD, "JAL target addition");
            expect_bit(o_aluout_write, 1'b1, "JAL target capture");
            step_clock;
            expect_state(ST_JAL_COMMIT, "JAL commit");
            expect_2(o_wb_sel, WB_PC4, "JAL link=PC+4");
            expect_bit(o_reg_write, 1'b1, "JAL link register write");
            expect_bit(o_pc_sel, 1'b1, "JAL selects target");
            expect_bit(o_pc_write, 1'b1, "JAL writes PC");
            step_clock;
            check_fetch;
        end
    endtask

    task test_jalr;
        begin
            tests = tests + 1;
            begin_instruction(make_i(12'h004, 3'b000, OP_JALR), "JALR");
            step_clock;
            expect_state(ST_JALR_TARGET, "JALR target");
            expect_bit(o_alu_a_sel, 1'b0, "JALR A=rs1");
            expect_bit(o_alu_b_sel, 1'b1, "JALR B=immediate");
            expect_4(o_alu_control, ALU_ADD, "JALR target addition");
            expect_bit(o_aluout_write, 1'b1, "JALR target capture");
            step_clock;
            expect_state(ST_JALR_COMMIT, "JALR commit");
            expect_2(o_wb_sel, WB_PC4, "JALR link=PC+4");
            expect_bit(o_reg_write, 1'b1, "JALR link register write");
            expect_bit(o_pc_sel, 1'b1, "JALR selects target");
            expect_bit(o_pc_lsb_clear, 1'b1, "JALR clears target bit zero");
            expect_bit(o_pc_write, 1'b1, "JALR writes PC");
            step_clock;
            check_fetch;
        end
    endtask

    task test_fence;
        begin
            tests = tests + 1;
            begin_instruction({25'b0, OP_FENCE}, "FENCE");
            step_clock;
            expect_state(ST_FENCE_COMMIT, "FENCE commit");
            expect_bit(o_pc_write, 1'b1, "FENCE advances PC");
            expect_bit(o_reg_write, 1'b0, "FENCE no register write");
            expect_bit(o_mem_write, 1'b0, "FENCE no memory write");
            step_clock;
            check_fetch;
        end
    endtask

    task test_halt;
        input [31:0] instruction;
        input [8*32-1:0] label;
        begin
            tests = tests + 1;
            begin_instruction(instruction, label);
            step_clock;
            expect_state(ST_HALT, label);
            expect_bit(o_halt, 1'b1, label);
            expect_bit(o_illegal, 1'b0, "valid system instruction");
            expect_bit(o_pc_write, 1'b0, "HALT holds PC");
            step_clock;
            expect_state(ST_HALT, "HALT remains halted");
            reset_dut;
        end
    endtask

    task test_illegal;
        begin
            begin_instruction(32'hFFFFFFFF, "illegal opcode");
            step_clock;
            expect_state(ST_ILLEGAL, "illegal state");
            expect_bit(o_illegal, 1'b1, "illegal flag");
            expect_bit(o_halt, 1'b1, "illegal instruction halts");
            expect_bit(o_pc_write, 1'b0, "illegal holds PC");
            expect_bit(o_reg_write, 1'b0, "illegal no register write");
            expect_bit(o_mem_write, 1'b0, "illegal no memory write");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        i_instruction = 32'h00000013;
        i_branch_taken = 1'b0;
        errors = 0;
        tests = 0;

        $dumpfile("tb_ControlUnit.vcd");
        $dumpvars(0, tb_ControlUnit);

        reset_dut;

        // Ten RV32I register-register operations.
        test_reg(7'b0000000, 3'b000, ALU_ADD,  "ADD");
        test_reg(7'b0100000, 3'b000, ALU_SUB,  "SUB");
        test_reg(7'b0000000, 3'b001, ALU_SLL,  "SLL");
        test_reg(7'b0000000, 3'b010, ALU_SLT,  "SLT");
        test_reg(7'b0000000, 3'b011, ALU_SLTU, "SLTU");
        test_reg(7'b0000000, 3'b100, ALU_XOR,  "XOR");
        test_reg(7'b0000000, 3'b101, ALU_SRL,  "SRL");
        test_reg(7'b0100000, 3'b101, ALU_SRA,  "SRA");
        test_reg(7'b0000000, 3'b110, ALU_OR,   "OR");
        test_reg(7'b0000000, 3'b111, ALU_AND,  "AND");

        // Nine RV32I immediate operations.
        test_imm(12'h005, 3'b000, ALU_ADD,  "ADDI");
        test_imm(12'h005, 3'b010, ALU_SLT,  "SLTI");
        test_imm(12'h005, 3'b011, ALU_SLTU, "SLTIU");
        test_imm(12'h005, 3'b100, ALU_XOR,  "XORI");
        test_imm(12'h005, 3'b110, ALU_OR,   "ORI");
        test_imm(12'h005, 3'b111, ALU_AND,  "ANDI");
        test_imm({7'b0000000, 5'd5}, 3'b001, ALU_SLL, "SLLI");
        test_imm({7'b0000000, 5'd5}, 3'b101, ALU_SRL, "SRLI");
        test_imm({7'b0100000, 5'd5}, 3'b101, ALU_SRA, "SRAI");

        // Four Zmmul operations.
        test_mul(3'b000, "MUL");
        test_mul(3'b001, "MULH");
        test_mul(3'b010, "MULHSU");
        test_mul(3'b011, "MULHU");

        // Three Xicrc operations.
        test_crc(3'b000, "CRCB");
        test_crc(3'b001, "CRCH");
        test_crc(3'b010, "CRCW");

        // Five loads and three stores.
        test_load(3'b000, LSU_LB,  "LB");
        test_load(3'b001, LSU_LH,  "LH");
        test_load(3'b010, LSU_LW,  "LW");
        test_load(3'b100, LSU_LBU, "LBU");
        test_load(3'b101, LSU_LHU, "LHU");
        test_store(3'b000, LSU_SB, "SB");
        test_store(3'b001, LSU_SH, "SH");
        test_store(3'b010, LSU_SW, "SW");

        // Six branches, including both taken and untaken paths.
        test_branch(3'b000, 1'b0, "BEQ untaken");
        test_branch(3'b001, 1'b1, "BNE taken");
        test_branch(3'b100, 1'b1, "BLT taken");
        test_branch(3'b101, 1'b0, "BGE untaken");
        test_branch(3'b110, 1'b1, "BLTU taken");
        test_branch(3'b111, 1'b0, "BGEU untaken");

        test_jal;
        test_jalr;
        test_lui;
        test_auipc;
        test_fence;

        test_halt(32'h00000073, "ECALL");
        test_halt(32'h00100073, "EBREAK");
        test_illegal;

        if (tests !== 47) begin
            $display("ERROR: testbench ran %0d required-instruction tests, expected 47", tests);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: all %0d required instructions and the illegal path passed", tests);
        end else begin
            $display("FAIL: %0d error(s) across %0d instruction tests", errors, tests);
            $fatal(1);
        end

        $finish;
    end

endmodule

`default_nettype wire