// ============================================================================
// BLOCK: UART_equipe41   (ChipInventor block - Stage 3, Team 41)
// Serial Controller, ChampionCHIP Block Guide section 2
//
// Registers (base 0xF1000000, word aligned):
//   0x0 TXDATA  [7:0] RW  byte to send
//   0x4 RXDATA  [7:0] R   last byte received
//   0x8 CONTROL bit2 TXDONE (R, 1 at reset) | bit1 RXDONE (RW, write 0 to clear)
//               | bit0 TRANSMIT (W, self-clearing)
// 8-N-1, LSB first, 115200 baud, full duplex, no oversampling.
// RX checks the stop bit: a frame whose stop bit is low (framing error) is
// dropped (RXDONE not set) and the receiver waits for the idle line.
// Offsets other than 0x0/0x4/0x8 inside the window are reserved (read 0).
// CLK_FREQ_HZ must equal the real clock frequency (testbench uses 50 MHz).
//
// Connect:  sel_i   <- MemoryUnit_SoC_equipe41.uart_sel
//           we_i    <- MemoryUnit_SoC_equipe41.periph_we
//           addr_i  <- MemoryUnit_SoC_equipe41.periph_addr
//           wdata_i <- MemoryUnit_SoC_equipe41.periph_wdata
//           rdata_o -> MemoryUnit_SoC_equipe41.uart_rdata
//           rx_i <- top-level pin uart_rx_i ,  tx_o -> top-level pin uart_tx_o
// ============================================================================
module UART_equipe41 #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 1000_000//115_200
)(
    input  wire        clk,
    input  wire        rst_n,

    // bus side
    input  wire        sel_i,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,

    // serial pins
    input  wire        rx_i,
    output reg         tx_o
);

    localparam integer CLKS_PER_BIT  = (CLK_FREQ_HZ + BAUD_RATE/2) / BAUD_RATE;  // rounded
    localparam integer HALF_BIT      = CLKS_PER_BIT / 2;
    localparam integer CW            = 16;   // counter width (CLKS_PER_BIT < 65536)

    localparam OFF_TXDATA  = 10'd0;   // 0x000
    localparam OFF_RXDATA  = 10'd1;   // 0x004
    localparam OFF_CONTROL = 10'd2;   // 0x008  (all other offsets reserved)

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;
    localparam R_WAIT  = 3'd4;        // RX only: framing error, wait for idle line

    // ------------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------------
    reg [7:0] r_txdata;
    reg [7:0] r_rxdata;
    reg       r_transmit;   // CONTROL[0]
    reg       r_rxdone;     // CONTROL[1]
    reg       r_txdone;     // CONTROL[2]

    wire [9:0] reg_idx = addr_i[11:2];    // word index inside the 4 KB window
    wire wr_txdata  = sel_i && we_i && (reg_idx == OFF_TXDATA);
    wire wr_control = sel_i && we_i && (reg_idx == OFF_CONTROL);

    // ------------------------------------------------------------------
    // TX datapath
    // ------------------------------------------------------------------
    reg [1:0]    tx_state;
    reg [CW-1:0] tx_cnt;
    reg [2:0]    tx_bit;
    reg [7:0]    tx_shift;          // FIFOtx
    reg          tx_frame_done;     // 1-cycle pulse at end of stop bit

    // ------------------------------------------------------------------
    // RX datapath
    // ------------------------------------------------------------------
    reg          rx_s1, rx_s2;      // synchroniser (line idles high)
    reg [2:0]    rx_state;
    reg [CW-1:0] rx_cnt;
    reg [2:0]    rx_bit;
    reg [7:0]    rx_shift;          // FIFOrx
    reg          rx_frame_done;     // 1-cycle pulse when a byte is complete

    // ---------------- TXDATA ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          r_txdata <= 8'h00;
        else if (wr_txdata)  r_txdata <= wdata_i[7:0];
    end

    // ---------------- TRANSMIT: set by SW, cleared next cycle ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                          r_transmit <= 1'b0;
        else if (wr_control && wdata_i[0])   r_transmit <= 1'b1;
        else                                 r_transmit <= 1'b0;
    end

    wire tx_start = r_transmit && (tx_state == S_IDLE);

    // ---------------- TXDONE: HW owned ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              r_txdone <= 1'b1;
        else if (tx_start)       r_txdone <= 1'b0;
        else if (tx_frame_done)  r_txdone <= 1'b1;
    end

    // ---------------- RXDONE: set by HW, cleared by SW writing 0 --------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)              r_rxdone <= 1'b0;
        else if (rx_frame_done)  r_rxdone <= 1'b1;        // HW set has priority
        else if (wr_control)     r_rxdone <= wdata_i[1];
    end

    // ---------------- TX state machine ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state      <= S_IDLE;
            tx_cnt        <= {CW{1'b0}};
            tx_bit        <= 3'd0;
            tx_shift      <= 8'h00;
            tx_o          <= 1'b1;
            tx_frame_done <= 1'b0;
        end else begin
            tx_frame_done <= 1'b0;
            case (tx_state)
                S_IDLE: begin
                    tx_o <= 1'b1;
                    if (tx_start) begin
                        tx_shift <= r_txdata;         // load FIFOtx
                        tx_cnt   <= {CW{1'b0}};
                        tx_o     <= 1'b0;             // start bit
                        tx_state <= S_START;
                    end
                end
                S_START: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt   <= {CW{1'b0}};
                        tx_bit   <= 3'd0;
                        tx_o     <= tx_shift[0];      // LSB first
                        tx_state <= S_DATA;
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
                S_DATA: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt <= {CW{1'b0}};
                        if (tx_bit == 3'd7) begin
                            tx_o     <= 1'b1;         // stop bit
                            tx_state <= S_STOP;
                        end else begin
                            tx_bit   <= tx_bit + 1'b1;
                            tx_o     <= tx_shift[tx_bit + 1'b1];
                        end
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
                S_STOP: begin
                    if (tx_cnt == CLKS_PER_BIT - 1) begin
                        tx_cnt        <= {CW{1'b0}};
                        tx_state      <= S_IDLE;
                        tx_frame_done <= 1'b1;
                    end else tx_cnt <= tx_cnt + 1'b1;
                end
            endcase
        end
    end

    // ---------------- RX state machine ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_s1 <= 1'b1;
            rx_s2 <= 1'b1;
        end else begin
            rx_s1 <= rx_i;
            rx_s2 <= rx_s1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state      <= S_IDLE;
            rx_cnt        <= {CW{1'b0}};
            rx_bit        <= 3'd0;
            rx_shift      <= 8'h00;
            r_rxdata      <= 8'h00;
            rx_frame_done <= 1'b0;
        end else begin
            rx_frame_done <= 1'b0;
            case (rx_state)
                S_IDLE: begin
                    rx_cnt <= {CW{1'b0}};
                    if (!rx_s2) rx_state <= S_START;          // falling edge
                end
                S_START: begin                                // go to bit centre
                    if (rx_cnt == HALF_BIT - 1) begin
                        rx_cnt <= {CW{1'b0}};
                        if (!rx_s2) begin                     // valid start bit
                            rx_bit   <= 3'd0;
                            rx_state <= S_DATA;
                        end else rx_state <= S_IDLE;          // glitch
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                S_DATA: begin                                 // 1 sample / bit
                    if (rx_cnt == CLKS_PER_BIT - 1) begin
                        rx_cnt   <= {CW{1'b0}};
                        rx_shift <= {rx_s2, rx_shift[7:1]};   // LSB first
                        if (rx_bit == 3'd7) rx_state <= S_STOP;
                        else                rx_bit   <= rx_bit + 1'b1;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                S_STOP: begin
                    if (rx_cnt == CLKS_PER_BIT - 1) begin     // centre of stop
                        rx_cnt <= {CW{1'b0}};
                        if (rx_s2) begin                      // valid stop bit
                            r_rxdata      <= rx_shift;
                            rx_frame_done <= 1'b1;
                            rx_state      <= S_IDLE;
                        end else begin                        // framing error:
                            rx_state      <= R_WAIT;          // drop the byte
                        end
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                R_WAIT: begin                                 // resync: wait until
                    if (rx_s2) rx_state <= S_IDLE;            // the line is idle
                end
                default: rx_state <= S_IDLE;
            endcase
        end
    end

    // ---------------- register reads ----------------
    always @(*) begin
        rdata_o = 32'h0000_0000;
        if (sel_i) begin
            case (reg_idx)
                OFF_TXDATA:  rdata_o = {24'h0, r_txdata};
                OFF_RXDATA:  rdata_o = {24'h0, r_rxdata};
                OFF_CONTROL: rdata_o = {29'h0, r_txdone, r_rxdone, r_transmit};
                default:     rdata_o = 32'h0000_0000;
            endcase
        end
    end

endmodule
