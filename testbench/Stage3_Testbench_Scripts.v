ChampionCHIP Stage 3 - Team 41 Testbench Scripts
==================================================

Source 1: stage3/chipinventor_kit/3_testbench/tb_OFFICIAL_TEST_FW.v
Purpose : Validate base GPIO + UART integration using the official firmware.

==================== tb_OFFICIAL_TEST_FW.v ====================
// ============================================================================
// ChipInventor testbench - OFFICIAL GPIO & UART TEST FIRMWARE (Team 41)
// Use with block MemoryUnit_SoC_equipe41__OFFICIAL_TEST_FW.v
//
// Checks: GPIO P3-P0 = 0xA -> P7-P4 = 0xA (gpio_out = 0xA0, gpio_oe = 0xF0)
//         UART RX 0x30 -> UART TX 0x30
//         2nd loop: UART 0x4B -> 0x4B, then GPIO 0x5 -> 0x5
// Only top-level ports are used, so it works with any ChipInventor
// instance names. Clock 50 MHz, UART 115200 8-N-1 (8680 ns per bit).
// ============================================================================
`timescale 1ns / 1ps
module testbench;

    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg  [7:0] gpio_in = 8'h00;
    reg        uart_rx = 1'b1;        // testbench -> processor, idle high
    wire [7:0] gpio_out;
    wire [7:0] gpio_oe;
    wire       uart_tx;               // processor -> testbench
    wire       o_halt;

    top dut (
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
        $dumpvars(0, testbench);

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
        check_uart(8'h30, 0);

        // second loop iteration (new GPIO value is read after the next echo)
        gpio_in = 8'h05;
        check_uart(8'h4B, 1);
        check_gpio(4'h5);

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


Source 2: stage3/chipinventor_kit/3_testbench/tb_TOLLGUARD_APP_FW.v
Purpose : Validate TollGuard application behaviour across seven test vectors.

================== tb_TOLLGUARD_APP_FW.v ======================
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
module testbench;

    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg  [7:0] gpio_in = 8'h00;
    reg        uart_rx = 1'b1;
    wire [7:0] gpio_out;
    wire [7:0] gpio_oe;
    wire       uart_tx;
    wire       o_halt;

    top dut (
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
        $dumpvars(1, testbench);

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
