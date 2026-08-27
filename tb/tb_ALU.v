`timescale 1ns / 1ps

module tb_ALU();

    // Inputs
    reg [31:0] reg_rs_1;
    reg [31:0] reg_rs_2;
    reg [31:0] pc_output;
    reg [31:0] immediate;
    reg [3:0]  ALU_control;
    reg        A_sel;
    reg        B_sel;

    // Output
    wire signed [31:0] Q;

    // Instantiate Unit Under Test (UUT)
    ALU uut (
        .reg_rs_1(reg_rs_1),
        .reg_rs_2(reg_rs_2),
        .pc_output(pc_output),
        .immediate(immediate),
        .ALU_control(ALU_control),
        .A_sel(A_sel),
        .B_sel(B_sel),
        .Q(Q)
    );

    initial begin
        // Display headers
        $display("----------------------------------------------------------------------");
        $display("Time | A_sel B_sel | Control |   Operand A  |   Operand B  |   Output Q   ");
        $display("----------------------------------------------------------------------");

        // Initialize inputs
        reg_rs_1    = 32'h0000_000A; // 10
        reg_rs_2    = 32'h0000_0003; // 3
        pc_output   = 32'h0000_0100; // 256
        immediate   = 32'hFFFF_FFFE; // -2 (signed) or 4294967294 (unsigned)
        A_sel       = 1'b0;
        B_sel       = 1'b0;
        ALU_control = 4'h0;

        #10;

        // Test 1: PASS_B (B_sel = 0 -> reg_rs_2)
        ALU_control = `c_ALU_OP_PASS_B; A_sel = 0; B_sel = 0; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        // Test 2: ADD (A_sel = 1 -> pc_output, B_sel = 1 -> immediate)
        ALU_control = `c_ALU_OP_ADD; A_sel = 1; B_sel = 1; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        // Test 3: SUB
        ALU_control = `c_ALU_OP_SUB; A_sel = 0; B_sel = 0; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        // Test 4: AND, OR, XOR
        ALU_control = `c_ALU_OP_AND; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);
        ALU_control = `c_ALU_OP_OR;  #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);
        ALU_control = `c_ALU_OP_XOR; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        // Test 5: Shifts (SLL, SRL, MRS) using negative value to show sign extension difference
        reg_rs_1 = 32'h8000_000F; // Negative number with sign bit set
        reg_rs_2 = 32'h0000_0004; // Shift amount = 4
        ALU_control = `c_ALU_OP_SLL; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h (SLL)", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);
        ALU_control = `c_ALU_OP_SRL; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h (SRL)", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);
        ALU_control = `c_ALU_OP_MRS; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h (MRS)", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        // Test 6: SLT vs SLTU (-2 vs 10)
        reg_rs_1 = 32'hFFFF_FFFE; // -2 signed, or 4,294,967,294 unsigned
        reg_rs_2 = 32'h0000_000A; // +10 signed, or 10 unsigned
        
        // SLT (-2 < 10) -> Should be 1
        ALU_control = `c_ALU_OP_SLT; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h (SLT: Expected 1)", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);
        
        // SLTU (4294967294 < 10) -> Should be 0
        ALU_control = `c_ALU_OP_SLTU; #10;
        $display("%4t |   %b     %b   |   %h   |  0x%h  |  0x%h  |  0x%h (SLTU: Expected 0)", $time, A_sel, B_sel, ALU_control, uut.A_Mux, uut.B_Mux, Q);

        $display("----------------------------------------------------------------------");
        $finish;
    end

endmodule