`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 11:15:22
// Design Name: 
// Module Name: tb_Multiplier
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

`timescale 1ns / 1ps

module tb_Multiplier();

    reg [31:0] reg_rs_1;
    reg [31:0] reg_rs_2;
    reg [3:0]  mult_sel;
    wire [31:0] rd;

    reg [31:0] expected_rd;

    Multiplier uut (
        .reg_rs_1(reg_rs_1),
        .reg_rs_2(reg_rs_2),
        .mult_sel(mult_sel),
        .rd(rd)
    );

    initial begin
        $display("----------------------------------------------------------------------------------");
        $display("Time | Opcode  |   Operand 1  |   Operand 2  | Expected Q   | Actual Q     | Status");
        $display("----------------------------------------------------------------------------------");

        // Test Setup: Large numbers to stress upper/lower 32-bit slices
        // reg_rs_1 = -5 (0xFFFFFFFB)
        // reg_rs_2 = +10 (0x0000000A)
        reg_rs_1 = 32'hFFFF_FFFB; 
        reg_rs_2 = 32'h0000_000A;

        // --------------------------------------------------------------------
        // Test 1: MUL (Lower 32 bits)
        // --------------------------------------------------------------------
        mult_sel = `MUL;
        expected_rd = ($signed(reg_rs_1) * $signed(reg_rs_2));
        #10;
        $display("%4t | MUL     |  0x%h  |  0x%h  |  0x%h  |  0x%h  | %s", 
                 $time, reg_rs_1, reg_rs_2, expected_rd, rd, (rd === expected_rd) ? "PASS" : "FAIL");

        // --------------------------------------------------------------------
        // Test 2: MULH (Signed * Signed, Upper 32 bits)
        // -5 * +10 = -50 (64-bit: 0xFFFFFFFFFFFFFFCE) -> Upper 32 = 0xFFFFFFFF
        // --------------------------------------------------------------------
        mult_sel = `MULH;
        expected_rd = 32'hFFFF_FFFF;
        #10;
        $display("%4t | MULH    |  0x%h  |  0x%h  |  0x%h  |  0x%h  | %s", 
                 $time, reg_rs_1, reg_rs_2, expected_rd, rd, (rd === expected_rd) ? "PASS" : "FAIL");

        // --------------------------------------------------------------------
        // Test 3: MULHSU (Signed * Unsigned, Upper 32 bits)
        // reg_rs_1 = -2 (0xFFFFFFFE)
        // reg_rs_2 = 3 (0x00000003)
        // --------------------------------------------------------------------
        reg_rs_1 = 32'hFFFF_FFFE;
        reg_rs_2 = 32'h0000_0003;
        mult_sel = `MULHSU;
        expected_rd = 32'hFFFF_FFFF; // Upper bits of (-2 * 3)
        #10;
        $display("%4t | MULHSU  |  0x%h  |  0x%h  |  0x%h  |  0x%h  | %s", 
                 $time, reg_rs_1, reg_rs_2, expected_rd, rd, (rd === expected_rd) ? "PASS" : "FAIL");

        // --------------------------------------------------------------------
        // Test 4: MULHU (Unsigned * Unsigned, Upper 32 bits)
        // reg_rs_1 = 0x8000_0000 (2,147,483,648 unsigned)
        // reg_rs_2 = 0x0000_0004 (4 unsigned)
        // Product = 0x2_0000_0000 -> Upper 32 bits = 0x0000_0002
        // --------------------------------------------------------------------
        reg_rs_1 = 32'h8000_0000;
        reg_rs_2 = 32'h0000_0004;
        mult_sel = `MULHU;
        expected_rd = 32'h0000_0002;
        #10;
        $display("%4t | MULHU   |  0x%h  |  0x%h  |  0x%h  |  0x%h  | %s", 
                 $time, reg_rs_1, reg_rs_2, expected_rd, rd, (rd === expected_rd) ? "PASS" : "FAIL");

        $display("----------------------------------------------------------------------------------");
        $finish;
    end

endmodule
