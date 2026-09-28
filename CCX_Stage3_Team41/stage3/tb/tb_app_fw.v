// ============================================================================
// tb_app_fw - TollGuard application firmware testbench (Team 41 / Equipe 41)
// ChampionCHIP Stage 3 - custom firmware validation
//
// DUT   : soc_top_equipe41, IMEM = TollGuard firmware (firmware/app)
// Model : the testbench plays the roadside: vehicle sensors on P3-P0, the RFID
//         reader on UART RX, and it checks the receipt on UART TX and the
//         lamps on P7-P4 against scripts/tollguard_model.py (app_vectors.vh).
//
// Pass A "emulator style": processor reset before every vehicle, exactly as
//        one ./emu invocation (reset -> -o READY -> -i -> -t.. -> -r.. -> -o).
// Pass B "continuous gantry": one reset, vehicles back-to-back; checks that
//        lamps hold until the vehicle leaves and READY returns afterwards.
// ============================================================================
`timescale 1ns / 1ps
module tb_app_fw;

    localparam integer CLK_FREQ_HZ = 50_000_000;
    localparam integer BAUD        = 115_200;
    localparam real    CLK_NS      = 1.0e9 / CLK_FREQ_HZ;
    localparam real    BIT_NS      = 1.0e9 / BAUD;
    localparam integer TIMEOUT_NS  = 3_000_000;

    reg         clk = 1'b0;
    reg         rst_n = 1'b0;
    reg  [7:0]  gpio_in = 8'h00;
    reg         uart_rx = 1'b1;
    wire [7:0]  gpio_out, gpio_oe;
    wire        uart_tx, o_halt;
    wire [31:0] o_pc;

    always #(CLK_NS/2) clk = ~clk;

    soc_top_equipe41 #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD)) dut (
        .clk(clk), .rst_n(rst_n), .o_halt(o_halt),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .uart_rx_i(uart_rx), .uart_tx_o(uart_tx), .o_pc(o_pc)
    );

    // -------------------- waveform-friendly aliases --------------------
    wire       VEHICLE  = gpio_in[3];
    wire       PEAK     = gpio_in[2];
    wire [1:0] CLASS    = gpio_in[1:0];
    wire       GATE     = gpio_out[4];
    wire       LOWBAL   = gpio_out[5];
    wire       FRAMEERR = gpio_out[6];
    wire       READY    = gpio_out[7];
    wire [31:0] crc_running = dut.blk4352_11.regs[19];   // s3
    wire [31:0] balance_rx  = dut.blk4352_11.regs[20];   // s4
    wire [31:0] km_rx       = dut.blk4352_11.regs[21];   // s5
    wire [31:0] crc_rx      = dut.blk4352_11.regs[23];   // s7 (after frame)
    wire [31:0] fare_reg    = dut.blk4352_11.regs[11];   // a1
    wire [5:0]  cu_state    = dut.blk4354_26.state_q;
    wire [31:0] pc          = o_pc;

    // -------------------- vectors --------------------
    reg [7:0]  v_gpio_in [0:15];
    reg [31:0] v_balance [0:15];
    reg [15:0] v_km      [0:15];
    reg [15:0] v_crc     [0:15];
    reg [7:0]  e_status  [0:15];
    reg [15:0] e_fare    [0:15];
    reg [31:0] e_balance [0:15];
    reg [7:0]  e_gpio_out[0:15];
    `include "app_vectors.vh"

    integer errors = 0, checks = 0;

    // -------------------- cycle-accurate latency probe --------------------
    // from RXDONE of the 8th frame byte to the TRANSMIT of the first reply byte
    integer cyc = 0, rx_count = 0, t_rx_last = 0, t_tx_first = 0;
    reg     tx_seen = 1'b0;
    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (dut.blk_mem_soc.u_uart.rx_frame_done) begin
            rx_count <= rx_count + 1;
            if (rx_count == 7) t_rx_last <= cyc;
        end
        if (dut.blk_mem_soc.u_uart.tx_start && !tx_seen) begin
            tx_seen    <= 1'b1;
            t_tx_first <= cyc;
        end
    end

    // -------------------- UART BFM --------------------
    task uart_send(input [7:0] b);
        integer i;
        begin
            uart_rx = 1'b0;  #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin uart_rx = b[i]; #(BIT_NS); end
            uart_rx = 1'b1;  #(BIT_NS);
        end
    endtask

    task uart_recv(output [7:0] b, output ok);
        integer i;
        begin : recv
            ok = 1'b0; b = 8'h00;
            fork
                begin : w
                    @(negedge uart_tx);
                    #(BIT_NS/2);
                    if (uart_tx !== 1'b0) disable recv;
                    for (i = 0; i < 8; i = i + 1) begin #(BIT_NS); b[i] = uart_tx; end
                    #(BIT_NS);
                    ok = (uart_tx === 1'b1);
                    disable t;
                end
                begin : t
                    #(TIMEOUT_NS); disable w;
                end
            join
        end
    endtask

    // -------------------- checkers --------------------
    task expect8(input [8*24-1:0] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("    [FAIL] %0s: got 0x%h expected 0x%h", what, got, exp);
            end
        end
    endtask

    task wait_gpio(input [7:0] exp, input [8*24-1:0] what);
        integer t;
        begin
            t = 0;
            while (gpio_out !== exp && t < TIMEOUT_NS) begin #(CLK_NS); t = t + CLK_NS; end
            expect8(what, gpio_out, exp);
        end
    endtask

    // -------------------- one vehicle --------------------
    reg [7:0]  frame [0:7];
    reg [7:0]  reply [0:6];
    reg        okb   [0:6];

    task run_vehicle(input integer k, input reg emu_style);
        integer i, is, ir, err0;
        reg [15:0] fare_got;
        reg [31:0] bal_got;
        begin
            err0 = errors;
            {frame[3],frame[2],frame[1],frame[0]} = v_balance[k];
            {frame[5],frame[4]} = v_km[k];
            {frame[7],frame[6]} = v_crc[k];

            if (emu_style) begin                       // ./emu: fresh reset
                rst_n = 1'b0; gpio_in = 8'h00; #(10*CLK_NS); rst_n = 1'b1;
            end
            wait_gpio(8'h80, "READY lamp (idle)");       // -o 0x80
            #(30_000);                                   // gantry idle, no vehicle

            rx_count = 0; tx_seen = 1'b0;
            gpio_in = v_gpio_in[k];                      // -i
            wait_gpio(8'h00, "busy (lamps off)");

            fork
                for (is = 0; is < 8; is = is + 1) uart_send(frame[is]);            // -t4 -t2 -t2
                for (ir = 0; ir < 7; ir = ir + 1) uart_recv(reply[ir], okb[ir]);   // -r1 -r2 -r4
            join

            for (i = 0; i < 7; i = i + 1)
                if (!okb[i]) begin errors = errors + 1; $display("    [FAIL] reply byte %0d not received", i); end
            fare_got = {reply[2], reply[1]};
            bal_got  = {reply[6], reply[5], reply[4], reply[3]};
            expect8("STATUS",  reply[0], e_status[k]);
            expect8("FARE",    fare_got, e_fare[k]);
            expect8("BALANCE", bal_got,  e_balance[k]);
            wait_gpio(e_gpio_out[k], "lamps (P7-P4)");       // -o

            $display("  [%s] #%0d in=0x%h bal=%0d km=%0d crc=0x%h | status=%0d fare=%0d sen new_bal=%0d lamps=0x%h | latency %0d cyc",
                     (errors == err0) ? "PASS" : "FAIL", k, v_gpio_in[k], v_balance[k], v_km[k], v_crc[k],
                     reply[0], fare_got, bal_got, gpio_out, t_tx_first - t_rx_last);

            if (!emu_style) begin                      // vehicle drives off
                #(20_000);
                expect8("lamps held while vehicle present", gpio_out, e_gpio_out[k]);
                gpio_in = 8'h00;
                wait_gpio(8'h80, "READY after vehicle left");
            end
        end
    endtask

    integer k;
    initial begin
        $timeformat(-6, 2, " us", 10);
        $dumpfile("results/tb_app_fw.vcd");
        $dumpvars(1, tb_app_fw);                          // pins + aliases
        $dumpvars(1, tb_app_fw.dut.blk_mem_soc.u_gpio);   // GPIO registers
        $dumpvars(1, tb_app_fw.dut.blk_mem_soc.u_uart);   // UART registers/FSMs
        load_vectors;

        $display("======================================================================================");
        $display(" TollGuard application firmware - Team 41 RV32I_Zmmul_Xicrc SoC");
        $display(" %0d vectors from scripts/tollguard_model.py | 50 MHz | UART 115200 8-N-1", N_VEC);
        $display("======================================================================================");
        #(5*CLK_NS) rst_n = 1'b1;

        $display("Pass A - emulator style (reset per vehicle, like one ./emu call)");
        for (k = 0; k < N_VEC; k = k + 1) run_vehicle(k, 1'b1);

        $display("Pass B - continuous gantry (single reset, vehicles back-to-back)");
        rst_n = 1'b0; gpio_in = 8'h00; #(10*CLK_NS); rst_n = 1'b1;
        for (k = 0; k < N_VEC; k = k + 1) run_vehicle(k, 1'b0);

        $display("--------------------------------------------------------------------------------------");
        if (errors == 0 && o_halt === 1'b0)
            $display("[PASS] TollGuard: %0d checks passed, %0d vehicles x 2 passes, no illegal-instruction halt", checks, N_VEC);
        else
            $display("[FAIL] TollGuard: %0d of %0d checks failed (halt=%b)", errors, checks, o_halt);
        $display("Simulated time %t", $time);
        $display("======================================================================================");
        $finish;
    end

    // safety net: the core must never reach the HALT / ILLEGAL state
    always @(posedge o_halt) begin
        $display("[FAIL] core halted at PC 0x%h (state %0d)", o_pc, cu_state);
        errors = errors + 1;
    end

endmodule
