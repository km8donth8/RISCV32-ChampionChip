`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 02:03:19
// Design Name: 
// Module Name: tb_MemoryUnit
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

module tb_MemoryUnit();

    reg        clk;
    reg        write_enable;
    reg        read_enable;
    reg  [2:0] op_size_o;
    reg  [31:0] core_data_o;
    reg  [31:0] core_address_o;
    wire [31:0] core_data_i;

    integer test_count  = 0;
    integer error_count = 0;

    // Matched directly to your LSU's custom localparam encoding
    localparam OP_LW  = 3'b000;
    localparam OP_LH  = 3'b001;
    localparam OP_LB  = 3'b010;
    localparam OP_LHU = 3'b011;
    localparam OP_LBU = 3'b100;
    localparam OP_SW  = 3'b101;
    localparam OP_SH  = 3'b110;
    localparam OP_SB  = 3'b111;

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
                $display("[FAIL] %0s | Addr: 0x%h, OpSize: %b", test_name, addr, size);
                $display("       Expected: 0x%h, Got: 0x%h", exp_data, core_data_i);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s | Addr: 0x%h -> Data: 0x%h", test_name, addr, core_data_i);
            end
            read_enable = 1'b0;
        end
    endtask

    initial begin
        clk            = 0;
        write_enable   = 0;
        read_enable    = 0;
        op_size_o      = 3'b000;
        core_data_o    = 32'h0;
        core_address_o = 32'h0;

        #10;

        $display("=========================================================================");
        $display("              STARTING TOP-LEVEL MEMORY UNIT TESTBENCH                   ");
        $display("=========================================================================");

        // 1. IMEM Reads
        $display("\n--- 1. Testing Instruction Memory Reads (IMEM Range) ---");
        memory_read_check(32'h00400000, OP_LW, 32'h100100b7, "Fetch IMEM Word 0 (lui x1)");
        memory_read_check(32'h00400004, OP_LW, 32'hdeadb137, "Fetch IMEM Word 1 (lui x2)");
        memory_read_check(32'h00400100, OP_LW, 32'h0000000A, "Fetch Constant at IMEM 0x00400100");

        // 2. DMEM Word Access
        $display("\n--- 2. Testing DMEM Word Store & Load (SW / LW) ---");
        memory_write(32'h10010000, 32'hCAFEBABE, OP_SW);
        memory_read_check(32'h10010000, OP_LW, 32'hCAFEBABE, "SW / LW Word Check");

        // 3. DMEM Half-Word Access
        $display("\n--- 3. Testing DMEM Half-Word Operations (SH / LH / LHU) ---");
        memory_write(32'h10010006, 32'h00008EEF, OP_SH);
        memory_read_check(32'h10010006, OP_LH,  32'hFFFF8EEF, "LH Signed Extension Check");
        memory_read_check(32'h10010006, OP_LHU, 32'h00008EEF, "LHU Zero Extension Check");

        // 4. DMEM Byte Access
        $display("\n--- 4. Testing DMEM Byte Operations (SB / LB / LBU) ---");
        memory_write(32'h1001000B, 32'h000000FE, OP_SB);
        memory_read_check(32'h1001000B, OP_LB,  32'hFFFFFFFE, "LB Signed Extension Check");
        memory_read_check(32'h1001000B, OP_LBU, 32'h000000FE, "LBU Zero Extension Check");

        // 5. Out-of-bounds Read Check
        $display("\n--- 5. Out-Of-Bounds Read Safety Check ---");
        memory_read_check(32'h20000000, OP_LW, 32'h00000000, "Unmapped Address Safety Read");

        $display("=========================================================================");
        $display("TEST RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL TOP-LEVEL MEMORY UNIT TESTS PASSED]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule