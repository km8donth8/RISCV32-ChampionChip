`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:37:19
// Design Name: 
// Module Name: tb_DMEM
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


module tb_DMEM();

    reg        clk;
    reg [31:0] dmem_addr;
    reg [31:0] dmem_data_i;
    reg [3:0]  bw;
    reg        write_enable;
    reg        read_enable;
    wire [31:0] dmem_output;

    integer test_count  = 0;
    integer error_count = 0;

    // Instantiate Data Memory
    DMEM #(
        .WORDS(2048)
    ) dut (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (dmem_data_i),
        .bw          (bw),
        .write_enable(write_enable),
        .read_enable (read_enable),
        .dmem_output (dmem_output)
    );

    // Clock generator (10 ns period)
    always #5 clk = ~clk;

    // Task: Perform a Synchronous Write
    task write_mem;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  byte_mask;
        input        w_en;
        begin
            dmem_addr    = addr;
            dmem_data_i  = data;
            bw           = byte_mask;
            write_enable = w_en;
            @(posedge clk); #1; // Trigger clock edge and hold briefly
            write_enable = 1'b0;
            bw           = 4'b0000;
        end
    endtask

    // Task: Perform a Read Verification
    task check_read;
        input [31:0]  addr;
        input         rd_en;
        input [31:0]  exp_data;
        input [128:0] test_name;
        begin
            test_count  = test_count + 1;
            dmem_addr   = addr;
            read_enable = rd_en;
            #2; // Combinational read delay check

            if (dmem_output !== exp_data) begin
                $display("[FAIL] %0s | Addr Offset: 0x%h", test_name, addr);
                $display("       Expected: 0x%h, Got: 0x%h", exp_data, dmem_output);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Addr Offset: 0x%h -> Data: 0x%h", test_name, addr, dmem_output);
            end
        end
    endtask

    initial begin
        clk          = 0;
        dmem_addr    = 0;
        dmem_data_i  = 0;
        bw           = 0;
        write_enable = 0;
        read_enable  = 0;

        $display("=========================================================================");
        $display("                  STARTING DMEM RIGOROUS TESTBENCH                       ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // TEST 1: Full Word Write & Read (SW)
        // ---------------------------------------------------------------------
        $display("\n--- 1. Full Word Store / Load (SW / LW) ---");
        write_mem(32'h00000000, 32'hDEADBEEF, 4'b1111, 1'b1);
        check_read(32'h00000000, 1'b1, 32'hDEADBEEF, "SW at Word Index 0");

        // ---------------------------------------------------------------------
        // TEST 2: Individual Byte-Lane Writes into Single Word Index (SB)
        // ---------------------------------------------------------------------
        $display("\n--- 2. Individual Byte-Lane Writes (SB) ---");
        // Target: Word Index 1 (Offset 0x0004)
        write_mem(32'h00000004, 32'h00000011, 4'b0001, 1'b1); // Write Byte 0
        write_mem(32'h00000004, 32'h00002200, 4'b0010, 1'b1); // Write Byte 1
        write_mem(32'h00000004, 32'h00330000, 4'b0100, 1'b1); // Write Byte 2
        write_mem(32'h00000004, 32'h44000000, 4'b1000, 1'b1); // Write Byte 3

        check_read(32'h00000004, 1'b1, 32'h44332211, "Merged Word Read (4 Byte Writes)");

        // ---------------------------------------------------------------------
        // TEST 3: Half-Word Writes (SH)
        // ---------------------------------------------------------------------
        $display("\n--- 3. Half-Word Writes (SH) ---");
        // Target: Word Index 2 (Offset 0x0008)
        write_mem(32'h00000008, 32'h0000AABB, 4'b0011, 1'b1); // Write Lower Half
        write_mem(32'h00000008, 32'hCCDD0000, 4'b1100, 1'b1); // Write Upper Half

        check_read(32'h00000008, 1'b1, 32'hCCDDAABB, "Merged Word Read (2 Half-Word Writes)");

        // ---------------------------------------------------------------------
        // TEST 4: Boundary Addresses (Min and Max Index)
        // ---------------------------------------------------------------------
        $display("\n--- 4. Memory Boundary Checks ---");
        // Max index for 8 kB = 2047 (Byte Address Offset = 2047 * 4 = 0x00001FCF / 0x1FFC)
        write_mem(32'h00001FFC, 32'hA5A55A5A, 4'b1111, 1'b1);
        check_read(32'h00001FFC, 1'b1, 32'hA5A55A5A, "Max Address Word Read (Index 2047)");

        // ---------------------------------------------------------------------
        // TEST 5: Write Enable Gating Check (write_enable = 0)
        // ---------------------------------------------------------------------
        $display("\n--- 5. Write Enable Gating Check ---");
        // Attempt to overwrite Index 0 with write_enable = 0
        write_mem(32'h00000000, 32'hBAADF00D, 4'b1111, 1'b0);
        check_read(32'h00000000, 1'b1, 32'hDEADBEEF, "Verify Data Unchanged when write_enable=0");

        // ---------------------------------------------------------------------
        // TEST 6: Read Enable Gating Check (read_enable = 0)
        // ---------------------------------------------------------------------
        $display("\n--- 6. Read Enable Gating Check ---");
        check_read(32'h00000000, 1'b0, 32'h00000000, "Output Zeroed when read_enable=0");

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("=========================================================================");
        $display("TEST RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL DMEM TESTS PASSED SUCCESSFULLY]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule
