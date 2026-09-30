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
        $dumpvars(0, stage3_top_old);


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
