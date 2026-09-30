// ============================================================================
// BLOCK: GPIO_equipe41   (ChipInventor block - Stage 3, Team 41)
// PIN Controller, ChampionCHIP Block Guide section 1
//
// Registers (base 0xF0000000, word aligned):
//   0x0 DATAOUT [7:0] RW  level driven on output pins
//   0x4 DATAIN  [7:0] R   level read on input pins (output pins read 0)
//   0x8 DATADIR [7:0] RW  1 = output, 0 = input (reset: all inputs)
//   any other offset in the window is reserved (reads 0, writes ignored)
//
// Connect:  sel_i   <- MemoryUnit_SoC_equipe41.gpio_sel
//           we_i    <- MemoryUnit_SoC_equipe41.periph_we
//           addr_i  <- MemoryUnit_SoC_equipe41.periph_addr
//           wdata_i <- MemoryUnit_SoC_equipe41.periph_wdata
//           rdata_o -> MemoryUnit_SoC_equipe41.gpio_rdata
//           gpio_in / gpio_out / gpio_oe <-> top-level pins
// ============================================================================
module GPIO_equipe41 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sel_i,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    input  wire [7:0]  gpio_in,
    output wire [7:0]  gpio_out,
    output wire [7:0]  gpio_oe
);

    reg  [7:0] r_dataout;
    reg  [7:0] r_datadir;
    reg  [7:0] r_sync1;
    reg  [7:0] r_sync2;
    wire [9:0] reg_idx = addr_i[11:2];    // word index inside the 4 KB window

    // register writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_dataout <= 8'h00;
            r_datadir <= 8'h00;
        end else if (sel_i && we_i) begin
            if (reg_idx == 10'd0) r_dataout <= wdata_i[7:0];
            if (reg_idx == 10'd2) r_datadir <= wdata_i[7:0];
        end
    end

    // 2-flip-flop input synchroniser
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_sync1 <= 8'h00;
            r_sync2 <= 8'h00;
        end else begin
            r_sync1 <= gpio_in;
            r_sync2 <= r_sync1;
        end
    end

    wire [7:0] w_datain = r_sync2 & ~r_datadir;   // input buffer only on inputs

    assign gpio_oe  = r_datadir;                   // output buffer enable
    assign gpio_out = r_dataout & r_datadir;       // driven only on outputs

    // register reads
    always @(*) begin
        rdata_o = 32'h00000000;
        if (sel_i) begin
            case (reg_idx)
                10'd0:   rdata_o = {24'h000000, r_dataout};
                10'd1:   rdata_o = {24'h000000, w_datain};
                10'd2:   rdata_o = {24'h000000, r_datadir};
                default: rdata_o = 32'h00000000;
            endcase
        end
    end

endmodule
