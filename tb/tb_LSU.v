`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 16:54:12
// Design Name: 
// Module Name: tb_LSU
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



module tb_LSU();

    reg  [31:0] core_data_o;
    reg  [31:0] core_address_o;
    reg  [2:0]  op_size_o;
    wire [31:0] core_data_i;

    wire [31:0] mem_address_i;
    wire [31:0] mem_data_i;
    wire [3:0]  byte_write_i;
    reg  [31:0] mem_data_o;

    LSU uut (
        .core_data_o(core_data_o),
        .core_address_o(core_address_o),
        .op_size_o(op_size_o),
        .core_data_i(core_data_i),
        .mem_address_i(mem_address_i),
        .mem_data_i(mem_data_i),
        .byte_write_i(byte_write_i),
        .mem_data_o(mem_data_o)
    );

    localparam c_LW  = 3'b000, c_LH  = 3'b001, c_LB  = 3'b010;
    localparam c_LHU = 3'b011, c_LBU = 3'b100, c_SW  = 3'b101;
    localparam c_SH  = 3'b110, c_SB  = 3'b111;

    initial begin
        $display("--- Starting LSU Testbench ---");

        // Test 1: Store Word (SW)
        core_address_o = 32'h10010000; core_data_o = 32'hAABBCCDD; op_size_o = c_SW; #10;
        if (byte_write_i === 4'b1111 && mem_data_i === 32'hAABBCCDD)
            $display("[PASS] SW Aligned");
        else
            $display("[FAIL] SW Aligned: bw=%b, data=%h", byte_write_i, mem_data_i);

        // Test 2: Store Byte (SB) at Offset 2 (0x10010002) - Example from documentation
        core_address_o = 32'h10010002; core_data_o = 32'h00000012; op_size_o = c_SB; #10;
        if (byte_write_i === 4'b0100 && mem_data_i === 32'h00120000)
            $display("[PASS] SB Offset 2 (Correct Lane Shift)");
        else
            $display("[FAIL] SB Offset 2: bw=%b, data=%h", byte_write_i, mem_data_i);

        // Test 3: Load Byte Unsigned (LBU) at Offset 2 with data 0xF4F3F2F1
        mem_data_o = 32'hF4F3F2F1; core_address_o = 32'h10010002; op_size_o = c_LBU; #10;
        if (core_data_i === 32'h000000F3)
            $display("[PASS] LBU Offset 2");
        else
            $display("[FAIL] LBU Offset 2: core_data_i=%h", core_data_i);

        // Test 4: Load Byte Signed (LB) at Offset 0 with negative byte (0xF1)
        core_address_o = 32'h10010000; op_size_o = c_LB; #10;
        if (core_data_i === 32'hFFFFFFF1)
            $display("[PASS] LB Offset 0 (Sign Extended)");
        else
            $display("[FAIL] LB Offset 0: core_data_i=%h", core_data_i);

        // Test 5: Load Half-word Signed (LH) at Offset 2 (0xF4F3)
        core_address_o = 32'h10010002; op_size_o = c_LH; #10;
        if (core_data_i === 32'hFFFFF4F3)
            $display("[PASS] LH Offset 2 (Sign Extended)");
        else
            $display("[FAIL] LH Offset 2: core_data_i=%h", core_data_i);

        $display("--- Testbench Complete ---");
        $finish;
    end

endmodule
