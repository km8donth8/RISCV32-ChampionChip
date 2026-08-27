`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.08.2026 13:37:23
// Design Name: 
// Module Name: tb_ProgramCounter
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


module tb_ProgramCounter();

    // Testbench Signals
    reg         clk;
    reg         rst_n;
    reg         PC_sel;
    reg  [31:0] i_ALU_output;
    wire [31:0] o_PC_Output;
    wire [31:0] o_PC_Plus_4;

    // Instantiate the Unit Under Test (UUT)
    ProgramCounter uut (
        .i_ALU_output(i_ALU_output),
        .PC_sel(PC_sel),
        .clk(clk),
        .rst_n(rst_n),
        .o_PC_Output(o_PC_Output),
        .o_PC_Plus_4(o_PC_Plus_4)
    );

    // Clock Generation (10ns period -> 100MHz)
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize Signals
        clk          = 0;
        rst_n        = 0; // Assert reset initially
        PC_sel       = 0;
        i_ALU_output = 32'h0;

        $display("\n--- Starting Program Counter Testbench ---");

        // 2. Test Asynchronous Reset
        #12;
        if (o_PC_Output == 32'h0040_0000 && o_PC_Plus_4 == 32'h0040_0004)
            $display("[PASS] Reset State: PC = 0x%h, PC+4 = 0x%h", o_PC_Output, o_PC_Plus_4);
        else
            $display("[FAIL] Reset State: PC = 0x%h", o_PC_Output);

        // De-assert reset
        rst_n = 1;

        // 3. Test Sequential Incrementing (PC_sel = 0)
        repeat (3) @(posedge clk);
        #1; // Small offset for signals to settle after clock edge
        $display("[INFO] Sequential Count: PC = 0x%h, PC+4 = 0x%h", o_PC_Output, o_PC_Plus_4);

        // 4. Test Branch/Jump Target Loading (PC_sel = 1)
        @(negedge clk);
        i_ALU_output = 32'h0040_1000;
        PC_sel       = 1; // Select branch target

        @(posedge clk);
        #1;
        if (o_PC_Output == 32'h0040_1000)
            $display("[PASS] Jump Target Loaded: PC = 0x%h", o_PC_Output);
        else
            $display("[FAIL] Jump Target: Expected 0x00401000, Got 0x%h", o_PC_Output);

        // 5. Resume Sequential Execution from New Address (PC_sel = 0)
        @(negedge clk);
        PC_sel = 0;

        @(posedge clk);
        #1;
        if (o_PC_Output == 32'h0040_1004)
            $display("[PASS] Resumed Sequential Step: PC = 0x%h", o_PC_Output);
        else
            $display("[FAIL] Resumed Sequential: Expected 0x00401004, Got 0x%h", o_PC_Output);

        // 6. Test Mid-Execution Asynchronous Reset
        #3;
        rst_n = 0; // Force reset without waiting for clock edge
        #1;
        if (o_PC_Output == 32'h0040_0000)
            $display("[PASS] Async Mid-Execution Reset successful: PC = 0x%h", o_PC_Output);
        else
            $display("[FAIL] Async Reset failed");

        $display("--- Testbench Complete ---\n");
        $finish;
    end

endmodule
