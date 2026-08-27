`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.08.2026 15:11:13
// Design Name: 
// Module Name: tb_RegisterFile
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

module tb_RegisterFile;

    // Parameters
    localparam DATA_MEM_SIZE = 8192; // 8 KB

    // Testbench Signals
    reg         clk;
    reg         rst_n;
    reg         reg_write;
    reg  [31:0] reg_rd_data;
    reg  [31:0] instruction;
    wire [31:0] reg_rs_1_data;
    wire [31:0] reg_rs_2_data;

    // Instantiate Unit Under Test (UUT)
    RegisterFile #(
        .DATA_MEM_SIZE(DATA_MEM_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(reg_write),
        .reg_rd_data(reg_rd_data),
        .instruction(instruction),
        .reg_rs_1_data(reg_rs_1_data),
        .reg_rs_2_data(reg_rs_2_data)
    );

    // Clock Generation (100 MHz, 10ns period)
    always #5 clk = ~clk;

    // Task to construct standard RISC-V instruction fields cleanly
    task set_instruction;
        input [4:0] rs1;
        input [4:0] rs2;
        input [4:0] rd;
        begin
            instruction = 32'h0;
            instruction[19:15] = rs1;
            instruction[24:20] = rs2;
            instruction[11:7]  = rd;
        end
    endtask

    // Main Test Sequence
    initial begin
        // Signal Initialization
        clk = 0;
        rst_n = 0;
        reg_write = 0;
        reg_rd_data = 32'h0;
        instruction = 32'h0;

        // ----------------------------------------------------------------
        // Test 1: Assert Reset & Validate SP / GP / x0 Initialization
        // ----------------------------------------------------------------
        #20;
        rst_n = 1; // Release Reset cleanly
        #10;

        // Check x0 (rs1) and x2 / SP (rs2)
        set_instruction(5'd0, 5'd2, 5'd0); 
        #1;
        if (reg_rs_1_data !== 32'h0000_0000)
            $error("[FAIL] x0 initialization failed. Expected: 0x0, Got: 0x%h", reg_rs_1_data);
        if (reg_rs_2_data !== 32'h1001_1FFC) // 0x10010000 + 8192 - 4
            $error("[FAIL] SP (x2) reset failed. Expected: 0x10011FFC, Got: 0x%h", reg_rs_2_data);

        // Check x3 / GP (rs1) and general register x4 (rs2)
        set_instruction(5'd3, 5'd4, 5'd0); 
        #1;
        if (reg_rs_1_data !== 32'h1001_0000)
            $error("[FAIL] GP (x3) reset failed. Expected: 0x10010000, Got: 0x%h", reg_rs_1_data);
        if (reg_rs_2_data !== 32'h0000_0000)
            $error("[FAIL] x4 initialization failed. Expected: 0x0, Got: 0x%h", reg_rs_2_data);

        // ----------------------------------------------------------------
        // Test 2: Synchronous Write & Asynchronous Read (x5)
        // ----------------------------------------------------------------
        @(negedge clk);
        reg_write = 1'b1;
        reg_rd_data = 32'hDEAD_BEEF;
        set_instruction(5'd5, 5'd0, 5'd5); // Target rd = x5, Read rs1 = x5
        
        @(posedge clk); // Clock edge performs write
        #1;             // Allow asynchronous read output to update
        if (reg_rs_1_data !== 32'hDEAD_BEEF)
            $error("[FAIL] Register x5 write/read failed. Expected: 0xDEADBEEF, Got: 0x%h", reg_rs_1_data);

        // ----------------------------------------------------------------
        // Test 3: x0 Write Protection Test
        // ----------------------------------------------------------------
        @(negedge clk);
        reg_write = 1'b1;
        reg_rd_data = 32'hCAFE_BABE;
        set_instruction(5'd0, 5'd0, 5'd0); // Target rd = x0, Read rs1 = x0
        
        @(posedge clk); // Clock edge attempts write to x0
        #1;
        if (reg_rs_1_data !== 32'h0000_0000)
            $error("[FAIL] x0 protection failed! x0 modified to: 0x%h", reg_rs_1_data);

        // ----------------------------------------------------------------
        // Test 4: Dual Read Operations (Read x5 on rs1 and SP on rs2)
        // ----------------------------------------------------------------
        @(negedge clk);
        reg_write = 1'b0; // Disable write
        set_instruction(5'd5, 5'd2, 5'd0); // rs1 = x5, rs2 = x2
        #1;
        if (reg_rs_1_data !== 32'hDEAD_BEEF || reg_rs_2_data !== 32'h1001_1FFC)
            $error("[FAIL] Dual read failed. rs1: 0x%h, rs2: 0x%h", reg_rs_1_data, reg_rs_2_data);

        $display("\n==========================================");
        $display("   ALL REGISTER FILE TESTS PASSED OK      ");
        $display("==========================================\n");
        $finish;
    end

endmodule