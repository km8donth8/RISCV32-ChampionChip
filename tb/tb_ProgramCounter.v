`timescale 1ns / 1ps

module testbench;

    // Inputs
    reg  [31:0] i_ALU_output;
    reg         PC_sel;
    reg         clk;
    reg         PC_write;
    reg         rst_n;

    // Outputs
    wire [31:0] o_PC_Output;
    wire [31:0] o_PC_Plus_4;

    // Instantiate Unit Under Test (UUT)
    ProgramCounter uut (
        .i_ALU_output(i_ALU_output),
        .PC_sel(PC_sel),
        .clk(clk),
        .PC_write(PC_write),
        .rst_n(rst_n),
        .o_PC_Output(o_PC_Output),
        .o_PC_Plus_4(o_PC_Plus_4)
    );

    // Clock generation: 100MHz (10ns period)
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize Inputs
        clk          = 0;
        rst_n        = 0;
        PC_write     = 0;
        PC_sel       = 0;
        i_ALU_output = 32'h0040_1000;

        // 2. Apply Reset
        #12;
        rst_n = 1; // De-assert reset (sync with clock)
        $display("[%0t ns] Reset released. PC = 0x%h (Expected: 0x00400000)", $time, o_PC_Output);

        // 3. Normal Incrementing (PC_write = 1)
        #10;
        PC_write = 1;
        #10; // Clock edge updates PC to PC+4
        $display("[%0t ns] Normal Step 1: PC = 0x%h (Expected: 0x00400004)", $time, o_PC_Output);

        #10; // Clock edge updates PC to PC+8
        $display("[%0t ns] Normal Step 2: PC = 0x%h (Expected: 0x00400008)", $time, o_PC_Output);

        // 4. TEST HOLD / STALL BEHAVIOR (PC_write = 0)
        #2; // Change signal mid-cycle
        PC_write = 0;
        i_ALU_output = 32'hDEAD_BEEF; // Change inputs while stalled to verify immunity

        #10; // Rising edge 1 during stall
        if (o_PC_Output == 32'h0040_0008) 
            $display("[%0t ns] PASS: PC Held at 0x%h on Clock Edge 1", $time, o_PC_Output);
        else 
            $display("[%0t ns] FAIL: PC changed to 0x%h during stall!", $time, o_PC_Output);

        #10; // Rising edge 2 during stall
        if (o_PC_Output == 32'h0040_0008) 
            $display("[%0t ns] PASS: PC Held at 0x%h on Clock Edge 2", $time, o_PC_Output);
        else 
            $display("[%0t ns] FAIL: PC changed to 0x%h during stall!", $time, o_PC_Output);

        // 5. Resume Operation & Branch/Jump Test
        #2;
        PC_write = 1;
        PC_sel   = 1; // Take ALU output target

        #10; // Clock edge loads target
        $display("[%0t ns] Jump Taken: PC = 0x%h (Expected: 0xDEADBEEF)", $time, o_PC_Output);

        // 6. Test Hold after Jump
        #2;
        PC_write = 0;
        #10;
        if (o_PC_Output == 32'hDEAD_BEEF) 
            $display("[%0t ns] PASS: PC Held at target 0x%h", $time, o_PC_Output);
        else 
            $display("[%0t ns] FAIL: PC failed to hold target!", $time, o_PC_Output);

        #20;
        $display("\n--- Testbench Complete ---");
        $finish;
    end

endmodule
