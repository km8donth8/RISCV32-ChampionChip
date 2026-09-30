# Testbench Results — Team 41 (Equipe 41)

## 1. Official GPIO & UART firmware testbench

![1. Official GPIO & UART firmware testbench](pic/stage3_tb.png)

<details>
<summary>Testbench: <code>tb_OFFICIAL_stage3.v</code></summary>

```verilog
module tb_stage3_top;


    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg  [7:0] gpio_in = 8'h00;
    reg        uart_rx = 1'b1;        // testbench -> processor, idle high
    wire [7:0] gpio_out;
    wire [7:0] gpio_oe;
    wire       uart_tx;               // processor -> testbench
    wire       o_halt;


    stage3_top_old dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .o_halt   (o_halt),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe),
        .uart_rx_i(uart_rx),
        .uart_tx_o(uart_tx)
    );


    always #10 clk = ~clk;            // 50 MHz


    parameter BIT_NS  = 8680;         // 434 clocks per bit
    parameter TIMEOUT = 3000000;      // 3 ms


    integer errors = 0;


    // Easy-to-read waveform signals
    wire [3:0] P3_P0 = gpio_in[3:0];
    wire [3:0] P7_P4 = gpio_out[7:4];


    // ---------------- UART monitor: every byte the processor sends ----------
    reg  [7:0] tx_bytes [0:15];
    integer    tx_count = 0;
    reg  [7:0] mon_byte;
    integer    mi;
    always begin
        @(negedge uart_tx);
        #(BIT_NS/2);                              // middle of start bit
        if (uart_tx == 1'b0) begin
            for (mi = 0; mi < 8; mi = mi + 1) begin
                #(BIT_NS);
                mon_byte[mi] = uart_tx;           // LSB first
            end
            #(BIT_NS);                            // stop bit
            tx_bytes[tx_count] = mon_byte;
            tx_count = tx_count + 1;
        end
    end


    // ---------------- send one byte to the processor RX ---------------------
    task uart_send;
        input [7:0] b;
        integer i;
        begin
            uart_rx = 1'b0; #(BIT_NS);            // start bit
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i]; #(BIT_NS);
            end
            uart_rx = 1'b1; #(BIT_NS);            // stop bit
        end
    endtask


    // corrupted frame: stop bit driven low (framing error)
    task uart_send_bad_stop;
        input [7:0] b;
        integer i;
        begin
            uart_rx = 1'b0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i]; #(BIT_NS);
            end
            uart_rx = 1'b0; #(BIT_NS);            // INVALID stop bit
            uart_rx = 1'b1; #(2*BIT_NS);          // back to idle
        end
    endtask


    task wait_tx_count;
        input integer n;
        integer t;
        begin
            t = 0;
            while (tx_count < n && t < TIMEOUT) begin #20; t = t + 20; end
        end
    endtask


    task wait_gpio_out;
        input [7:0] exp;
        integer t;
        begin
            t = 0;
            while (gpio_out !== exp && t < TIMEOUT) begin #20; t = t + 20; end
        end
    endtask


    task check_gpio;
        input [3:0] stim;
        begin
            wait_gpio_out({stim, 4'h0});
            if (P7_P4 === stim)
                $display("[PASS] GPIO: P3-P0 = 0x%h, P7-P4 = 0x%h (gpio_out = 0x%h)   t = %0d ns",
                         P3_P0, P7_P4, gpio_out, $time);
            else begin
                $display("[FAIL] GPIO: P3-P0 = 0x%h, expected P7-P4 = 0x%h, got 0x%h", P3_P0, stim, P7_P4);
                errors = errors + 1;
            end
        end
    endtask


    task check_uart;
        input [7:0] b;
        input integer idx;
        begin
            uart_send(b);
            wait_tx_count(idx + 1);
            if (tx_count > idx && tx_bytes[idx] === b)
                $display("[PASS] UART: RX = 0x%h, TX = 0x%h   t = %0d ns", b, tx_bytes[idx], $time);
            else begin
                $display("[FAIL] UART: RX = 0x%h, TX not received or wrong (count %0d)", b, tx_count);
                errors = errors + 1;
            end
        end
    endtask


    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, tb_stage3_top);


        $display("=========================================================");
        $display(" ChampionCHIP Stage 3 - Official GPIO & UART Test (Team 41)");
        $display("=========================================================");


        gpio_in = 8'h0A;                  // stimulus present before the first read
        #95 rst_n = 1'b1;


        // required checks
        check_gpio(4'hA);
        if (gpio_oe === 8'hF0)
            $display("[INFO] DATADIR = 0x%h -> P7-P4 outputs, P3-P0 inputs", gpio_oe);
        else begin
            $display("[FAIL] DATADIR = 0x%h, expected 0xF0", gpio_oe);
            errors = errors + 1;
        end


        gpio_in = 8'h05;
        check_uart(8'h30, 0);


        // second loop iteration (new GPIO value is read after the next echo)
       
        check_uart(8'h4B, 1);
        check_gpio(4'h5);


        // extra (team) robustness check: framing error must be dropped
        uart_send_bad_stop(8'h77);
        #200000;
        if (tx_count == 2)
            $display("[PASS] UART: frame with invalid stop bit dropped (no echo)   t = %0d ns", $time);
        else begin
            $display("[FAIL] UART: corrupted frame was accepted/echoed");
            errors = errors + 1;
        end
        check_uart(8'h5C, 2);             // receiver resynchronised


        $display("---------------------------------------------------------");
        if (errors == 0 && o_halt !== 1'b1)
            $display("[PASS] GPIO and UART firmware test completed successfully");
        else
            $display("[FAIL] %0d check(s) failed, halt = %b", errors, o_halt);
        $display("=========================================================");
        #10000;
        $finish;
    end


endmodule
```

