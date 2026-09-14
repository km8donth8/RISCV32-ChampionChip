`timescale 1ns / 1ps
module testbench;

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire o_halt;

    integer i;
    integer errors = 0;

    top dut (.clk(clk), .rst_n(rst_n), .o_halt(o_halt));

    always #5 clk = ~clk;   // 100 MHz

    // ----------------------------------------------------------------------
    // Waveform debug signals
    // ----------------------------------------------------------------------
    wire [31:0] dbg_pc     = dut.blk4480_4.blk4300_34.o_PC_Output;
    wire [31:0] dbg_ir     = dut.blk4480_4.blk4368_28.ir;
    wire [5:0]  dbg_state  = dut.blk4480_4.blk4354_26.state_q;
    wire        dbg_halt   = o_halt;

    wire [31:0] dbg_x5     = dut.blk4480_4.blk4352_11.regs[5];
    wire [31:0] dbg_x6     = dut.blk4480_4.blk4352_11.regs[6];
    wire [31:0] dbg_x7     = dut.blk4480_4.blk4352_11.regs[7];
    wire [31:0] dbg_x2_sp  = dut.blk4480_4.blk4352_11.regs[2];
    wire [31:0] dbg_x3_gp  = dut.blk4480_4.blk4352_11.regs[3];

    wire [31:0] dbg_op_a   = dut.blk4480_4.blk4369_35.A;
    wire [31:0] dbg_op_b   = dut.blk4480_4.blk4366_36.B;
    wire [31:0] dbg_alu    = dut.blk4480_4.blk4367_2.alu_out;
    wire [31:0] dbg_wb     = dut.blk4480_4.blk4372_7.wb_data;
    wire        dbg_regwr  = dut.blk4480_4.blk4354_26.o_reg_write;

    // FSM state name, so the waveform reads as states not numbers
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
    task check(input [31:0] got, input [31:0] exp, input [255:0] name);
    begin
        if (got !== exp) begin
            $display("[FAIL] %0s | Expected: 0x%h, Got: 0x%h", name, exp, got);
            errors = errors + 1;
        end else begin
            $display("[PASS] %0s | 0x%h (%0d)", name, got, got);
        end
    end
    endtask

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(1, testbench);

        $display("=========================================================");
        $display("   Mock Program Verification - Physical Build             ");
        $display("=========================================================");
        $display("--- Reset state ---");

        #12;
        check(dbg_pc,    32'h00400000, "PC reset value            ");
        check(dbg_x3_gp, 32'h10010000, "x3 (gp) reset value       ");
        check(dbg_x2_sp, 32'h10010008, "x2 (sp) reset value       ");
        check(dbg_x5,    32'h00000000, "x5 cleared on reset       ");
        check(dbg_x7,    32'h00000000, "x7 cleared on reset       ");

        rst_n = 1'b1;

        // allow the three instructions to fetch, execute and retire
        for (i = 0; i < 400; i = i + 1) @(posedge clk);
        #1;

        $display("--- Program results ---");
        check(dbg_x5, 32'h0000000A, "addi x5, x0, 10           ");
        check(dbg_x6, 32'h00000005, "addi x6, x0, 5            ");
        check(dbg_x7, 32'h0000000F, "add  x7, x5, x6           ");

        $display("---------------------------------------------------------");
        $display("Final PC          : 0x%h", dbg_pc);
        $display("Final state       : %0s", dbg_state_name);
        $display("Halt              : %b", dbg_halt);
        $display("---------------------------------------------------------");

        if (errors == 0)
            $display("STATUS: [ALL MOCK PROGRAM TESTS PASSED]");
        else
            $display("STATUS: [FAILED %0d TEST(S)]", errors);

        $display("=========================================================");
        $finish;
    end

endmodule
