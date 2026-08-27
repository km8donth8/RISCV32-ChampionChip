`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.08.2026 15:43:22
// Design Name: 
// Module Name: tb_ImmediateGenerator
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


module tb_ImmediateGenerator;

    reg [31:0] instruction;
    wire [31:0] extended_immediate;

    ImmediateGenerator uut (
        .instruction(instruction),
        .extended_immediate(extended_immediate)
    );

    task check_result(input [31:0] expected, input [160:1] test_label);
        begin
            #5;
            if (extended_immediate === expected) begin
                $display("[PASS] %-30s | Output: 0x%h", test_label, extended_immediate);
            end else begin
                $display("[FAIL] %-30s | Expected: 0x%h, Got: 0x%h", test_label, expected, extended_immediate);
            end
        end
    endtask

    initial begin
        $display("==================================================");
        $display("       Testing RISC-V Immediate Generator         ");
        $display("==================================================");

        // 1. I-Type Test: ADDI x1, x2, -20 (Imm = -20 / 12'hFEC)
        instruction = 32'hFEC10093;
        check_result(32'hFFFFFFEC, "I-Type (ADDI negative)");

        // 2. S-Type Test: SW x2, -4(x1) (Imm = -4 / 12'hFFC) -> FIXED HEX
        instruction = 32'hFE20AE23;
        check_result(32'hFFFFFFFC, "S-Type (SW negative offset)");

        // 3. B-Type Test: BEQ x1, x2, -16 (Imm = -16 / 13'h1FF0)
        instruction = 32'hFE2088E3;
        check_result(32'hFFFFFFF0, "B-Type (BEQ negative offset)");

        // 4. U-Type Test: LUI x1, 0x12345 (Imm = 0x12345000)
        instruction = 32'h123450B7;
        check_result(32'h12345000, "U-Type (LUI upper immediate)");

        // 5. J-Type Test: JAL x1, -20 (Imm = -20 / 21'h1FFFEC) -> FIXED HEX
        instruction = 32'hFEDFF0EF;
        check_result(32'hFFFFFFEC, "J-Type (JAL negative target)");

        $display("==================================================");
        $finish;
    end

endmodule