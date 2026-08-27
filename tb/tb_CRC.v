`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 20:06:58
// Design Name: 
// Module Name: tb_CRC
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


// module tb_CRC();

//     // --------------------------------------------------------
//     // Testbench Signals
//     // --------------------------------------------------------
//     reg  [31:0] reg_rs_1;
//     reg  [15:0] reg_rs_2;
//     reg  [1:0]  crc_sel;
//     wire [31:0] rd;

//     integer error_count = 0;

//     // --------------------------------------------------------
//     // Instantiate Unit Under Test (UUT)
//     // --------------------------------------------------------
//     CRC uut (
//         .reg_rs_1(reg_rs_1),
//         .reg_rs_2(reg_rs_2),
//         .crc_sel(crc_sel),
//         .rd(rd)
//     );

//     // --------------------------------------------------------
//     // Verification Task
//     // --------------------------------------------------------
//     task check_rd(
//         input [31:0] expected_rd,
//         input [127:0] test_name
//     );
//         begin
//             #1; // Delay for combinational propagation
//             if (rd !== expected_rd) begin
//                 $display("[FAIL] %0s | Got: 0x%h, Expected: 0x%h", test_name, rd, expected_rd);
//                 error_count = error_count + 1;
//             end else begin
//                 $display("[PASS] %0s | Result: 0x%h", test_name, rd);
//             end
//         end
//     endtask

//     // --------------------------------------------------------
//     // Main Test Sequence
//     // --------------------------------------------------------
//     initial begin
//         $display("==================================================");
//         $display("       STARTING TOP-LEVEL CRC WRAPPER TEST        ");
//         $display("==================================================");

//         // Initialize inputs
//         reg_rs_1 = 32'h0000_0000;
//         reg_rs_2 = 16'hFFFF;
//         crc_sel  = 2'b00;

//         // --- TEST 1: 8-bit Mode (crc_sel = 2'b00) ---
//         // Payload: 8'h31 ('1'), Seed: 0x0000 -> Expected: 0x00006B81
//         reg_rs_1 = 32'h0000_0031;
//         reg_rs_2 = 16'hFFFF;
//         crc_sel  = 2'b00;
//         #1;
//         check_rd(32'h0000_6B81, "8-bit Mode  (crc_sel = 00) Payload '1'  ");

//         // --- TEST 2: 16-bit Mode (crc_sel = 2'b01) ---
//         // Payload: 16'h3231 ("12"), Seed: 0x0000 -> Expected: 0x00000A6A
//         reg_rs_1 = 32'h0000_3231;
//         reg_rs_2 = 16'hFFFF;
//         crc_sel  = 2'b01;
//         #1;
//         check_rd(32'h0000_0A6A, "16-bit Mode (crc_sel = 01) Payload '12' ");

//         // --- TEST 3: 32-bit Mode (crc_sel = 2'b10) ---
//         // Payload: 32'h3433_3231 ("1234"), Seed: 0x0000 -> Expected: 0x0000CF45
//         reg_rs_1 = 32'h3433_3231;
//         reg_rs_2 = 16'hFFFF;
//         crc_sel  = 2'b10;
//         #1;
//         check_rd(32'h0000_CF45, "32-bit Mode (crc_sel = 10) Payload '1234'");

       
//         // --- TEST 4: Invalid Selector Fallback ---
//         crc_sel  = 2'b11;
//         #1;
//         check_rd(32'h0000_0000, "Undefined Opcode Fallback");

//         $display("==================================================");
//         if (error_count == 0) begin
//             $display("ALL TOP-LEVEL CRC TESTS PASSED! (0 Errors)");
//         end else begin
//             $display("TESTBENCH FAILED WITH %0d ERROR(S)", error_count);
//         end
//         $display("==================================================");
//         $finish;
//     end

// endmodule


module tb_CRC();

    // --------------------------------------------------------
    // Testbench Signals
    // --------------------------------------------------------
    reg  [31:0] reg_rs_1;
    reg  [31:0] reg_rs_2;
    reg  [1:0]  crc_sel;
    wire [31:0] rd;

    integer error_count = 0;

    // --------------------------------------------------------
    // Instantiate Unit Under Test (UUT)
    // --------------------------------------------------------
    CRC uut (
        .reg_rs_1(reg_rs_1),
        .reg_rs_2(reg_rs_2),
        .crc_sel(crc_sel),
        .rd(rd)
    );

    // --------------------------------------------------------
    // Verification Task
    // --------------------------------------------------------
    task check_rd(
        input [31:0] expected_rd,
        input [127:0] test_name
    );
        begin
            #1; // Delay for combinational propagation
            if (rd !== expected_rd) begin
                $display("[FAIL] %0s | Got: 0x%h, Expected: 0x%h", test_name, rd, expected_rd);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Result: 0x%h", test_name, rd);
            end
        end
    endtask

    // --------------------------------------------------------
    // Main Test Sequence
    // --------------------------------------------------------
    initial begin
        $display("==================================================");
        $display("       STARTING TOP-LEVEL CRC WRAPPER TEST        ");
        $display("==================================================");

        // Initialize inputs
        reg_rs_1 = 32'h0000_0000;
        reg_rs_2 = 32'h1234_FFFF; // Upper 16 bits set to 1234 to verify ignore
        crc_sel  = 2'b00;

        // --- TEST 1: 8-bit Mode (crc_sel = 2'b00) ---
        // Payload: 8'h31 ('1'), Seed: 0xFFFF -> Expected: 0x00006B81
        reg_rs_1 = 32'h0000_0031;
        reg_rs_2 = 32'hABCD_FFFF;
        crc_sel  = 2'b00;
        #1;
        check_rd(32'h0000_6B81, "8-bit Mode  (crc_sel = 00) Payload '1'  ");

        // --- TEST 2: 16-bit Mode (crc_sel = 2'b01) ---
        // Payload: 16'h3231 ("12"), Seed: 0xFFFF -> Expected: 0x00000A6A
        reg_rs_1 = 32'h0000_3231;
        reg_rs_2 = 32'h0000_FFFF;
        crc_sel  = 2'b01;
        #1;
        check_rd(32'h0000_0A6A, "16-bit Mode (crc_sel = 01) Payload '12' ");

        // --- TEST 3: 32-bit Mode (crc_sel = 2'b10) ---
        // Payload: 32'h3433_3231 ("1234"), Seed: 0xFFFF -> Expected: 0x0000CF45
        reg_rs_1 = 32'h3433_3231;
        reg_rs_2 = 32'hFFFF_FFFF;
        crc_sel  = 2'b10;
        #1;
        check_rd(32'h0000_CF45, "32-bit Mode (crc_sel = 10) Payload '1234'");

        // --- TEST 4: Invalid Selector Fallback ---
        crc_sel  = 2'b11;
        #1;
        check_rd(32'h0000_0000, "Undefined Opcode Fallback");

        $display("==================================================");
        if (error_count == 0) begin
            $display("ALL TOP-LEVEL CRC TESTS PASSED! (0 Errors)");
        end else begin
            $display("TESTBENCH FAILED WITH %0d ERROR(S)", error_count);
        end
        $display("==================================================");
        $finish;
    end

endmodule