</details>

---

## 2. GPIO block testbench

![2. GPIO block testbench](pic/GPIO_tb_1.png)

![2. GPIO block testbench](pic/GPIO_tb_2.png)

![2. GPIO block testbench](pic/GPIO_tb_3.png)

<details>
<summary>Testbench: <code>tb_GPIO_equipe41.v</code></summary>

```verilog
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
```

</details>

---

## 3. UART block testbench

![3. UART block testbench](pic/UART_tb_1.png)

![3. UART block testbench](pic/UART_tb_2.png)

![3. UART block testbench](pic/UART_tb_3.png)

<details>
<summary>Testbench: <code>tb_UART_equipe41.v</code></summary>

```verilog
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
```

</details>

---

## 4. TollGuard application testbench

![4. TollGuard application testbench](pic/tb_TOLLGUARD.png)

<details>
<summary>Testbench: <code>tb_TollGuard_Application.v</code></summary>

```verilog
// ============================================================================
// ChipInventor testbench - TOLLGUARD APPLICATION FIRMWARE (Team 41)
// Use with block MemoryUnit_SoC_equipe41__TOLLGUARD_APP_FW.v
//
// The testbench plays the roadside: vehicle sensors on P3-P0, the RFID reader
// on UART RX. It checks the 7-byte receipt on UART TX and the lamps on P7-P4
// against expected values from the Python reference model.
//   Pass A: reset before every vehicle (same as one ./emu call)
//   Pass B: one reset, vehicles back-to-back (lamps held until the vehicle
//           leaves, then READY again)
// Only top-level ports are used. Clock 50 MHz, UART 115200 8-N-1.
//
// GPIO in : P3 VEHICLE | P2 PEAK | P1:P0 CLASS (0..3 = Class 1..4)
// GPIO out: P4 GATE | P5 LOW_BALANCE | P6 FRAME_ERROR | P7 READY
// UART RX : balance(4B) km(2B) crc16(2B), LSB first
// UART TX : status(1B) fare(2B) new_balance(4B), LSB first
// ============================================================================
`timescale 1ns / 1ps
module tb_stage3_top;


    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg  [7:0] gpio_in = 8'h00;
    reg        uart_rx = 1'b1;
    wire [7:0] gpio_out;
    wire [7:0] gpio_oe;
    wire       uart_tx;
    wire       o_halt;


    stage3_top_old dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .o_halt   (o_halt),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe),
        .uart_rx_i(uart_rx),
        .uart_tx_o(uart_tx)
    );


    always #10 clk = ~clk;            // 50 MHz


    parameter BIT_NS  = 8680;
    parameter TIMEOUT = 3000000;
    parameter N_VEC   = 7;


    // Easy-to-read waveform signals
    wire       VEHICLE  = gpio_in[3];
    wire       PEAK     = gpio_in[2];
    wire [1:0] CLASS    = gpio_in[1:0];
    wire       GATE     = gpio_out[4];
    wire       LOWBAL   = gpio_out[5];
    wire       FRAMEERR = gpio_out[6];
    wire       READY    = gpio_out[7];


    // ---------------- test vectors (scripts/tollguard_model.py) -------------
    reg [7:0]  v_in   [0:N_VEC-1];
    reg [31:0] v_bal  [0:N_VEC-1];
    reg [15:0] v_km   [0:N_VEC-1];
    reg [15:0] v_crc  [0:N_VEC-1];
    reg [7:0]  e_st   [0:N_VEC-1];
    reg [15:0] e_fare [0:N_VEC-1];
    reg [31:0] e_bal  [0:N_VEC-1];
    reg [7:0]  e_out  [0:N_VEC-1];
    initial begin
        // 0: Car, off-peak, RM50.00, 25 km -> OK
        v_in[0] = 8'h08; v_bal[0] = 32'h00001388; v_km[0] = 16'h0019; v_crc[0] = 16'h8411;
        e_st[0] = 8'h00; e_fare[0] = 16'h015E; e_bal[0] = 32'h0000122A; e_out[0] = 8'h10;
        // 1: Van, peak, RM100.00, 120 km -> OK
        v_in[1] = 8'h0D; v_bal[1] = 32'h00002710; v_km[1] = 16'h0078; v_crc[1] = 16'hFA04;
        e_st[1] = 8'h00; e_fare[1] = 16'h0E8D; e_bal[1] = 32'h00001883; e_out[1] = 8'h10;
        // 2: Lorry, low balance RM10.00, 80 km -> LOW_BALANCE
        v_in[2] = 8'h0A; v_bal[2] = 32'h000003E8; v_km[2] = 16'h0050; v_crc[2] = 16'h6807;
        e_st[2] = 8'h01; e_fare[2] = 16'h0BD6; e_bal[2] = 32'h000003E8; e_out[2] = 8'h20;
        // 3: Taxi, peak, RM1234.56, 300 km -> OK
        v_in[3] = 8'h0F; v_bal[3] = 32'h0001E240; v_km[3] = 16'h012C; v_crc[3] = 16'h3E91;
        e_st[3] = 8'h00; e_fare[3] = 16'h08EF; e_bal[3] = 32'h0001D951; e_out[3] = 8'h10;
        // 4: Car, exact balance RM1.70, 10 km -> OK
        v_in[4] = 8'h08; v_bal[4] = 32'h000000AA; v_km[4] = 16'h000A; v_crc[4] = 16'h86F1;
        e_st[4] = 8'h00; e_fare[4] = 16'h00AA; e_bal[4] = 32'h00000000; e_out[4] = 8'h10;
        // 5: Car, tampered frame (bad CRC) -> CRC_ERROR
        v_in[5] = 8'h08; v_bal[5] = 32'h00001388; v_km[5] = 16'h0019; v_crc[5] = 16'hBEEF;
        e_st[5] = 8'h02; e_fare[5] = 16'h0000; e_bal[5] = 32'h00000000; e_out[5] = 8'h40;
        // 6: Lorry, distance 1500 km out of range -> OUT_OF_RANGE
        v_in[6] = 8'h0A; v_bal[6] = 32'h000DBBA0; v_km[6] = 16'h05DC; v_crc[6] = 16'h1490;
        e_st[6] = 8'h03; e_fare[6] = 16'h0000; e_bal[6] = 32'h00000000; e_out[6] = 8'h40;
    end


    integer errors = 0;
    integer checks = 0;


    // ---------------- UART monitor: every byte the processor sends ----------
    reg  [7:0] tx_bytes [0:255];
    integer    tx_time  [0:255];
    integer    tx_count = 0;
    reg  [7:0] mon_byte;
    integer    mi, t_start;
    always begin
        @(negedge uart_tx);
        t_start = $time;
        #(BIT_NS/2);
        if (uart_tx == 1'b0) begin
            for (mi = 0; mi < 8; mi = mi + 1) begin
                #(BIT_NS);
                mon_byte[mi] = uart_tx;
            end
            #(BIT_NS);
            tx_bytes[tx_count] = mon_byte;
            tx_time[tx_count]  = t_start;
            tx_count = tx_count + 1;
        end
    end


    task uart_send;
        input [7:0] b;
        integer i;
        begin
            uart_rx = 1'b0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i]; #(BIT_NS);
            end
            uart_rx = 1'b1; #(BIT_NS);
        end
    endtask


    task wait_gpio_out;
        input [7:0] exp;
        integer t;
        begin
            t = 0;
            while (gpio_out !== exp && t < TIMEOUT) begin #20; t = t + 20; end
        end
    endtask


    task check;
        input [31:0] got;
        input [31:0] exp;
        input [8*20-1:0] what;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("    [FAIL] %0s: got 0x%h expected 0x%h", what, got, exp);
            end
        end
    endtask


    // ---------------- one vehicle ----------------
    task run_vehicle;
        input integer k;
        input         emu_style;
        integer base, t, err0, t_rx_done;
        reg [15:0] fare;
        reg [31:0] bal;
        begin
            err0 = errors;
            if (emu_style) begin                           // like one ./emu call
                rst_n = 1'b0; gpio_in = 8'h00; #200; rst_n = 1'b1;
            end
            wait_gpio_out(8'h80);
            check(gpio_out, 8'h80, "READY lamp");
            #30000;                                         // gantry idle


            base = tx_count;
            gpio_in = v_in[k];                              // vehicle arrives
            wait_gpio_out(8'h00);
            check(gpio_out, 8'h00, "busy (lamps off)");


            uart_send(v_bal[k][7:0]);   uart_send(v_bal[k][15:8]);
            uart_send(v_bal[k][23:16]); uart_send(v_bal[k][31:24]);
            uart_send(v_km[k][7:0]);    uart_send(v_km[k][15:8]);
            uart_send(v_crc[k][7:0]);   uart_send(v_crc[k][15:8]);
            t_rx_done = $time - BIT_NS/2;                   // RXDONE of last byte


            t = 0;
            while (tx_count < base + 7 && t < TIMEOUT) begin #20; t = t + 20; end
            check(tx_count - base, 7, "receipt length");


            fare = {tx_bytes[base+2], tx_bytes[base+1]};
            bal  = {tx_bytes[base+6], tx_bytes[base+5], tx_bytes[base+4], tx_bytes[base+3]};
            check(tx_bytes[base], e_st[k], "STATUS");
            check(fare, e_fare[k], "FARE");
            check(bal,  e_bal[k],  "BALANCE");
            wait_gpio_out(e_out[k]);
            check(gpio_out, e_out[k], "lamps P7-P4");


            $display("  [%0s] #%0d in=0x%h bal=%0d km=%0d crc=0x%h | status=%0d fare=%0d new_bal=%0d lamps=0x%h | ~%0d cycles",
                     (errors == err0) ? "PASS" : "FAIL", k, v_in[k], v_bal[k], v_km[k], v_crc[k],
                     tx_bytes[base], fare, bal, gpio_out, (tx_time[base] - t_rx_done) / 20);


            if (!emu_style) begin                           // vehicle drives off
                #20000;
                check(gpio_out, e_out[k], "lamps held");
                gpio_in = 8'h00;
                wait_gpio_out(8'h80);
                check(gpio_out, 8'h80, "READY after leave");
            end
        end
    endtask


    integer k;
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(1, tb_stage3_top);


        $display("==========================================================================");
        $display(" TollGuard application firmware - Team 41 (%0d vectors, 2 passes)", N_VEC);
        $display("==========================================================================");
        #95 rst_n = 1'b1;


        $display("Pass A - emulator style (reset per vehicle)");
        for (k = 0; k < N_VEC; k = k + 1) run_vehicle(k, 1'b1);


        $display("Pass B - continuous gantry (vehicles back-to-back)");
        rst_n = 1'b0; gpio_in = 8'h00; #200; rst_n = 1'b1;
        for (k = 0; k < N_VEC; k = k + 1) run_vehicle(k, 1'b0);


        $display("--------------------------------------------------------------------------");
        if (errors == 0 && o_halt !== 1'b1)
            $display("[PASS] TollGuard: %0d checks passed", checks);
        else
            $display("[FAIL] TollGuard: %0d of %0d checks failed (halt = %b)", errors, checks, o_halt);
        $display("==========================================================================");
        $finish;
    end


    always @(posedge o_halt) begin
        $display("[FAIL] core halted (illegal instruction)");
        errors = errors + 1;
    end


endmodule
```

</details>

---
