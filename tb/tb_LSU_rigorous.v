`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.08.2026 23:26:46
// Design Name: 
// Module Name: tb_LSU_rigorous
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


module tb_LSU_rigorous();

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    reg  [31:0] core_data_o;
    reg  [31:0] core_address_o;
    reg  [2:0]  op_size_o;
    wire [31:0] core_data_i;

    wire [31:0] mem_address_i;
    wire [31:0] mem_data_i;
    wire [3:0]  byte_write_i;
    reg  [31:0] mem_data_o;

    // Testbench tracking variables
    integer test_count  = 0;
    integer error_count = 0;

    // Opcode localparams matching the LSU
    localparam c_LW  = 3'b000;
    localparam c_LH  = 3'b001;
    localparam c_LB  = 3'b010;
    localparam c_LHU = 3'b011;
    localparam c_LBU = 3'b100;
    localparam c_SW  = 3'b101;
    localparam c_SH  = 3'b110;
    localparam c_SB  = 3'b111;

    // Instantiate Load/Store Unit
    LSU dut (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),
        .mem_address_i (mem_address_i),
        .mem_data_i    (mem_data_i),
        .byte_write_i  (byte_write_i),
        .mem_data_o    (mem_data_o)
    );

    // -------------------------------------------------------------------------
    // Helper Tasks for Self-Checking
    // -------------------------------------------------------------------------
    
    // Task to verify STORE operations
    task check_store;
        input [128:0] test_name;
        input [31:0]  addr;
        input [31:0]  data_from_core;
        input [2:0]   op;
        input [3:0]   exp_byte_write;
        input [31:0]  exp_mem_data;
        begin
            test_count     = test_count + 1;
            core_address_o = addr;
            core_data_o    = data_from_core;
            op_size_o      = op;
            mem_data_o     = 32'h00000000; // Irrelevant for stores
            #10;

            if (byte_write_i !== exp_byte_write || mem_data_i !== exp_mem_data || mem_address_i !== addr) begin
                $display("[FAIL] %0s", test_name);
                $display("       Addr: %h | Op: %b", addr, op);
                $display("       Expected -> bw: %b, mem_data: %h, mem_addr: %h", exp_byte_write, exp_mem_data, addr);
                $display("       Got      -> bw: %b, mem_data: %h, mem_addr: %h", byte_write_i, mem_data_i, mem_address_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s", test_name);
            end
        end
    endtask

    // Task to verify LOAD operations (and check that byte_write_i remains 0000)
    task check_load;
        input [128:0] test_name;
        input [31:0]  addr;
        input [31:0]  mem_word_in;
        input [2:0]   op;
        input [31:0]  exp_core_data;
        begin
            test_count     = test_count + 1;
            core_address_o = addr;
            core_data_o    = 32'hDEADBEEF; // Irrelevant for loads
            op_size_o      = op;
            mem_data_o     = mem_word_in;
            #10;

            if (core_data_i !== exp_core_data || byte_write_i !== 4'b0000 || mem_address_i !== addr) begin
                $display("[FAIL] %0s", test_name);
                $display("       Addr: %h | Op: %b | Mem Input: %h", addr, op, mem_word_in);
                $display("       Expected -> core_data: %h, bw: 0000", exp_core_data);
                $display("       Got      -> core_data: %h, bw: %b", core_data_i, byte_write_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s", test_name);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Execution Block
    // -------------------------------------------------------------------------
    initial begin
        $display("=========================================================================");
        $display("                  STARTING RIGOROUS LSU TESTBENCH                        ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // CATEGORY 1: STORE BYTE (SB) Across All 4 Byte Lanes
        // ---------------------------------------------------------------------
        $display("\n--- 1. Store Byte (SB) Tests ---");
        check_store("SB Offset 0", 32'h10010000, 32'h112233A5, c_SB, 4'b0001, 32'h000000A5);
        check_store("SB Offset 1", 32'h10010001, 32'h112233A5, c_SB, 4'b0010, 32'h0000A500);
        check_store("SB Offset 2", 32'h10010002, 32'h112233A5, c_SB, 4'b0100, 32'h00A50000);
        check_store("SB Offset 3", 32'h10010003, 32'h112233A5, c_SB, 4'b1000, 32'hA5000000);

        // ---------------------------------------------------------------------
        // CATEGORY 2: STORE HALF-WORD (SH) Across Upper and Lower Halves
        // ---------------------------------------------------------------------
        $display("\n--- 2. Store Half-word (SH) Tests ---");
        check_store("SH Offset 0", 32'h10010000, 32'hABCD8001, c_SH, 4'b0011, 32'h00008001);
        check_store("SH Offset 2", 32'h10010002, 32'hABCD8001, c_SH, 4'b1100, 32'h80010000);

        // ---------------------------------------------------------------------
        // CATEGORY 3: STORE WORD (SW)
        // ---------------------------------------------------------------------
        $display("\n--- 3. Store Word (SW) Tests ---");
        check_store("SW Full Word", 32'h10010004, 32'hDEADBEEF, c_SW, 4'b1111, 32'hDEADBEEF);

        // ---------------------------------------------------------------------
        // CATEGORY 4: LOAD BYTE SIGNED (LB) - Sign Extension Verification
        // Test memory word: 0x807FFE81 (Byte 3: 0x80, Byte 2: 0x7F, Byte 1: 0xFE, Byte 0: 0x81)
        // ---------------------------------------------------------------------
        $display("\n--- 4. Load Byte Signed (LB) Tests ---");
        check_load("LB Offset 0 (0x81 -> Negative Sign Ext)", 32'h10010000, 32'h807FFE81, c_LB, 32'hFFFFFF81);
        check_load("LB Offset 1 (0xFE -> Negative Sign Ext)", 32'h10010001, 32'h807FFE81, c_LB, 32'hFFFFFFFE); // 0xFE -> 0xFFFFFFFE
        check_load("LB Offset 2 (0x7F -> Positive Sign Ext)", 32'h10010002, 32'h807FFE81, c_LB, 32'h0000007F);
        check_load("LB Offset 3 (0x80 -> Negative Sign Ext)", 32'h10010003, 32'h807FFE81, c_LB, 32'hFFFFFF80);

        // ---------------------------------------------------------------------
        // CATEGORY 5: LOAD BYTE UNSIGNED (LBU) - Zero Extension Verification
        // ---------------------------------------------------------------------
        $display("\n--- 5. Load Byte Unsigned (LBU) Tests ---");
        check_load("LBU Offset 0 (0x81 -> Zero Ext)", 32'h10010000, 32'h807FFE81, c_LBU, 32'h00000081);
        check_load("LBU Offset 1 (0xFE -> Zero Ext)", 32'h10010001, 32'h807FFE81, c_LBU, 32'h000000FE);
        check_load("LBU Offset 2 (0x7F -> Zero Ext)", 32'h10010002, 32'h807FFE81, c_LBU, 32'h0000007F);
        check_load("LBU Offset 3 (0x80 -> Zero Ext)", 32'h10010003, 32'h807FFE81, c_LBU, 32'h00000080);

        // ---------------------------------------------------------------------
        // CATEGORY 6: LOAD HALF-WORD SIGNED & UNSIGNED (LH / LHU)
        // Test memory word: 0x80017FFF (Upper Half: 0x8001, Lower Half: 0x7FFF)
        // ---------------------------------------------------------------------
        $display("\n--- 6. Load Half-word (LH / LHU) Tests ---");
        check_load("LH Offset 0 (0x7FFF -> Pos Sign Ext)", 32'h10010000, 32'h80017FFF, c_LH,  32'h00007FFF);
        check_load("LH Offset 2 (0x8001 -> Neg Sign Ext)", 32'h10010002, 32'h80017FFF, c_LH,  32'hFFFF8001);
        check_load("LHU Offset 0 (0x7FFF -> Zero Ext)",    32'h10010000, 32'h80017FFF, c_LHU, 32'h00007FFF);
        check_load("LHU Offset 2 (0x8001 -> Zero Ext)",    32'h10010002, 32'h80017FFF, c_LHU, 32'h00008001);

        // ---------------------------------------------------------------------
        // CATEGORY 7: LOAD WORD & IMEM CONSTANT FETCHING
        // ---------------------------------------------------------------------
        $display("\n--- 7. Load Word (LW) & IMEM Boundary Tests ---");
        check_load("LW DMEM Address", 32'h10010000, 32'h12345678, c_LW, 32'h12345678);
        check_load("LW IMEM Address", 32'h00400100, 32'h0000000A, c_LW, 32'h0000000A); // Constant reading

        // ---------------------------------------------------------------------
        // CATEGORY 8: CORNER CASES (All 1s, All 0s, Boundary Sign Bit)
        // ---------------------------------------------------------------------
        $display("\n--- 8. Extreme Corner Cases ---");
        check_load("LB All Bits 1",    32'h10010000, 32'hFFFFFFFF, c_LB, 32'hFFFFFFFF);
        check_load("LBU All Bits 1",   32'h10010000, 32'hFFFFFFFF, c_LBU, 32'h000000FF);
        check_load("LH Boundary 0x8000",32'h10010000, 32'h00008000, c_LH, 32'hFFFF8000);
        check_store("SB Data All 1s",  32'h10010003, 32'hFFFFFFFF, c_SB, 4'b1000, 32'hFF000000);

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("=========================================================================");
        $display("TEST RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL TESTS PASSED SUCCESSFULLY]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule
