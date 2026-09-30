`timescale 1ns/1ps
// ============================================================================
// Self-checking testbench for UART_equipe41
//
//  T1  reset state
//  T2  register access (TXDATA readback, reserved offset reads 0)
//  T3  TX: 5 frames, checked by an independent monitor on tx_o
//      (start bit, 8 data bits LSB first, stop bit, txdone behaviour)
//  T4  TX: exact baud timing (0x00 frame => low for exactly 9 bit times)
//  T5  RX: frames driven on rx_i at nominal, -2% and +2% baud
//      (rxdone set, RXDATA correct, rxdone cleared by SW write of 0)
//  T6  RX: framing error (bad stop bit) -> byte dropped, then recovery
//  T7  RX: glitch on the line (shorter than half a bit) -> ignored
//  T8  Internal loopback tx_o -> rx_i (TX and RX working together)
//
// Run:  iverilog -g2012 -o sim_uart tb_UART_equipe41.v UART_equipe41.v
//       vvp sim_uart          (optional: gtkwave tb_UART_equipe41.vcd)
// ============================================================================
module tb_UART_equipe41;


    parameter integer CLK_FREQ_HZ = 50_000_000;
    parameter integer BAUD_RATE   = 115_200;


    localparam integer CLK_PERIOD   = 1_000_000_000 / CLK_FREQ_HZ;             // ns
    localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2) / BAUD_RATE;  // same as DUT
    localparam integer BIT_T        = CLKS_PER_BIT * CLK_PERIOD;                // ns per bit


    localparam [31:0] ADDR_TXDATA  = 32'h0000_0000;
    localparam [31:0] ADDR_RXDATA  = 32'h0000_0004;
    localparam [31:0] ADDR_CONTROL = 32'h0000_0008;
    localparam [31:0] ADDR_RESERVED= 32'h0000_000C;


    // ------------------------------------------------------------------
    // DUT hookup
    // ------------------------------------------------------------------
    reg         clk = 1'b0;
    reg         rst_n;
    reg         sel, we;
    reg  [31:0] addr, wdata;
    wire [31:0] rdata;
    wire        tx_o;
    reg         rx_drv;          // TB-driven serial line
    reg         loop_en;         // 1 => rx_i = tx_o
    wire        rx_i = loop_en ? tx_o : rx_drv;


    UART_equipe41 #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst_n(rst_n),
        .sel_i(sel), .we_i(we), .addr_i(addr), .wdata_i(wdata), .rdata_o(rdata),
        .rx_i(rx_i), .tx_o(tx_o)
    );


    always #(CLK_PERIOD/2) clk = ~clk;


    // ------------------------------------------------------------------
    // Pass / fail bookkeeping
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


    task check_true(input cond, input [8*56-1:0] msg);
        begin
            checks = checks + 1;
            if (cond)
                $display("  [PASS] %0s", msg);
            else begin
                errors = errors + 1;
                $display("  [FAIL] %0s  (t=%0t)", msg, $time);
            end
        end
    endtask


    // ------------------------------------------------------------------
    // Bus tasks (write is sampled at a posedge, read is combinational)
    // ------------------------------------------------------------------
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


    // poll CONTROL[bitn] until it equals v (or timeout)
    task wait_ctrl(input integer bitn, input v, input integer max_cycles, output ok);
        integer n;
        reg [31:0] r;
        begin
            ok = 1'b0; n = 0;
            while (!ok && n < max_cycles) begin
                bus_read(ADDR_CONTROL, r);
                if (r[bitn] === v) ok = 1'b1;
                else n = n + 1;
            end
        end
    endtask


    // ------------------------------------------------------------------
    // Independent TX monitor: decodes every frame seen on tx_o
    // (samples in the centre of each bit, like a real receiver)
    // ------------------------------------------------------------------
    reg [7:0] mon_byte;
    reg       mon_ok;
    integer   mon_count = 0;
    integer   mi;


    always @(negedge tx_o) begin
        if (rst_n === 1'b1) begin
            mon_ok = 1'b1;
            #(BIT_T/2);
            if (tx_o !== 1'b0) mon_ok = 1'b0;                 // start bit = 0
            for (mi = 0; mi < 8; mi = mi + 1) begin
                #(BIT_T);
                mon_byte[mi] = tx_o;                          // LSB first
            end
            #(BIT_T);
            if (tx_o !== 1'b1) mon_ok = 1'b0;                 // stop bit = 1
            mon_count = mon_count + 1;
        end
    end


    // measure the length of every low pulse on tx_o
    time t_fall = 0, t_rise = 0, last_low = 0;
    always @(negedge tx_o) t_fall = $time;
    always @(posedge tx_o) begin t_rise = $time; last_low = t_rise - t_fall; end


    // ------------------------------------------------------------------
    // Serial driver for the RX tests. bt = bit time in ns.
    // ------------------------------------------------------------------
    task send_serial(input [7:0] b, input stop_lvl, input integer bt);
        integer i;
        begin
            rx_drv = 1'b0;            #(bt);        // start
            for (i = 0; i < 8; i = i + 1) begin
                rx_drv = b[i];        #(bt);        // data, LSB first
            end
            rx_drv = stop_lvl;        #(bt);        // stop
            rx_drv = 1'b1;
        end
    endtask


    // ------------------------------------------------------------------
    // Higher-level tasks
    // ------------------------------------------------------------------
    task tx_byte(input [7:0] b);
        integer c0;
        reg ok;
        reg [31:0] r;
        begin
            c0 = mon_count;
            bus_write(ADDR_TXDATA, {24'h0, b});
            bus_write(ADDR_CONTROL, 32'h1);                   // TRANSMIT = 1
            repeat (4) @(posedge clk);
            bus_read(ADDR_CONTROL, r);
            check_eq(r[2], 1'b0, "txdone = 0 while frame is being sent");
            wait_ctrl(2, 1'b1, 20*CLKS_PER_BIT, ok);
            check_true(ok, "txdone returns to 1 at end of frame");
            check_true(mon_count == c0 + 1, "exactly one frame appeared on tx_o");
            check_eq(mon_byte, b, "byte decoded from tx_o");
            check_true(mon_ok, "start=0 / stop=1 framing correct");
        end
    endtask


    task rx_byte(input [7:0] b, input integer bt);
        reg [31:0] r;
        begin
            send_serial(b, 1'b1, bt);
            bus_read(ADDR_CONTROL, r);
            check_eq(r[1], 1'b1, "rxdone = 1 after frame received");
            bus_read(ADDR_RXDATA, r);
            check_eq(r, {24'h0, b}, "RXDATA holds received byte");
            bus_write(ADDR_CONTROL, 32'h0);                   // SW clears rxdone
            bus_read(ADDR_CONTROL, r);
            check_eq(r[1], 1'b0, "rxdone cleared by software write of 0");
            #(BIT_T);                                         // idle gap
        end
    endtask


    // ------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------
    reg [31:0] r, prev;
    reg        ok;
    integer    k;
    reg [7:0]  tx_list [0:4];
    reg [7:0]  lb_list [0:2];


    initial begin
        $dumpfile("tb_UART_equipe41.vcd");
        $dumpvars(0, tb_UART_equipe41);
        $display("=== UART_equipe41 testbench : CLKS_PER_BIT=%0d, bit=%0d ns ===", CLKS_PER_BIT, BIT_T);


        tx_list[0] = 8'hA5; tx_list[1] = 8'h3C; tx_list[2] = 8'h00;
        tx_list[3] = 8'hFF; tx_list[4] = 8'h55;
        lb_list[0] = 8'h96; lb_list[1] = 8'h0F; lb_list[2] = 8'hE1;


        sel = 0; we = 0; addr = 0; wdata = 0; rx_drv = 1'b1; loop_en = 1'b0;
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);


        // ---------------- T1 ----------------
        $display("\n-- T1: reset state --");
        check_eq(tx_o, 1'b1, "tx_o idles high");
        bus_read(ADDR_CONTROL, r);
        check_eq(r, 32'h0000_0004, "CONTROL = {txdone=1, rxdone=0, transmit=0}");
        bus_read(ADDR_RXDATA, r);
        check_eq(r, 32'h0, "RXDATA = 0");
        bus_read(ADDR_TXDATA, r);
        check_eq(r, 32'h0, "TXDATA = 0");


        // ---------------- T2 ----------------
        $display("\n-- T2: register access --");
        bus_write(ADDR_TXDATA, 32'hFFFF_F1A5);
        bus_read(ADDR_TXDATA, r);
        check_eq(r, 32'h0000_00A5, "TXDATA stores only wdata[7:0]");
        bus_write(ADDR_RESERVED, 32'hFFFF_FFFF);
        bus_read(ADDR_RESERVED, r);
        check_eq(r, 32'h0, "reserved offset reads 0");
        check_true(tx_o === 1'b1, "write to reserved offset does not start TX");


        // ---------------- T3 ----------------
        $display("\n-- T3: transmit frames --");
        for (k = 0; k < 5; k = k + 1) begin
            $display(" frame %0d: sending 0x%02h", k, tx_list[k]);
            tx_byte(tx_list[k]);
            if (tx_list[k] == 8'h00) begin
                // T4 piggy-backs on the 0x00 frame
                $display("\n-- T4: TX baud timing (from the 0x00 frame) --");
                check_eq(last_low, 9*BIT_T, "tx_o low for exactly 9 bit times (start+8 zeros)");
                $display("");
            end
        end


        // ---------------- T5 ----------------
        $display("\n-- T5: receive frames --");
        $display(" 0x5A at nominal baud");     rx_byte(8'h5A, BIT_T);
        $display(" 0xC3 at nominal baud");     rx_byte(8'hC3, BIT_T);
        $display(" 0x81 at -2%% baud error");  rx_byte(8'h81, BIT_T*98/100);
        $display(" 0x7E at +2%% baud error");  rx_byte(8'h7E, BIT_T*102/100);
        $display(" 0x00 at nominal baud");     rx_byte(8'h00, BIT_T);
        $display(" 0xFF at nominal baud");     rx_byte(8'hFF, BIT_T);


        // ---------------- T6 ----------------
        $display("\n-- T6: framing error (stop bit = 0) --");
        rx_byte(8'hC3, BIT_T);                                  // known RXDATA value
        bus_read(ADDR_RXDATA, prev);
        send_serial(8'h81, 1'b0, BIT_T);                        // bad stop bit
        #(2*BIT_T);
        bus_read(ADDR_CONTROL, r);
        check_eq(r[1], 1'b0, "rxdone stays 0 (frame rejected)");
        bus_read(ADDR_RXDATA, r);
        check_eq(r, prev, "RXDATA unchanged (byte dropped)");
        $display(" next good frame after the error (receiver must resync)");
        rx_byte(8'h7E, BIT_T);


        // ---------------- T7 ----------------
        $display("\n-- T7: glitch shorter than half a bit --");
        bus_read(ADDR_RXDATA, prev);
        rx_drv = 1'b0; #(BIT_T/4); rx_drv = 1'b1;
        #(3*BIT_T);
        bus_read(ADDR_CONTROL, r);
        check_eq(r[1], 1'b0, "rxdone stays 0 (glitch ignored)");
        bus_read(ADDR_RXDATA, r);
        check_eq(r, prev, "RXDATA unchanged");
        $display(" real frame right after the glitch");
        rx_byte(8'h3A, BIT_T);


        // ---------------- T8 ----------------
        $display("\n-- T8: internal loopback tx_o -> rx_i --");
        loop_en = 1'b1;
        #(2*CLK_PERIOD);
        for (k = 0; k < 3; k = k + 1) begin
            $display(" loopback of 0x%02h", lb_list[k]);
            bus_write(ADDR_TXDATA, {24'h0, lb_list[k]});
            bus_write(ADDR_CONTROL, 32'h1);
            wait_ctrl(1, 1'b1, 20*CLKS_PER_BIT, ok);
            check_true(ok, "rxdone raised by the looped-back frame");
            bus_read(ADDR_RXDATA, r);
            check_eq(r, {24'h0, lb_list[k]}, "RXDATA equals byte that was sent");
            bus_write(ADDR_CONTROL, 32'h0);
            wait_ctrl(2, 1'b1, 20*CLKS_PER_BIT, ok);
            check_true(ok, "txdone back to 1");
        end
        loop_en = 1'b0;


        // ---------------- summary ----------------
        $display("\n==================================================");
        if (errors == 0)
            $display(" ALL TESTS PASSED  (%0d checks, 0 errors)", checks);
        else
            $display(" TEST FAILED      (%0d errors out of %0d checks)", errors, checks);
        $display("==================================================");
        $finish;
    end


    // watchdog
    initial begin
        #(3000 * BIT_T);
        $display("[FAIL] watchdog timeout");
        $finish;
    end


endmodule


