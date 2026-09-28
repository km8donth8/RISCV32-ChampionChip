// ============================================================================
// UART_equipe41 - Serial Controller (ChampionCHIP Block Guide, section 2)
// Team 41 (Equipe 41) - Stage 3
//
// Memory map (base 0xF1000000, 32-bit aligned, addr[1:0] ignored):
//   0x0000 TXDATA  [7:0] RW  byte to transmit (sent when TRANSMIT is set)
//   0x0004 RXDATA  [7:0] R   last byte received
//   0x0008 CONTROL
//           bit 2 TXDONE   R   1 = transmitter idle / last frame finished
//           bit 1 RXDONE   RW  1 = new byte in RXDATA; cleared by writing 0
//           bit 0 TRANSMIT W   write 1 to start; self-clears next cycle
//
// Frame: 8-N-1, LSB first, BAUD_RATE (default 115200), full duplex,
// independent 8-bit TX and RX shift registers, no oversampling
// (one sample per bit, taken at the bit centre), no flow control.
//
// Reset state: TXDONE = 1 (transmitter ready), RXDONE = 0, tx_o idle high.
// ============================================================================
module UART_equipe41 #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,

    // bus side
    input  wire        sel_i,
    input  wire        we_i,
    input  wire [3:2]  addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,

    // serial pins
    input  wire        rx_i,
    output reg         tx_o
);

    localparam integer CLKS_PER_BIT  = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF_BIT      = CLKS_PER_BIT / 2;
    localparam integer CW            = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT + 1) : 1;

    localparam OFF_TXDATA  = 2'd0;
    localparam OFF_RXDATA  = 2'd1;
    localparam OFF_CONTROL = 2'd2;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    // ------------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------------
    reg [7:0] r_txdata;
    reg [7:0] r_rxdata;
    reg       r_transmit;   // CONTROL[0]
    reg       r_rxdone;     // CONTROL[1]
    reg       r_txdone;     // CONTROL[2]

    wire wr_txdata  = sel_i && we_i && (addr_i == OFF_TXDATA);
    wire wr_control = sel_i && we_i && (addr_i == OFF_CONTROL);

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
    reg [1:0]    rx_state;
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
                        rx_cnt        <= {CW{1'b0}};
                        r_rxdata      <= rx_shift;
                        rx_frame_done <= 1'b1;
                        rx_state      <= S_IDLE;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
            endcase
        end
    end

    // ---------------- register reads ----------------
    always @(*) begin
        rdata_o = 32'h0000_0000;
        if (sel_i) begin
            case (addr_i)
                OFF_TXDATA:  rdata_o = {24'h0, r_txdata};
                OFF_RXDATA:  rdata_o = {24'h0, r_rxdata};
                OFF_CONTROL: rdata_o = {29'h0, r_txdone, r_rxdone, r_transmit};
                default:     rdata_o = 32'h0000_0000;
            endcase
        end
    end

endmodule
