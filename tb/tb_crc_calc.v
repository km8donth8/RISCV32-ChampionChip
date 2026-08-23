`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 20:31:07
// Design Name: 
// Module Name: tb_crc_calc
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

module tb_crc_calc();

    // Standard USB CRC-16 Parameters
    parameter [63:0]  POLY     = 64'h8005;
    parameter integer CRC_SIZE = 16;
    parameter integer REF_IN   = 1;
    parameter integer REF_OUT  = 1;
    parameter [63:0]  XOR_OUT  = 64'hFFFF;

    // 8-bit Width Signals
    reg  [15:0] crc_in_8;
    reg  [7:0]  data_8;
    wire [15:0] crc_o_8;

    // 16-bit Width Signals
    reg  [15:0] crc_in_16;
    reg  [15:0] data_16;
    wire [15:0] crc_o_16;

    // 32-bit Width Signals
    reg  [15:0] crc_in_32;
    reg  [31:0] data_32;
    wire [15:0] crc_o_32;

    integer error_count = 0;

    // --------------------------------------------------------
    // DUT Instantiations (Pure Combinational)
    // --------------------------------------------------------
    crc_calc #(
        .POLY(POLY), .CRC_SIZE(CRC_SIZE), .DATA_WIDTH(8),
        .REF_IN(REF_IN), .REF_OUT(REF_OUT), .XOR_OUT(XOR_OUT)
    ) dut_8bit (
        .crc_in(crc_in_8),
        .data_i(data_8),
        .crc_o(crc_o_8)
    );

    crc_calc #(
        .POLY(POLY), .CRC_SIZE(CRC_SIZE), .DATA_WIDTH(16),
        .REF_IN(REF_IN), .REF_OUT(REF_OUT), .XOR_OUT(XOR_OUT)
    ) dut_16bit (
        .crc_in(crc_in_16),
        .data_i(data_16),
        .crc_o(crc_o_16)
    );

    crc_calc #(
        .POLY(POLY), .CRC_SIZE(CRC_SIZE), .DATA_WIDTH(32),
        .REF_IN(REF_IN), .REF_OUT(REF_OUT), .XOR_OUT(XOR_OUT)
    ) dut_32bit (
        .crc_in(crc_in_32),
        .data_i(data_32),
        .crc_o(crc_o_32)
    );

    // --------------------------------------------------------
    // Validation Task
    // --------------------------------------------------------
    task check_crc(
        input [15:0] actual,
        input [15:0] expected,
        input [127:0] test_name
    );
        begin
            #1; // Propagation delay check
            if (actual !== expected) begin
                $display("[FAIL] %0s | Got: 0x%h, Expected: 0x%h", test_name, actual, expected);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Result: 0x%h", test_name, actual);
            end
        end
    endtask

    // --------------------------------------------------------
    // Main Stimulus
    // --------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("    STARTING ZERO-LATENCY CRC_CALC TESTBENCH      ");
        $display("==================================================");

        // --- TEST 1: 8-bit Data Width ('1' -> 0x31) ---
        crc_in_8 = 16'h0000;
        data_8   = 8'h31;
        #1;
        check_crc(crc_o_8, 16'h6B81, "8-bit  Input Payload '1' (0x31)      ");

        // --- TEST 2: 16-bit Data Width ("12" -> 0x3231) ---
        crc_in_16 = 16'h0000;
        data_16   = 16'h3231;
        #1;
        check_crc(crc_o_16, 16'h0A6A, "16-bit Input Payload '12' (0x3231)  ");

        // --- TEST 3: 32-bit Data Width ("1234" -> 0x34333231) ---
        crc_in_32 = 16'h0000;
        data_32   = 32'h3433_3231;
        #1;
        check_crc(crc_o_32, 16'hCF45, "32-bit Input Payload '1234'         ");

        // --- TEST 4: Zero-Latency 16-bit Dynamic Chaining ---
        // Step 1: Send "12" (0x3231) with seed 0x0000
        crc_in_16 = 16'h0000;
        data_16   = 16'h3231;
        #1;
        // Step 2: Feed output directly into seed with "34" (0x3433)
        crc_in_16 = crc_o_16; // 0x0A6A
        data_16   = 16'h3433;
        #1;
        check_crc(crc_o_16, 16'hCF45, "16-bit Chained '12' -> '34' ('1234') ");

        $display("==================================================");
        if (error_count == 0) begin
            $display("   ALL CRC_CALC TESTS PASSED! (0 Errors)");
        end else begin
            $display("   TESTBENCH FAILED WITH %0d ERROR(S)", error_count);
        end
        $display("==================================================");
        $finish;
    end

endmodule