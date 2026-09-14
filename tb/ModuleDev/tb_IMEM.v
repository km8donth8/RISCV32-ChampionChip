`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:30:19
// Design Name: 
// Module Name: tb_IMEM
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


module tb_IMEM();

    reg         clk;
    reg  [31:0] imem_addr;
    reg         read_enable;
    wire [31:0] imem_output;

    integer test_count  = 0;
    integer error_count = 0;

    // Instantiate IMEM
    IMEM dut (
        .clk        (clk),
        .imem_addr  (imem_addr),
        .read_enable(read_enable),
        .imem_output(imem_output)
    );

    // Clock generator
    always #5 clk = ~clk;

    // Self-checking verification task
    task check_imem;
        input [31:0]  rel_addr;       // Relative byte address (addr - 0x00400000)
        input         rd_en;
        input [31:0]  exp_output;
        input [128:0] desc;
        begin
            test_count  = test_count + 1;
            imem_addr   = rel_addr;
            read_enable = rd_en;
            #10; // Wait for combinational read output

            if (imem_output !== exp_output) begin
                $display("[FAIL] %0s | Addr Offset: 0x%h", desc, rel_addr);
                $display("       Expected: 0x%h, Got: 0x%h", exp_output, imem_output);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Addr Offset: 0x%h -> Data: 0x%h", desc, rel_addr, imem_output);
            end
        end
    endtask

    initial begin
        clk = 0;
        imem_addr = 0;
        read_enable = 0;

        $display("=========================================================================");
        $display("                   STARTING IMEM FIRMWARE TESTBENCH                      ");
        $display("=========================================================================");

        // 1. Test Sequential Instruction Fetching from Firmware Base (0x00400000)
        $display("\n--- 1. Testing Instruction Fetch (Base Program) ---");
        check_imem(32'h00000000, 1'b1, 32'h100100b7, "Fetch Inst 0 (lui x1)");
        check_imem(32'h00000004, 1'b1, 32'hdeadb137, "Fetch Inst 1 (lui x2)");
        check_imem(32'h00000008, 1'b1, 32'heef10113, "Fetch Inst 2 (addi x2)");
        check_imem(32'h0000000C, 1'b1, 32'h0020a023, "Fetch Inst 3 (sw x2)");
        check_imem(32'h00000010, 1'b1, 32'h00209223, "Fetch Inst 4 (sh x2)");
        check_imem(32'h00000014, 1'b1, 32'h00208323, "Fetch Inst 5 (sb x2)");
        check_imem(32'h00000018, 1'b1, 32'h0000a183, "Fetch Inst 6 (lw x3)");
        check_imem(32'h0000001C, 1'b1, 32'h0060c203, "Fetch Inst 7 (lbu x4)");
        check_imem(32'h00000020, 1'b1, 32'h004002b7, "Fetch Inst 8 (lui x5)");
        check_imem(32'h00000024, 1'b1, 32'h1002a303, "Fetch Inst 9 (lw x6)");
        check_imem(32'h00000028, 1'b1, 32'h0000006f, "Fetch Inst 10 (jal loop)");

        // 2. Test Sparse Address Data Fetch (Table 14 Constant at 0x00400100)
        $display("\n--- 2. Testing Sparse Memory Constant (@00000040 Offset) ---");
        check_imem(32'h00000100, 1'b1, 32'h0000000A, "Fetch Constant at Offset 0x100");

        // 3. Test Control Gating (Read Enable = 0)
        $display("\n--- 3. Testing Read Enable Gating ---");
        check_imem(32'h00000000, 1'b0, 32'h00000000, "Read Disabled Output Check");

        // Summary
        $display("=========================================================================");
        $display("TEST RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL FIRMWARE INSTRUCTIONS LOADED & READ SUCCESSFULLY]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS - Check firmware.hex file path]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule
