`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 01:48:58
// Design Name: 
// Module Name: tb_AddressDecoder
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

module tb_AddressDecoder();

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    reg  [31:0] addr_i;
    reg         read_enable_i;
    reg         write_enable_i;
    reg  [3:0]  bw_i;

    wire [31:0] imem_addr_o;
    wire        imem_read_en_o;
    wire [31:0] dmem_addr_o;
    wire        dmem_read_en_o;
    wire        dmem_write_en_o;
    wire [3:0]  dmem_bw_o;
    wire        addr_decoder_sel;

    integer test_count  = 0;
    integer error_count = 0;

    // Instantiate Address Decoder
    AddressDecoder dut (
        .addr_i          (addr_i),
        .read_enable_i   (read_enable_i),
        .write_enable_i  (write_enable_i),
        .bw_i            (bw_i),
        .imem_addr_o     (imem_addr_o),
        .imem_read_en_o  (imem_read_en_o),
        .dmem_addr_o     (dmem_addr_o),
        .dmem_read_en_o  (dmem_read_en_o),
        .dmem_write_en_o (dmem_write_en_o),
        .dmem_bw_o       (dmem_bw_o),
        .addr_decoder_sel(addr_decoder_sel)
    );

    // -------------------------------------------------------------------------
    // Verification Helper Task
    // -------------------------------------------------------------------------
    task check_decode;
        input [128:0] test_name;
        input [31:0]  addr;
        input         rd_en;
        input         wr_en;
        input [3:0]   bw;
        input [31:0]  exp_imem_addr;
        input         exp_imem_rd;
        input [31:0]  exp_dmem_addr;
        input         exp_dmem_rd;
        input         exp_dmem_wr;
        input [3:0]   exp_dmem_bw;
        input         exp_sel;
        begin
            test_count     = test_count + 1;
            addr_i         = addr;
            read_enable_i  = rd_en;
            write_enable_i = wr_en;
            bw_i           = bw;
            #5; // Combinational delay check

            if (imem_addr_o      !== exp_imem_addr ||
                imem_read_en_o   !== exp_imem_rd   ||
                dmem_addr_o      !== exp_dmem_addr ||
                dmem_read_en_o   !== exp_dmem_rd   ||
                dmem_write_en_o  !== exp_dmem_wr   ||
                dmem_bw_o        !== exp_dmem_bw   ||
                addr_decoder_sel !== exp_sel) begin
                
                $display("[FAIL] %0s", test_name);
                $display("       Input  -> Addr: 0x%h, Rd: %b, Wr: %b, BW: %b", addr, rd_en, wr_en, bw);
                $display("       Exp Out-> IMEM Addr: 0x%h, Rd: %b | DMEM Addr: 0x%h, Rd: %b, Wr: %b, BW: %b | Sel: %b",
                         exp_imem_addr, exp_imem_rd, exp_dmem_addr, exp_dmem_rd, exp_dmem_wr, exp_dmem_bw, exp_sel);
                $display("       Got Out-> IMEM Addr: 0x%h, Rd: %b | DMEM Addr: 0x%h, Rd: %b, Wr: %b, BW: %b | Sel: %b",
                         imem_addr_o, imem_read_en_o, dmem_addr_o, dmem_read_en_o, dmem_write_en_o, dmem_bw_o, addr_decoder_sel);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s", test_name);
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Vectors
    // -------------------------------------------------------------------------
    initial begin
        $display("=========================================================================");
        $display("             STARTING ADDRESS DECODER RIGOROUS TESTBENCH                 ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // CATEGORY 1: IMEM Range (0x00400000 - 0x007FFFFF)
        // Expected: sel = 0, imem_offset = addr - 0x00400000, dmem signals = 0
        // ---------------------------------------------------------------------
        $display("\n--- 1. Instruction Memory (IMEM) Range Tests ---");
        //                      Name                         Addr        Rd Wr BW    IMEM_Addr   I_Rd  DMEM_Addr   D_Rd D_Wr D_BW    Sel
        check_decode("IMEM Base Address",            32'h00400000, 1, 0, 4'b0000, 32'h00000000,  1,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("IMEM Mid Address (Offset 0x100)",32'h00400100, 1, 0, 4'b0000, 32'h00000100,  1,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("IMEM Upper Boundary (4 MB)",   32'h007FFFFF, 1, 0, 4'b0000, 32'h003FFFFF,  1,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("IMEM Read Disabled Gating",    32'h00400004, 0, 0, 4'b0000, 32'h00000004,  0,  32'h00000000,  0,   0,  4'b0000,  0);

        // ---------------------------------------------------------------------
        // CATEGORY 2: DMEM Range (0x10010000 - 0x10011FFF)
        // Expected: sel = 1, dmem_offset = addr - 0x10010000, imem signals = 0
        // ---------------------------------------------------------------------
        $display("\n--- 2. Data Memory (DMEM) Range & Signal Forwarding Tests ---");
        //                      Name                         Addr        Rd Wr BW    IMEM_Addr   I_Rd  DMEM_Addr   D_Rd D_Wr D_BW    Sel
        check_decode("DMEM Base Address Load",       32'h10010000, 1, 0, 4'b0000, 32'h00000000,  0,  32'h00000000,  1,   0,  4'b0000,  1);
        check_decode("DMEM Store Word (SW)",         32'h10010004, 0, 1, 4'b1111, 32'h00000000,  0,  32'h00000004,  0,   1,  4'b1111,  1);
        check_decode("DMEM Store Byte Offset 2 (SB)",32'h1001000A, 0, 1, 4'b0100, 32'h00000000,  0,  32'h0000000A,  0,   1,  4'b0100,  1);
        check_decode("DMEM Max Boundary (8 kB)",     32'h10011FFF, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00001FFF,  1,   1,  4'b1111,  1);

        // ---------------------------------------------------------------------
        // CATEGORY 3: Out of Bounds & Boundary Transitions
        // Expected: All enables = 0, Offsets = 0, sel = 0
        // ---------------------------------------------------------------------
        $display("\n--- 3. Out-Of-Bounds & Boundary Safety Tests ---");
        //                      Name                         Addr        Rd Wr BW    IMEM_Addr   I_Rd  DMEM_Addr   D_Rd D_Wr D_BW    Sel
        check_decode("Just Below IMEM Range",        32'h003FFFFF, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("Just Above IMEM Range",        32'h00800000, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("Just Below DMEM Range",        32'h1000FFFF, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("Just Above DMEM Range",        32'h10012000, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("Zero Address",                 32'h00000000, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);
        check_decode("Max 32-bit Address",           32'hFFFFFFFF, 1, 1, 4'b1111, 32'h00000000,  0,  32'h00000000,  0,   0,  4'b0000,  0);

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("=========================================================================");
        $display("TEST RESULTS: Executed %0d Tests", test_count);
        if (error_count == 0) begin
            $display("STATUS: [ALL ADDRESS DECODER TESTS PASSED]");
        end else begin
            $display("STATUS: [FAILED %0d TESTS]", error_count);
        end
        $display("=========================================================================");
        $finish;
    end

endmodule
