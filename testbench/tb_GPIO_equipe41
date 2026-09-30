`timescale 1ns/1ps
// ============================================================================
// Self-checking testbench for GPIO_equipe41
//
// Register map (word offsets):  0 = DATAOUT (R/W)   1 = DATAIN (R only)
//                               2 = DATADIR (R/W)   others reserved
//
//  T1  reset state
//  T2  DATAOUT / DATADIR write + readback, gpio_out masking, gpio_oe
//  T3  DATAIN: reads only pins configured as inputs
//  T4  2-flip-flop synchroniser latency (exactly 2 clock cycles)
//  T5  DATAIN is read-only
//  T6  reserved offsets, upper wdata bits, sel_i = 0 are all harmless
//  T7  walking-one on DATADIR
//  T8  changing direction releases / re-drives the pins
//  T9  asynchronous reset
//
// The pins are modelled as real bidirectional pads: when gpio_oe = 1 the pad
// is driven by the DUT, otherwise by the testbench (ext_drv).
//
// Run:  iverilog -g2012 -o sim_gpio tb_GPIO_equipe41.v GPIO_equipe41.v
//       vvp sim_gpio          (optional: gtkwave tb_GPIO_equipe41.vcd)
// ============================================================================
module tb_GPIO_equipe41;


    localparam [31:0] A_DATAOUT = 32'h0000_0000;
    localparam [31:0] A_DATAIN  = 32'h0000_0004;
    localparam [31:0] A_DATADIR = 32'h0000_0008;


    reg         clk = 1'b0;
    reg         rst_n;
    reg         sel, we;
    reg  [31:0] addr, wdata;
    wire [31:0] rdata;
    reg  [7:0]  ext_drv;                 // what the outside world drives
    wire [7:0]  gpio_out, gpio_oe;
    wire [7:0]  pad = (gpio_oe & gpio_out) | (~gpio_oe & ext_drv);


    GPIO_equipe41 dut (
        .clk(clk), .rst_n(rst_n),
        .sel_i(sel), .we_i(we), .addr_i(addr), .wdata_i(wdata), .rdata_o(rdata),
        .gpio_in(pad), .gpio_out(gpio_out), .gpio_oe(gpio_oe)
    );


    always #5 clk = ~clk;                // 100 MHz


    // ------------------------------------------------------------------
    integer errors = 0;
    integer checks = 0;


    task check_eq(input [31:0] got, input [31:0] exp, input [8*56-1:0] msg);
        begin
            checks = checks + 1;
            if (got === exp)
                $display("  [PASS] %0s (= 0x%0h)", msg, got);
            else begin
                errors = errors + 1;
                $display("  [FAIL] %0s : got 0x%0h, expected 0x%0h  (t=%0t)", msg, got, exp, $time);
            end
        end
    endtask


    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b1; addr = a; wdata = d;
            @(negedge clk);
            sel = 1'b0; we = 1'b0; addr = 32'h0; wdata = 32'h0;
        end
    endtask


    task bus_read(input [31:0] a, output [31:0] d);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b0; addr = a;
            #1 d = rdata;
            sel = 1'b0; addr = 32'h0;
        end
    endtask


    // ------------------------------------------------------------------
    reg [31:0] r;
    integer    i;


    initial begin
        $dumpfile("tb_GPIO_equipe41.vcd");
        $dumpvars(0, tb_GPIO_equipe41);
        $display("=== GPIO_equipe41 testbench ===");


        sel = 0; we = 0; addr = 0; wdata = 0; ext_drv = 8'h00;
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);


        // ---------------- T1 ----------------
        $display("\n-- T1: reset state --");
        bus_read(A_DATAOUT, r); check_eq(r, 32'h0, "DATAOUT = 0");
        bus_read(A_DATAIN,  r); check_eq(r, 32'h0, "DATAIN  = 0");
        bus_read(A_DATADIR, r); check_eq(r, 32'h0, "DATADIR = 0 (all pins are inputs)");
        check_eq(gpio_oe,  8'h00, "gpio_oe  = 0x00 (outputs disabled)");
        check_eq(gpio_out, 8'h00, "gpio_out = 0x00");


        // ---------------- T2 ----------------
        $display("\n-- T2: DATAOUT / DATADIR --");
        bus_write(A_DATAOUT, 32'hA5);
        bus_read(A_DATAOUT, r);
        check_eq(r, 32'h0000_00A5, "DATAOUT readback = 0xA5");
        check_eq(gpio_out, 8'h00, "gpio_out still 0: all pins are inputs");
        check_eq(gpio_oe,  8'h00, "gpio_oe  still 0");


        bus_write(A_DATADIR, 32'h0F);
        bus_read(A_DATADIR, r);
        check_eq(r, 32'h0000_000F, "DATADIR readback = 0x0F");
        check_eq(gpio_oe,  8'h0F, "gpio_oe = DATADIR = 0x0F");
        check_eq(gpio_out, 8'h05, "gpio_out = 0xA5 & 0x0F = 0x05");
        check_eq(pad[3:0], 4'h5, "pad low nibble driven by the GPIO block");


        // ---------------- T3 ----------------
        $display("\n-- T3: DATAIN only shows input pins (DATADIR=0x0F) --");
        ext_drv = 8'hFF;
        repeat (3) @(posedge clk);
        check_eq(pad, 8'hF5, "pad = ext on [7:4], DUT output on [3:0]");
        bus_read(A_DATAIN, r);
        check_eq(r, 32'h0000_00F0, "DATAIN = 0xF0 (output pins read as 0)");
        ext_drv = 8'h30;
        repeat (3) @(posedge clk);
        bus_read(A_DATAIN, r);
        check_eq(r, 32'h0000_0030, "DATAIN follows ext pins: 0x30");


        // ---------------- T4 ----------------
        $display("\n-- T4: synchroniser latency --");
        bus_write(A_DATADIR, 32'h00);              // all inputs
        ext_drv = 8'h00;
        repeat (4) @(posedge clk);
        @(negedge clk);
        sel = 1'b1; we = 1'b0; addr = A_DATAIN;    // keep reading DATAIN
        ext_drv = 8'hFF;                           // change asynchronously
        @(posedge clk); #1;
        check_eq(rdata, 32'h00, "1 clock after the pin change: still old value");
        @(posedge clk); #1;
        check_eq(rdata, 32'hFF, "2 clocks after the pin change: new value visible");
        @(negedge clk);
        sel = 1'b0; addr = 32'h0;


        // ---------------- T5 ----------------
        $display("\n-- T5: DATAIN is read-only --");
        bus_write(A_DATADIR, 32'h0F);
        bus_write(A_DATAOUT, 32'h05);
        ext_drv = 8'h00;
        repeat (3) @(posedge clk);
        bus_write(A_DATAIN, 32'hFF);               // must be ignored
        repeat (2) @(posedge clk);
        bus_read(A_DATAIN,  r); check_eq(r, 32'h00, "DATAIN unchanged after write");
        bus_read(A_DATAOUT, r); check_eq(r, 32'h05, "DATAOUT unchanged");
        bus_read(A_DATADIR, r); check_eq(r, 32'h0F, "DATADIR unchanged");


        // ---------------- T6 ----------------
        $display("\n-- T6: reserved offsets / upper bits / sel_i=0 --");
        bus_write(32'h0000_000C, 32'hFF);
        bus_write(32'h0000_0100, 32'hFF);
        bus_read(A_DATAOUT, r); check_eq(r, 32'h05, "DATAOUT unchanged by reserved writes");
        bus_read(A_DATADIR, r); check_eq(r, 32'h0F, "DATADIR unchanged by reserved writes");
        bus_read(32'h0000_000C, r); check_eq(r, 32'h0, "reserved offset 0x00C reads 0");
        bus_read(32'h0000_0100, r); check_eq(r, 32'h0, "reserved offset 0x100 reads 0");


        bus_write(A_DATAOUT, 32'hFFFF_FF12);
        bus_read(A_DATAOUT, r);
        check_eq(r, 32'h0000_0012, "upper wdata bits ignored, upper rdata bits = 0");


        // write with sel_i = 0 must do nothing, read with sel_i = 0 returns 0
        @(negedge clk);
        sel = 1'b0; we = 1'b1; addr = A_DATAOUT; wdata = 32'hFF;
        #1 check_eq(rdata, 32'h0, "rdata = 0 when sel_i = 0");
        @(negedge clk);
        we = 1'b0; wdata = 32'h0;
        bus_read(A_DATAOUT, r);
        check_eq(r, 32'h0000_0012, "write with sel_i=0 had no effect");


        // ---------------- T7 ----------------
        $display("\n-- T7: walking one on DATADIR (DATAOUT = 0xFF) --");
        bus_write(A_DATAOUT, 32'hFF);
        for (i = 0; i < 8; i = i + 1) begin
            bus_write(A_DATADIR, 32'h1 << i);
            check_eq(gpio_oe,  8'h01 << i, "gpio_oe  = one-hot");
            check_eq(gpio_out, 8'h01 << i, "gpio_out = one-hot");
        end


        // ---------------- T8 ----------------
        $display("\n-- T8: direction change releases / re-drives pins --");
        bus_write(A_DATADIR, 32'hFF);
        check_eq(gpio_out, 8'hFF, "all outputs: gpio_out = DATAOUT = 0xFF");
        bus_write(A_DATADIR, 32'h00);
        check_eq(gpio_oe,  8'h00, "all inputs: gpio_oe = 0");
        check_eq(gpio_out, 8'h00, "all inputs: gpio_out forced to 0");
        bus_read(A_DATAOUT, r);
        check_eq(r, 32'hFF, "DATAOUT register still remembers 0xFF");
        bus_write(A_DATADIR, 32'h80);
        check_eq(gpio_out, 8'h80, "pin 7 re-driven with stored value");


        // ---------------- T9 ----------------
        $display("\n-- T9: asynchronous reset --");
        #2 rst_n = 1'b0;
        #1;
        check_eq(gpio_oe,  8'h00, "gpio_oe cleared immediately by rst_n");
        check_eq(gpio_out, 8'h00, "gpio_out cleared");
        #10 rst_n = 1'b1;
        bus_read(A_DATAOUT, r); check_eq(r, 32'h0, "DATAOUT = 0 after reset");
        bus_read(A_DATADIR, r); check_eq(r, 32'h0, "DATADIR = 0 after reset");


        // ---------------- summary ----------------
        $display("\n==================================================");
        if (errors == 0)
            $display(" ALL TESTS PASSED  (%0d checks, 0 errors)", checks);
        else
            $display(" TEST FAILED      (%0d errors out of %0d checks)", errors, checks);
        $display("==================================================");
        $finish;
    end


    initial begin
        #100000;
        $display("[FAIL] watchdog timeout");
        $finish;
    end


endmodule
