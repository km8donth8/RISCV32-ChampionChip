`timescale 1ns / 1ps
module testbench;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire o_halt;

    integer cycle, done_cycle, stuck;
    reg [31:0] last_pc;

    top dut (.clk(clk), .rst_n(rst_n), .o_halt(o_halt));

    always #5 clk = ~clk;   // 100 MHz

    // ----------------------------------------------------------------------
    // Waveform debug signals
    // ----------------------------------------------------------------------
    // Program flow
    wire [31:0] dbg_pc        = dut.blk4300_10.o_PC_Output;
    wire [31:0] dbg_pc_plus4  = dut.blk4300_10.o_PC_Plus_4;
    wire [31:0] dbg_ir        = dut.blk4368_28.ir;
    wire [5:0]  dbg_state     = dut.blk4354_26.state_q;
    wire        dbg_halt      = o_halt;

    // Result registers  (dbg_x4 is the pass/fail indicator)
    wire [31:0] dbg_x4        = dut.blk4352_11.regs[4];
    wire [31:0] dbg_x2_sp     = dut.blk4352_11.regs[2];
    wire [31:0] dbg_x3_gp     = dut.blk4352_11.regs[3];

    // Datapath
    wire [31:0] dbg_operand_a = dut.blk4369_15.A;
    wire [31:0] dbg_operand_b = dut.blk4366_16.B;
    wire [31:0] dbg_alu_out   = dut.blk4367_2.alu_out;
    wire [31:0] dbg_wb_data   = dut.blk4372_7.wb_data;

    // Memory interface
    wire [31:0] dbg_mem_addr  = dut.blk4373_8.mem_addr;
    wire [31:0] dbg_mem_rdata = dut.blk4370_5.mem_rdata;
    wire        dbg_mem_read  = dut.blk4354_26.o_mem_read;
    wire        dbg_mem_write = dut.blk4354_26.o_mem_write;

    // Control strobes
    wire        dbg_pc_write  = dut.blk4354_26.o_pc_write;
    wire        dbg_ir_write  = dut.blk4354_26.o_ir_write;
    wire        dbg_reg_write = dut.blk4354_26.o_reg_write;
    wire [3:0]  dbg_alu_ctrl  = dut.blk4354_26.o_alu_control;

    // ----------------------------------------------------------------------
    // FSM state name, so the waveform reads as states not numbers
    // ----------------------------------------------------------------------
    reg [127:0] dbg_state_name;
    always @(*) begin
        case (dbg_state)
            6'd0 : dbg_state_name = "FETCH";
            6'd1 : dbg_state_name = "DECODE";
            6'd2 : dbg_state_name = "EXEC_REG";
            6'd3 : dbg_state_name = "EXEC_IMM";
            6'd4 : dbg_state_name = "EXEC_MUL";
            6'd5 : dbg_state_name = "EXEC_CRC";
            6'd6 : dbg_state_name = "EXEC_LUI";
            6'd7 : dbg_state_name = "EXEC_AUIPC";
            6'd8 : dbg_state_name = "MEM_ADDR";
            6'd9 : dbg_state_name = "LOAD_REQ";
            6'd10: dbg_state_name = "LOAD_CAP";
            6'd11: dbg_state_name = "LOAD_WB";
            6'd12: dbg_state_name = "STORE_WR";
            6'd13: dbg_state_name = "BR_TARGET";
            6'd14: dbg_state_name = "BR_COMMIT";
            6'd15: dbg_state_name = "JAL_TARGET";
            6'd16: dbg_state_name = "JAL_COMMIT";
            6'd17: dbg_state_name = "JALR_TARGET";
            6'd18: dbg_state_name = "JALR_COMMIT";
            6'd19: dbg_state_name = "ALU_WB";
            6'd20: dbg_state_name = "FENCE";
            6'd21: dbg_state_name = "HALT";
            6'd22: dbg_state_name = "ILLEGAL";
            default: dbg_state_name = "?";
        endcase
    end

    // ----------------------------------------------------------------------
    // Progress trace - prints the first time each firmware section is entered
    // ----------------------------------------------------------------------
    reg [15:0] seen;
    task mark(input integer idx, input [31:0] addr, input [255:0] label);
    begin
        if (!seen[idx] && dbg_pc == addr && dbg_state == 6'd0) begin
            seen[idx] = 1'b1;
            $display("  [%6d cyc] PC=0x%h  %0s", cycle, addr, label);
        end
    end
    endtask

    always @(posedge clk) if (rst_n) begin
        mark(0,  32'h00400000, "ALU / LUI / AUIPC tests");
        mark(1,  32'h0040011C, "Load-store unit tests");
        mark(2,  32'h00400184, "Branch condition tests");
        mark(3,  32'h00400200, "Jump and link tests");
        mark(4,  32'h00400238, "Zmmul multiply tests");
        mark(5,  32'h00400298, "CRC register tests");
        mark(6,  32'h0040034C, "CRC from memory tests");
        mark(7,  32'h00400378, "Arithmetic integration");
        mark(8,  32'h00400394, "Data section copy");
        mark(9,  32'h004003E8, "_all_good reached");
        mark(10, 32'h004003F0, "_error reached");
    end

    // ----------------------------------------------------------------------
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(1, testbench);   // depth 1: the dbg_ signals only, clean view

        seen = 16'h0;

        $display("=========================================================");
        $display("   ChampionCHIP Stage 2 - Full Firmware Validation        ");
        $display("=========================================================");

        #23 rst_n = 1'b1;
        stuck = 0; last_pc = 32'hFFFFFFFF; done_cycle = 0;

        for (cycle = 0; cycle < 400000; cycle = cycle + 1) begin
            @(posedge clk);
            if (dbg_state == 6'd0) begin              // ST_FETCH
                if (dbg_pc == last_pc) begin
                    stuck = stuck + 1;
                    if (stuck > 3) begin              // self-loop reached
                        done_cycle = cycle;
                        cycle = 400000;
                    end
                end else begin
                    stuck   = 0;
                    last_pc = dbg_pc;
                end
            end
        end
        #1;

        $display("---------------------------------------------------------");
        $display("Final PC          : 0x%h", dbg_pc);
        $display("Cycles executed   : %0d", done_cycle);
        $display("x4 (result)       : 0x%h", dbg_x4);
        $display("x2 (sp)           : 0x%h", dbg_x2_sp);
        $display("x3 (gp)           : 0x%h", dbg_x3_gp);
        $display("Final state       : %0s", dbg_state_name);
        $display("---------------------------------------------------------");

        if (dbg_x4 === 32'h00000000 && stuck > 3)
            $display("STATUS: [ALL VALIDATION STAGES PASSED]");
        else if (dbg_x4 === 32'hFFFFFFFF)
            $display("STATUS: [FAILED - firmware reached _error]");
        else
            $display("STATUS: [DID NOT COMPLETE - check cycle limit]");

        $display("=========================================================");
        $finish;
    end

endmodule
