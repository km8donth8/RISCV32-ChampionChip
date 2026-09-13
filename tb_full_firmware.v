`timescale 1ns / 1ps
module testbench;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire o_halt;

    integer cycle, done_cycle, stuck;
    reg [31:0] last_pc;

    top dut (.clk(clk), .rst_n(rst_n), .o_halt(o_halt));
	// Easy-to-read waveform debug signals
	wire [31:0] dbg_pc       = dut.w_15;
	wire [5:0]  dbg_state    = dut.blk4354_26.state_q;
	wire [31:0] dbg_ir       = dut.w_27;

	wire [31:0] dbg_x4       = dut.blk4352_11.regs[4];
	wire [31:0] dbg_x2_sp    = dut.blk4352_11.regs[2];
	wire [31:0] dbg_x3_gp    = dut.blk4352_11.regs[3];

	wire dbg_pc_write        = dut.w_24;
	wire dbg_ir_write        = dut.w_53;
	wire dbg_reg_write       = dut.w_26;

	// Use ControlUnit hierarchy for these two
	wire dbg_mem_read        = dut.blk4354_26.o_mem_read;
	wire dbg_mem_write       = dut.blk4354_26.o_mem_write;

	wire [31:0] dbg_alu_out  = dut.w_3;
	wire [31:0] dbg_mem_addr = dut.w_18;

    always #5 clk = ~clk;   // 100 MHz

    // shorthand into the design hierarchy
    `define PC     dut.blk4300_10.o_PC_Output
    `define STATE  dut.blk4354_26.state_q
    `define REGS   dut.blk4352_11.regs

    initial begin
    $dumpfile("testbench.vcd");
      $dumpvars(1,testbench);

        $display("=========================================================");
        $display("   ChampionCHIP Stage 2 - Full Firmware Validation        ");
        $display("=========================================================");

        #23 rst_n = 1'b1;
        stuck = 0; last_pc = 32'hFFFFFFFF; done_cycle = 0;

        for (cycle = 0; cycle < 400000; cycle = cycle + 1) begin
            @(posedge clk);
            if (`STATE == 6'd0) begin                 // ST_FETCH
                if (`PC == last_pc) begin
                    stuck = stuck + 1;
                    if (stuck > 3) begin              // self-loop reached
                        done_cycle = cycle;
                        cycle = 400000;
                    end
                end else begin
                    stuck   = 0;
                    last_pc = `PC;
                end
            end
        end
        #1;

        $display("Final PC          : 0x%h", `PC);
        $display("Cycles executed   : %0d", done_cycle);
        $display("x4 (result)       : 0x%h", `REGS[4]);
        $display("x2 (sp)           : 0x%h", `REGS[2]);
        $display("x3 (gp)           : 0x%h", `REGS[3]);
        $display("---------------------------------------------------------");

        if (`REGS[4] === 32'h00000000 && stuck > 3)
            $display("STATUS: [ALL VALIDATION STAGES PASSED]");
        else if (`REGS[4] === 32'hFFFFFFFF)
            $display("STATUS: [FAILED - firmware reached _error]");
        else
            $display("STATUS: [DID NOT COMPLETE - check cycle limit]");

        $display("=========================================================");
        $finish;
    end

endmodule
