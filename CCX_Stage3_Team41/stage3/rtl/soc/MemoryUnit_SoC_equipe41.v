// ============================================================================
// MemoryUnit_SoC_equipe41 - Stage 3 memory subsystem
// Team 41 (Equipe 41)
//
// Stage 2 MemoryUnit (LSU + AddressDecoder + IMEM + DMEM) extended with two
// memory-mapped peripheral windows. The core interface is UNCHANGED, so the
// Stage 2 datapath and 23-state Control Unit need no modification:
// peripherals are reached with ordinary lw / sw.
//
//   Region   Base         High         Latency   Access
//   IMEM     0x00400000   0x007FFFFF   comb.     read (fetch + const loads)
//   DMEM     0x10010000   0x10011FFF   1 cycle   read/write (byte lanes)
//   GPIO     0xF0000000   0xF0000FFF   comb.     32-bit word registers
//   UART     0xF1000000   0xF1000FFF   comb.     32-bit word registers
//
// Loads take LOAD_REQUEST + LOAD_CAPTURE in the Control Unit; the MDR is
// written at the end of LOAD_CAPTURE, so both the 1-cycle DMEM and the
// combinational peripheral reads are captured correctly.
// ============================================================================
module MemoryUnit_SoC_equipe41 #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115_200
)(
    input  wire        clk,
    input  wire        rst_n,
    // ---- core interface (same as Stage 2) ----
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,
    input  wire [31:0] core_address_o,
    output wire [31:0] core_data_i,
    // ---- GPIO pins ----
    input  wire [7:0]  gpio_in,
    output wire [7:0]  gpio_out,
    output wire [7:0]  gpio_oe,
    // ---- UART pins ----
    input  wire        uart_rx_i,
    output wire        uart_tx_o
);

    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;

    wire [31:0] imem_addr;
    wire        imem_read_en;
    wire [31:0] dmem_addr;
    wire        dmem_read_en, dmem_write_en;
    wire [3:0]  dmem_bw;
    wire        gpio_sel, uart_sel, periph_we;
    wire [1:0]  region_sel;

    wire [31:0] imem_out, dmem_out, gpio_rdata, uart_rdata;
    reg  [31:0] mux_mem_data_out;

    localparam [1:0] R_IMEM = 2'd0, R_DMEM = 2'd1, R_GPIO = 2'd2, R_UART = 2'd3;

    // DMEM answers one cycle after the request (same as Stage 2)
    reg dmem_sel_q;
    always @(posedge clk) dmem_sel_q <= (region_sel == R_DMEM);

    always @(*) begin
        case (region_sel)
            R_DMEM:  mux_mem_data_out = dmem_sel_q ? dmem_out : 32'h0;
            R_GPIO:  mux_mem_data_out = gpio_rdata;
            R_UART:  mux_mem_data_out = uart_rdata;
            default: mux_mem_data_out = imem_out;
        endcase
    end

    LSU u_lsu (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),
        .mem_address_i (lsu_mem_addr),
        .mem_data_i    (lsu_mem_data),
        .byte_write_i  (lsu_byte_write),
        .mem_data_o    (mux_mem_data_out)
    );

    AddressDecoder_SoC_equipe41 u_dec (
        .addr_i          (lsu_mem_addr),
        .read_enable_i   (read_enable),
        .write_enable_i  (write_enable),
        .bw_i            (lsu_byte_write),
        .imem_addr_o     (imem_addr),
        .imem_read_en_o  (imem_read_en),
        .dmem_addr_o     (dmem_addr),
        .dmem_read_en_o  (dmem_read_en),
        .dmem_write_en_o (dmem_write_en),
        .dmem_bw_o       (dmem_bw),
        .gpio_sel_o      (gpio_sel),
        .uart_sel_o      (uart_sel),
        .periph_we_o     (periph_we),
        .region_sel_o    (region_sel)
    );

    IMEM_equipe41 u_imem (
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    DMEM #(.WORDS(2048)) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

    GPIO_equipe41 u_gpio (
        .clk     (clk),
        .rst_n   (rst_n),
        .sel_i   (gpio_sel),
        .we_i    (periph_we),
        .addr_i  (lsu_mem_addr[3:2]),
        .wdata_i (lsu_mem_data),
        .rdata_o (gpio_rdata),
        .gpio_in (gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe (gpio_oe)
    );

    UART_equipe41 #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) u_uart (
        .clk    (clk),
        .rst_n  (rst_n),
        .sel_i  (uart_sel),
        .we_i   (periph_we),
        .addr_i (lsu_mem_addr[3:2]),
        .wdata_i(lsu_mem_data),
        .rdata_o(uart_rdata),
        .rx_i   (uart_rx_i),
        .tx_o   (uart_tx_o)
    );

endmodule

// ============================================================================
// AddressDecoder_SoC_equipe41 - Stage 2 decoder + GPIO/UART windows
// ============================================================================
module AddressDecoder_SoC_equipe41 (
    input  wire [31:0] addr_i,
    input  wire        read_enable_i,
    input  wire        write_enable_i,
    input  wire [3:0]  bw_i,

    output reg  [31:0] imem_addr_o,
    output reg         imem_read_en_o,
    output reg  [31:0] dmem_addr_o,
    output reg         dmem_read_en_o,
    output reg         dmem_write_en_o,
    output reg  [3:0]  dmem_bw_o,

    output reg         gpio_sel_o,
    output reg         uart_sel_o,
    output reg         periph_we_o,
    output reg  [1:0]  region_sel_o     // 0 IMEM, 1 DMEM, 2 GPIO, 3 UART
);
    localparam IMEM_BASE = 32'h0040_0000, IMEM_HIGH = 32'h007F_FFFF;
    localparam DMEM_BASE = 32'h1001_0000, DMEM_HIGH = 32'h1001_1FFF;
    localparam GPIO_BASE = 32'hF000_0000, GPIO_HIGH = 32'hF000_0FFF;
    localparam UART_BASE = 32'hF100_0000, UART_HIGH = 32'hF100_0FFF;

    always @(*) begin
        imem_addr_o     = 32'h0;
        imem_read_en_o  = 1'b0;
        dmem_addr_o     = 32'h0;
        dmem_read_en_o  = 1'b0;
        dmem_write_en_o = 1'b0;
        dmem_bw_o       = 4'b0000;
        gpio_sel_o      = 1'b0;
        uart_sel_o      = 1'b0;
        periph_we_o     = 1'b0;
        region_sel_o    = 2'd0;

        if (addr_i >= IMEM_BASE && addr_i <= IMEM_HIGH) begin
            imem_addr_o    = addr_i - IMEM_BASE;
            imem_read_en_o = read_enable_i;
            region_sel_o   = 2'd0;
        end else if (addr_i >= DMEM_BASE && addr_i <= DMEM_HIGH) begin
            dmem_addr_o     = addr_i - DMEM_BASE;
            dmem_read_en_o  = read_enable_i;
            dmem_write_en_o = write_enable_i;
            dmem_bw_o       = bw_i;
            region_sel_o    = 2'd1;
        end else if (addr_i >= GPIO_BASE && addr_i <= GPIO_HIGH) begin
            gpio_sel_o   = 1'b1;
            periph_we_o  = write_enable_i;
            region_sel_o = 2'd2;
        end else if (addr_i >= UART_BASE && addr_i <= UART_HIGH) begin
            uart_sel_o   = 1'b1;
            periph_we_o  = write_enable_i;
            region_sel_o = 2'd3;
        end
    end
endmodule
