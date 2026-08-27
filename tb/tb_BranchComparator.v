`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 16:03:12
// Design Name: 
// Module Name: tb_BranchComparator
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


module tb_BranchComparator;

    // Inputs
    reg signed [31:0] reg_rs_1;
    reg signed [31:0] reg_rs_2;
    reg [2:0] Branch_Sel;

    // Output
    wire o_Branch_Taken;

    // Branch Sel Definitions
    localparam c_BEQ  = 3'b000;
    localparam c_BNE  = 3'b001;
    localparam c_BLT  = 3'b100;
    localparam c_BGE  = 3'b101;
    localparam c_BLTU = 3'b110;
    localparam c_BGEU = 3'b111;

    // Instantiate UUT
    BranchComparator uut (
        .reg_rs_1(reg_rs_1),
        .reg_rs_2(reg_rs_2),
        .Branch_Sel(Branch_Sel),
        .o_Branch_Taken(o_Branch_Taken)
    );

    // Verification Helper Task
    task check_branch(
        input [2:0] sel,
        input expected,
        input [200:1] test_name
    );
        begin
            Branch_Sel = sel;
            #5; // Wait for combinational evaluation
            if (o_Branch_Taken === expected) begin
                $display("[PASS] %-45s | Branch_Sel: 3'b%03b | Taken: %b", test_name, sel, o_Branch_Taken);
            end else begin
                $display("[FAIL] %-45s | Branch_Sel: 3'b%03b | Expected: %b, Got: %b", test_name, sel, expected, o_Branch_Taken);
            end
        end
    endtask

    initial begin
        $display("==================================================================================");
        $display("                  RIGOROUS BRANCH COMPARATOR TESTBENCH                           ");
        $display("==================================================================================");

        // --------------------------------------------------------------------------------
        // TEST CASE 1: Signed vs Unsigned Trap (0 vs -1 / 0xFFFF_FFFF)
        // --------------------------------------------------------------------------------
        reg_rs_1 = 32'h0000_0000; //  0
        reg_rs_2 = 32'hFFFF_FFFF; // -1 (signed) OR 4294967295 (unsigned)
        
        check_branch(c_BEQ,  1'b0, "TC1: 0 == -1 (BEQ)");
        check_branch(c_BNE,  1'b1, "TC1: 0 != -1 (BNE)");
        check_branch(c_BLT,  1'b0, "TC1: 0 < -1 Signed (BLT)");
        check_branch(c_BGE,  1'b1, "TC1: 0 >= -1 Signed (BGE)");
        check_branch(c_BLTU, 1'b1, "TC1: 0 < 4294967295 Unsigned (BLTU)");
        check_branch(c_BGEU, 1'b0, "TC1: 0 >= 4294967295 Unsigned (BGEU)");

        $display("----------------------------------------------------------------------------------");

        // --------------------------------------------------------------------------------
        // TEST CASE 2: Extreme Limits (INT_MAX vs INT_MIN)
        // --------------------------------------------------------------------------------
        reg_rs_1 = 32'h7FFF_FFFF; // +2147483647 (INT_MAX)
        reg_rs_2 = 32'h8000_0000; // -2147483648 (INT_MIN)

        check_branch(c_BLT,  1'b0, "TC2: INT_MAX < INT_MIN Signed (BLT)");
        check_branch(c_BGE,  1'b1, "TC2: INT_MAX >= INT_MIN Signed (BGE)");
        check_branch(c_BLTU, 1'b1, "TC2: 0x7FFFFFFF < 0x80000000 Unsigned (BLTU)");
        check_branch(c_BGEU, 1'b0, "TC2: 0x7FFFFFFF >= 0x80000000 Unsigned (BGEU)");

        $display("----------------------------------------------------------------------------------");

        // --------------------------------------------------------------------------------
        // TEST CASE 3: Equal Negative Values (-500 vs -500)
        // --------------------------------------------------------------------------------
        reg_rs_1 = -32'sd500; // 32'hFFFF_FE0C
        reg_rs_2 = -32'sd500; // 32'hFFFF_FE0C

        check_branch(c_BEQ,  1'b1, "TC3: -500 == -500 (BEQ)");
        check_branch(c_BNE,  1'b0, "TC3: -500 != -500 (BNE)");
        check_branch(c_BGE,  1'b1, "TC3: -500 >= -500 Signed (BGE)");
        check_branch(c_BGEU, 1'b1, "TC3: -500 >= -500 Unsigned (BGEU)");

        $display("----------------------------------------------------------------------------------");

        // --------------------------------------------------------------------------------
        // TEST CASE 4: Off-By-One Near Zero
        // --------------------------------------------------------------------------------
        reg_rs_1 = -32'sd1;   // 32'hFFFF_FFFF
        reg_rs_2 = 32'sd0;    // 32'h0000_0000

        check_branch(c_BLT,  1'b1, "TC4: -1 < 0 Signed (BLT)");
        check_branch(c_BLTU, 1'b0, "TC4: 0xFFFFFFFF < 0 Unsigned (BLTU)");

        $display("----------------------------------------------------------------------------------");

        // --------------------------------------------------------------------------------
        // TEST CASE 5: Invalid/Unused Funct3 Code
        // --------------------------------------------------------------------------------
        check_branch(3'b010, 1'b0, "TC5: Reserved Funct3 Code (Default)");

        $display("==================================================================================");
        $finish;
    end

endmodule
