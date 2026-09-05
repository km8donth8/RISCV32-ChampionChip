`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.09.2026 11:06:58
// Design Name: 
// Module Name: tb_MemoryUnit_rigorous_mixed_latency
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



module tb_MemoryUnit_rigorous_mixed_latency();

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

    // Custom Opcode Encoding
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
    localparam UNMAPPED  = 32'h20000000;

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

    // Clock Generation (10ns Period / 100MHz)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Core Verification Tasks
    // -------------------------------------------------------------------------
    
    // DMEM Write Task (Synchronous)
    task dmem_write;
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

    // DMEM Read Task (Synchronous - 1 Cycle Latency)
    task dmem_read_check;
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
            
            // Wait 1 clock edge for synchronous DMEM memory read
            @(posedge clk);
            #1;

            if (core_data_i !== exp_data) begin
                $display("[FAIL - DMEM Sync] %0s | Addr: 0x%h, Op: %b", test_name, addr, size);
                $display("       Expected: 0x%h | Got: 0x%h", exp_data, core_data_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS - DMEM Sync] %0s | Addr: 0x%h -> 0x%h", test_name, addr, core_data_i);
            end
            read_enable = 1'b0;
        end
    endtask

    // IMEM Read Task (Asynchronous - 0 Cycle Latency / Combinational)
    task imem_read_check;
        input [31:0]  addr;
        input [2:0]   size;
        input [31:0]  exp_data;
        input [255:0] test_name;
        begin
            test_count     = test_count + 1;
            core_address_o = addr;
            op_size_o      = size;
            read_enable    = 1'b1;
            write_enable   = 1'b0;
            
            // Small delta delay for combinational propagation
            #1;

            if (core_data_i !== exp_data) begin
                $display("[FAIL - IMEM Async] %0s | Addr: 0x%h, Op: %b", test_name, addr, size);
                $display("        Expected: 0x%h | Got: 0x%h", exp_data, core_data_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS - IMEM Async] %0s | Addr: 0x%h -> 0x%h", test_name, addr, core_data_i);
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
        $dumpfile("tb_MemoryUnit_mixed.vcd");
        $dumpvars(0, tb_MemoryUnit_rigorous_mixed_latency);

        clk            = 0;
        write_enable   = 0;
        read_enable    = 0;
        op_size_o      = 3'b000;
        core_data_o    = 32'h0;
        core_address_o = 32'h0;

        #20;

        $display("=========================================================================");
        $display("   STARTING MIXED LATENCY (ASYNC IMEM / SYNC DMEM) MEMORY TESTBENCH      ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // CATEGORY 1: DMEM Exhaustive Byte Lane & Sign/Zero Extension
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 1: DMEM Byte Alignment & Sign/Zero Extension ---");
        
        // Offset 0
        dmem_write(32'h10010010, 32'h00000080, OP_SB);
        dmem_read_check(32'h10010010, OP_LB,  32'hFFFFFF80, "Byte Offset 0: LB Sign Extension");
        dmem_read_check(32'h10010010, OP_LBU, 32'h00000080, "Byte Offset 0: LBU Zero Extension");

        // Offset 1
        dmem_write(32'h10010011, 32'h0000007F, OP_SB);
        dmem_read_check(32'h10010011, OP_LB,  32'h0000007F, "Byte Offset 1: LB Positive Sign");
        dmem_read_check(32'h10010011, OP_LBU, 32'h0000007F, "Byte Offset 1: LBU Positive Sign");

        // Offset 2
        dmem_write(32'h10010012, 32'h000000FE, OP_SB);
        dmem_read_check(32'h10010012, OP_LB,  32'hFFFFFFFE, "Byte Offset 2: LB Sign Extension");
        dmem_read_check(32'h10010012, OP_LBU, 32'h000000FE, "Byte Offset 2: LBU Zero Extension");

        // Offset 3
        dmem_write(32'h10010013, 32'h00000041, OP_SB);
        dmem_read_check(32'h10010013, OP_LB,  32'h00000041, "Byte Offset 3: LB Positive Sign");
        dmem_read_check(32'h10010013, OP_LBU, 32'h00000041, "Byte Offset 3: LBU Positive Sign");

        // ---------------------------------------------------------------------
        // CATEGORY 2: DMEM Half-Word Alignment Matrix
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 2: DMEM Half-Word Lane & Extension Matrix ---");
        
        // Lower Half
        dmem_write(32'h10010020, 32'h00009ABC, OP_SH);
        dmem_read_check(32'h10010020, OP_LH,  32'hFFFF9ABC, "Half-word Offset 0: LH Sign Extension");
        dmem_read_check(32'h10010020, OP_LHU, 32'h00009ABC, "Half-word Offset 0: LHU Zero Extension");

        // Upper Half
        dmem_write(32'h10010022, 32'h00003456, OP_SH);
        dmem_read_check(32'h10010022, OP_LH,  32'h00003456, "Half-word Offset 2: LH Positive Sign");
        dmem_read_check(32'h10010022, OP_LHU, 32'h00003456, "Half-word Offset 2: LHU Zero Extension");

        // ---------------------------------------------------------------------
        // CATEGORY 3: Asynchronous IMEM Direct Access Test
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 3: Asynchronous IMEM Combinational Reads ---");
        
        // Immediate zero-cycle read checks
        imem_read_check(IMEM_BASE, OP_LW, 32'h100100b7, "IMEM Base Address (0-cycle execution)");
        imem_read_check(IMEM_BASE + 32'h4, OP_LW, 32'hdeadb137, "IMEM Offset +4 (0-cycle execution)");
        imem_read_check(IMEM_HIGH, OP_LW, 32'h00000000, "IMEM Upper Boundary Access");

        // Intra-cycle dynamic change test (Simulating asynchronous PC update without waiting for clk)
        core_address_o = IMEM_BASE;
        op_size_o      = OP_LW;
        read_enable    = 1'b1;
        #2;
        if (core_data_i === 32'h100100b7) 
            $display("[PASS - IMEM Dynamic] Immediate combinational decode verified at IMEM_BASE");
        else begin
            $display("[FAIL - IMEM Dynamic] Expected 0x100100b7, got 0x%h", core_data_i);
            error_count = error_count + 1;
        end

        // Change address in same cycle
        core_address_o = IMEM_BASE + 32'h4;
        #2;
        if (core_data_i === 32'hdeadb137) 
            $display("[PASS - IMEM Dynamic] Immediate combinational decode verified at IMEM_BASE+4");
        else begin
            $display("[FAIL - IMEM Dynamic] Expected 0xdeadb137, got 0x%h", core_data_i);
            error_count = error_count + 1;
        end
        read_enable = 1'b0;

        // ---------------------------------------------------------------------
        // CATEGORY 4: Interleaved IMEM (Async) and DMEM (Sync) Access
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 4: Interleaved Async IMEM & Sync DMEM MUX Stability ---");
        
        // 1. Async Read IMEM
        imem_read_check(IMEM_BASE, OP_LW, 32'h100100b7, "Step 1: Read Async IMEM");

        // 2. Synchronous Write then Read to DMEM
        dmem_write(32'h10010040, 32'h87654321, OP_SW);
        dmem_read_check(32'h10010040, OP_LW, 32'h87654321, "Step 2: Read Sync DMEM");

        // 3. Immediately switch back to IMEM (Async)
        imem_read_check(IMEM_BASE + 32'h4, OP_LW, 32'hdeadb137, "Step 3: Switch back to Async IMEM");

        // 4. Read back DMEM
        dmem_read_check(32'h10010040, OP_LW, 32'h87654321, "Step 4: Re-read Sync DMEM");

        // ---------------------------------------------------------------------
        // CATEGORY 5: DMEM Boundary & Unmapped Memory Operations
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 5: DMEM Boundary & Unmapped Operations ---");

        dmem_write(DMEM_HIGH, 32'hA5A55A5A, OP_SW);
        dmem_read_check(DMEM_HIGH, OP_LW, 32'hA5A55A5A, "DMEM Upper Limit Word Check");

        dmem_write(32'h10011FFF, 32'h000000C3, OP_SB);
        dmem_read_check(32'h10011FFF, OP_LBU, 32'h000000C3, "DMEM Max Byte Address (0x10011FFF)");

        dmem_read_check(UNMAPPED, OP_LW, 32'h00000000, "Unmapped Address Read Zero Check");

        // ---------------------------------------------------------------------
        // CATEGORY 6: Pseudo-Random DMEM Stress Loop
        // ---------------------------------------------------------------------
        $display("\n--- CATEGORY 6: Pseudo-Random Stress Operations on DMEM ---");
        
        for (i = 0; i < 20; i = i + 1) begin
            rand_addr = DMEM_BASE + (($urandom % 512) * 4);
            rand_val  = $urandom;

            dmem_write(rand_addr, rand_val, OP_SW);
            dmem_read_check(rand_addr, OP_LW, rand_val, "Randomized SW/LW Stress Pass");
        end

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("\n=========================================================================");
        $display("FINAL VERIFICATION RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL MIXED-LATENCY MEMORY UNIT TESTS PASSED]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule