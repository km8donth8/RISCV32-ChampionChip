// ============================================================================
// tb_official_fw - Official GPIO & UART Test Firmware validation
// Team 41 (Equipe 41) - ChampionCHIP Stage 3
//
// DUT     : soc_top_equipe41 with IMEM = RVBL-GPIO-UART-Test-Firmware
// Checks  : (required)  GPIO P3-P0 = 0xA  -> P7-P4 = 0xA  (DATAOUT = 0xA0)
//                       UART RX    = 0x30 -> UART TX = 0x30
//           (extra)     second loop iteration with new values, to show the
//                       firmware loops and both peripherals keep working
// Clock   : 50 MHz, UART 115200 baud 8-N-1 (434 clocks / bit)
// ============================================================================
`timescale 1ns / 1ps
module tb_official_fw;

    localparam integer CLK_FREQ_HZ = 50_000_000;
    localparam integer BAUD        = 115_200;
    localparam real    CLK_NS      = 1.0e9 / CLK_FREQ_HZ;       // 20 ns
    localparam real    BIT_NS      = 1.0e9 / BAUD;              // 8680.6 ns
    localparam integer TIMEOUT_NS  = 2_000_000;                 // 2 ms / step

    reg         clk = 1'b0;
    reg         rst_n = 1'b0;
    reg  [7:0]  gpio_in = 8'h00;
    reg         uart_rx = 1'b1;           // TB -> processor (idle high)
    wire [7:0]  gpio_out, gpio_oe;
    wire        uart_tx;                  // processor -> TB
    wire        o_halt;
    wire [31:0] o_pc;

    integer errors = 0;
    reg [7:0] rx_byte;

    always #(CLK_NS/2) clk = ~clk;

    soc_top_equipe41 #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD)) dut (
        .clk(clk), .rst_n(rst_n), .o_halt(o_halt),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .uart_rx_i(uart_rx), .uart_tx_o(uart_tx), .o_pc(o_pc)
    );

    // ---- waveform-friendly aliases ----
    wire [3:0] P3_P0   = gpio_in[3:0];
    wire [3:0] P7_P4   = gpio_out[7:4];
    wire [7:0] DATAOUT = dut.blk_mem_soc.u_gpio.r_dataout;
    wire [7:0] DATADIR = dut.blk_mem_soc.u_gpio.r_datadir;
    wire [2:0] UART_CONTROL = {dut.blk_mem_soc.u_uart.r_txdone,
                               dut.blk_mem_soc.u_uart.r_rxdone,
                               dut.blk_mem_soc.u_uart.r_transmit};
    wire [7:0] RXDATA  = dut.blk_mem_soc.u_uart.r_rxdata;
    wire [7:0] TXDATA  = dut.blk_mem_soc.u_uart.r_txdata;

    // ---------------- UART BFM: send one byte to processor RX ---------------
    task uart_send(input [7:0] b);
        integer i;
        begin
            uart_rx = 1'b0;  #(BIT_NS);                  // start
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i]; #(BIT_NS);               // LSB first
            end
            uart_rx = 1'b1;  #(BIT_NS);                  // stop
        end
    endtask

    // ---------------- UART BFM: receive one byte from processor TX ----------
    task uart_recv(output [7:0] b, output ok);
        integer i;
        begin : recv
            ok = 1'b0; b = 8'h00;
            fork
                begin : wait_start
                    @(negedge uart_tx);
                    #(BIT_NS/2);                          // centre of start
                    if (uart_tx !== 1'b0) disable recv;   // glitch
                    for (i = 0; i < 8; i = i + 1) begin
                        #(BIT_NS); b[i] = uart_tx;
                    end
                    #(BIT_NS);
                    ok = (uart_tx === 1'b1);              // valid stop bit
                    disable to;
                end
                begin : to
                    #(TIMEOUT_NS);
                    disable wait_start;
                end
            join
        end
    endtask

    // ---------------- GPIO check with timeout ----------------
    task check_gpio(input [3:0] stim);
        integer t;
        begin
            t = 0;
            while (P7_P4 !== stim && t < TIMEOUT_NS) begin #(CLK_NS); t = t + CLK_NS; end
            if (P7_P4 === stim)
                $display("[PASS] GPIO: P3-P0 = 0x%h, P7-P4 = 0x%h  (DATAOUT = 0x%h)  @ %t",
                         stim, P7_P4, DATAOUT, $time);
            else begin
                $display("[FAIL] GPIO: P3-P0 = 0x%h, expected P7-P4 = 0x%h, got 0x%h (timeout)",
                         stim, stim, P7_P4);
                errors = errors + 1;
            end
        end
    endtask

    // ---------------- UART echo check ----------------
    task check_uart(input [7:0] b);
        reg ok;
        begin
            fork
                uart_send(b);
                uart_recv(rx_byte, ok);
            join
            if (ok && rx_byte === b)
                $display("[PASS] UART: RX = 0x%h, TX = 0x%h  @ %t", b, rx_byte, $time);
            else begin
                $display("[FAIL] UART: RX = 0x%h, TX = 0x%h (ok=%0d)", b, rx_byte, ok);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $timeformat(-6, 2, " us", 10);
        $dumpfile("results/tb_official_fw.vcd");
        $dumpvars(0, tb_official_fw);

        $display("=====================================================================");
        $display(" ChampionCHIP Stage 3 - Official GPIO & UART Test Firmware (Team 41)");
        $display(" SoC clock %0d MHz, UART %0d baud 8-N-1", CLK_FREQ_HZ/1_000_000, BAUD);
        $display("=====================================================================");

        // GPIO stimulus present before the firmware's first GPIO read
        gpio_in = 8'h0A;
        #(5*CLK_NS) rst_n = 1'b1;

        // ---- Iteration 1: required checks ----
        check_gpio(4'hA);
        if (DATADIR !== 8'hF0) begin
            $display("[FAIL] DATADIR = 0x%h (expected 0xF0)", DATADIR); errors = errors + 1;
        end else
            $display("[INFO] DATADIR = 0x%h -> P7-P4 outputs, P3-P0 inputs", DATADIR);
        check_uart(8'h30);

        // ---- Iteration 2: firmware loops, new values ----
        // The loop already re-read P3-P0 (still 0xA) and is now blocked on
        // RXDONE, so the new GPIO value is only sampled after the next echo.
        gpio_in = 8'h05;
        check_uart(8'h4B);          // 0100_1011: not a bit-palindrome, catches bit-order bugs
        check_gpio(4'h5);

        $display("---------------------------------------------------------------------");
        if (errors == 0)
            $display("[PASS] GPIO and UART firmware test completed successfully");
        else
            $display("[FAIL] %0d check(s) failed", errors);
        $display("Simulated time: %t, PC = 0x%h, halt = %b", $time, o_pc, o_halt);
        $display("=====================================================================");
        #(10_000);
        $finish;
    end

endmodule
