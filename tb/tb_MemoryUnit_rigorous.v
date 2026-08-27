`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 02:20:59
// Design Name: 
// Module Name: tb_MemoryUnit_rigorous
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

module tb_MemoryUnit_rigorous();

    // -------------------------------------------------------------------------
    // Signals & Constants
    // -------------------------------------------------------------------------
    reg        clk;
    reg        write_enable;
    reg        read_enable;
    reg  [2:0] op_size_o;
    reg  [31:0] core_data_o;
    reg  [31:0] core_address_o;
    wire [31:0] core_data_i;

    integer test_count  = 0;
    integer error_count = 0;

    // Custom Opcode Encoding Matching User LSU Specification
    localparam OP_LW  = 3'b000;
    localparam OP_LH  = 3'b001;
    localparam OP_LB  = 3'b010;
    localparam OP_LHU = 3'b011;
    localparam OP_LBU = 3'b100;
    localparam OP_SW  = 3'b101;
    localparam OP_SH  = 3'b110;
    localparam OP_SB  = 3'b111;

    // Memory Boundaries
    localparam IMEM_BASE = 32'h00400000;
    localparam IMEM_HIGH = 32'h007FFFFC;
    localparam DMEM_BASE = 32'h10010000;
    localparam DMEM_HIGH = 32'h10011FFC; // Max word-aligned address

    // Instantiate Top Unit
    MemoryUnit dut (
        .clk           (clk),
        .write_enable  (write_enable),
        .read_enable   (read_enable),
        .op_size_o     (op_size_o),
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .core_data_i   (core_data_i)
    );

    // Clock Generation (10ns Period)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Core Verification Tasks
    // -------------------------------------------------------------------------
    task memory_write;
        input [31:0] addr;
        input [31:0] data;
        input [2:0]  size;
        begin
            @(posedge clk);
            core_address_o = addr;
            core_data_o    = data;
            op_size_o      = size;
            write_enable   = 1'b1;
            read_enable    = 1'b0;
            @(posedge clk);
            #1;
            write_enable   = 1'b0;
        end
    endtask

    task memory_read_check;
        input [31:0]  addr;
        input [2:0]   size;
        input [31:0]  exp_data;
        input [255:0] test_name;
        begin
            test_count     = test_count + 1;
            @(posedge clk);
            core_address_o = addr;
            op_size_o      = size;
            read_enable    = 1'b1;
            write_enable   = 1'b0;
            
            @(posedge clk);
            #1;

            if (core_data_i !== exp_data) begin
                $display("[FAIL] %0s | Addr: 0x%h, Op: %b", test_name, addr, size);
                $display("       Expected: 0x%h | Got: 0x%h", exp_data, core_data_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Addr: 0x%h -> 0x%h", test_name, addr, core_data_i);
            end
            read_enable = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Suite
    // -------------------------------------------------------------------------
    integer i;
    reg [31:0] rand_addr;
    reg [31:0] rand_val;

    initial begin
        clk            = 0;
        write_enable   = 0;
        read_enable    = 0;
        op_size_o      = 3'b000;
        core_data_o    = 32'h0;
        core_address_o = 32'h0;

        #10;

        $display("=========================================================================");
        $display("          STARTING RIGOROUS TOP-LEVEL MEMORY UNIT TESTBENCH              ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 1: Exhaustive Byte Alignment Matrix (Offsets 0, 1, 2, 3)
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 1: Exhaustive Byte Lane & Sign/Zero Extension Matrix ---");
        
        // Offset 0 (Sign bit 1 vs 0)
        memory_write(32'h10010010, 32'h00000080, OP_SB);
        memory_read_check(32'h10010010, OP_LB,  32'hFFFFFF80, "Byte Offset 0: LB Sign Extension");
        memory_read_check(32'h10010010, OP_LBU, 32'h00000080, "Byte Offset 0: LBU Zero Extension");

        // Offset 1
        memory_write(32'h10010011, 32'h0000007F, OP_SB);
        memory_read_check(32'h10010011, OP_LB,  32'h0000007F, "Byte Offset 1: LB Positive Sign");
        memory_read_check(32'h10010011, OP_LBU, 32'h0000007F, "Byte Offset 1: LBU Positive Sign");

        // Offset 2
        memory_write(32'h10010012, 32'h000000FE, OP_SB);
        memory_read_check(32'h10010012, OP_LB,  32'hFFFFFFFE, "Byte Offset 2: LB Sign Extension");
        memory_read_check(32'h10010012, OP_LBU, 32'h000000FE, "Byte Offset 2: LBU Zero Extension");

        // Offset 3
        memory_write(32'h10010013, 32'h00000041, OP_SB);
        memory_read_check(32'h10010013, OP_LB,  32'h00000041, "Byte Offset 3: LB Positive Sign");
        memory_read_check(32'h10010013, OP_LBU, 32'h00000041, "Byte Offset 3: LBU Positive Sign");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 2: Half-Word Alignment Matrix (Offsets 0 and 2)
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 2: Half-Word Lane & Extension Matrix ---");
        
        // Lower Half (Offset 0)
        memory_write(32'h10010020, 32'h00009ABC, OP_SH);
        memory_read_check(32'h10010020, OP_LH,  32'hFFFF9ABC, "Half-word Offset 0: LH Sign Extension");
        memory_read_check(32'h10010020, OP_LHU, 32'h00009ABC, "Half-word Offset 0: LHU Zero Extension");

        // Upper Half (Offset 2)
        memory_write(32'h10010022, 32'h00003456, OP_SH);
        memory_read_check(32'h10010022, OP_LH,  32'h00003456, "Half-word Offset 2: LH Positive Sign");
        memory_read_check(32'h10010022, OP_LHU, 32'h00003456, "Half-word Offset 2: LHU Zero Extension");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 3: Partial Word Overwrites (Read-Modify-Write Integrity)
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 3: Sub-word Partial Overwrite Verification ---");
        
        // Step A: Write full word
        memory_write(32'h10010030, 32'h12345678, OP_SW);
        memory_read_check(32'h10010030, OP_LW, 32'h12345678, "Initial SW Setup Word");

        // Step B: Overwrite Byte Lane 1 with 0xFF
        memory_write(32'h10010031, 32'h000000FF, OP_SB);
        memory_read_check(32'h10010030, OP_LW, 32'h1234FF78, "Verify Byte 1 Modification (SW read)");

        // Step C: Overwrite Upper Half-Word (Bytes 2 and 3) with 0xAABB
        memory_write(32'h10010032, 32'h0000AABB, OP_SH);
        memory_read_check(32'h10010030, OP_LW, 32'hAABBFF78, "Verify Upper Half Modification (SW read)");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 4: Address Range Limits & Boundaries
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 4: Memory Address Boundaries & Range Limits ---");
        
        // IMEM Base and Upper Limit
        memory_read_check(IMEM_BASE, OP_LW, 32'h100100b7, "IMEM Base Address Access");
        memory_read_check(IMEM_HIGH, OP_LW, 32'h00000000, "IMEM Upper Boundary Access");

        // DMEM Upper Limit Word Write/Read
        memory_write(DMEM_HIGH, 32'hA5A55A5A, OP_SW);
        memory_read_check(DMEM_HIGH, OP_LW, 32'hA5A55A5A, "DMEM Upper Limit Word Check");

        // DMEM Boundary Byte Access at maximum address 0x10011FFF
        memory_write(32'h10011FFF, 32'h000000C3, OP_SB);
        memory_read_check(32'h10011FFF, OP_LBU, 32'h000000C3, "DMEM Max Byte Address (0x10011FFF)");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 5: Interleaved Access (Ping-Pong Switching)
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 5: Interleaved IMEM/DMEM Access (MUX Stability) ---");
        
        memory_read_check(32'h00400000, OP_LW, 32'h100100b7, "IMEM Read 1");
        memory_write(32'h10010040, 32'h87654321, OP_SW);
        memory_read_check(32'h10010040, OP_LW, 32'h87654321, "DMEM Read Interleaved");
        memory_read_check(32'h00400004, OP_LW, 32'hdeadb137, "IMEM Read 2 Interleaved");
        memory_read_check(32'h10010040, OP_LW, 32'h87654321, "DMEM Re-read Stability");

        // ---------------------------------------------------------------------
        // TEST CATEGORY 6: Pseudo-Random Stress Loop
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 6: Pseudo-Random Stress Operations ---");
        
        for (i = 0; i < 20; i = i + 1) begin
            // Generate random word address within DMEM range (word-aligned)
            rand_addr = DMEM_BASE + (($urandom % 512) * 4);
            rand_val  = $urandom;

            memory_write(rand_addr, rand_val, OP_SW);
            memory_read_check(rand_addr, OP_LW, rand_val, "Randomized SW/LW Stress Pass");
        end

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("\n=========================================================================");
        $display("FINAL VERIFICATION RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL RIGOROUS MEMORY UNIT TESTS PASSED]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule
