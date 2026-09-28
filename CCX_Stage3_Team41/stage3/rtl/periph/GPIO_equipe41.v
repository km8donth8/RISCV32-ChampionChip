// ============================================================================
// GPIO_equipe41 - PIN Controller (ChampionCHIP Block Guide, section 1)
// Team 41 (Equipe 41) - Stage 3
//
// Memory map (base 0xF0000000, 32-bit aligned, addr[1:0] ignored):
//   0x0000 DATAOUT  [7:0] RW  logic level driven on pins configured as output
//   0x0004 DATAIN   [7:0] R   logic level sampled on pins configured as input
//   0x0008 DATADIR  [7:0] RW  1 = output, 0 = input   (reset: all inputs)
//   bits [31:8] reserved, read as 0
//
// Per-pin structure (replicated 8x):
//   DATADIR[x]=1 -> output buffer enabled (pin = DATAOUT[x]), input isolated
//                   (DATAIN[x] reads 0)
//   DATADIR[x]=0 -> output buffer disabled (high-Z / 0 on split bus),
//                   DATAIN[x] = synchronised external level
//
// The pins are exposed as a split bus (gpio_in / gpio_out / gpio_oe) so the
// block works in simulation, on FPGA fabric (no internal tri-states) and in
// ChipInventor. GPIO_Pads_equipe41 below turns it into a real inout pins_io.
// ============================================================================
module GPIO_equipe41 #(
    parameter NPINS = 8
)(
    input  wire             clk,
    input  wire             rst_n,

    // bus side (from the SoC address decoder)
    input  wire             sel_i,      // address falls in the GPIO window
    input  wire             we_i,       // store strobe (1 cycle)
    input  wire [3:2]       addr_i,     // register offset (word index)
    input  wire [31:0]      wdata_i,
    output reg  [31:0]      rdata_o,    // combinational read data

    // pin side
    input  wire [NPINS-1:0] gpio_in,    // external level on the pins
    output wire [NPINS-1:0] gpio_out,   // value driven by enabled output buffers
    output wire [NPINS-1:0] gpio_oe     // output-buffer enable = DATADIR
);

    localparam OFF_DATAOUT = 2'd0;   // 0x0
    localparam OFF_DATAIN  = 2'd1;   // 0x4
    localparam OFF_DATADIR = 2'd2;   // 0x8

    reg [NPINS-1:0] r_dataout;
    reg [NPINS-1:0] r_datadir;
    reg [NPINS-1:0] r_sync1, r_sync2;   // 2-FF synchroniser for async inputs

    // ---------------- register writes ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_dataout <= {NPINS{1'b0}};
            r_datadir <= {NPINS{1'b0}};
        end else if (sel_i && we_i) begin
            case (addr_i)
                OFF_DATAOUT: r_dataout <= wdata_i[NPINS-1:0];
                OFF_DATADIR: r_datadir <= wdata_i[NPINS-1:0];
                default: ;                       // DATAIN is read-only
            endcase
        end
    end

    // ---------------- input sampling ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_sync1 <= {NPINS{1'b0}};
            r_sync2 <= {NPINS{1'b0}};
        end else begin
            r_sync1 <= gpio_in;
            r_sync2 <= r_sync1;
        end
    end

    // input buffer enabled only when the pin is an input
    wire [NPINS-1:0] w_datain = r_sync2 & ~r_datadir;

    // output buffer enabled only when the pin is an output
    assign gpio_oe  = r_datadir;
    assign gpio_out = r_dataout & r_datadir;

    // ---------------- register reads ----------------
    always @(*) begin
        rdata_o = 32'h0000_0000;
        if (sel_i) begin
            case (addr_i)
                OFF_DATAOUT: rdata_o[NPINS-1:0] = r_dataout;
                OFF_DATAIN:  rdata_o[NPINS-1:0] = w_datain;
                OFF_DATADIR: rdata_o[NPINS-1:0] = r_datadir;
                default:     rdata_o = 32'h0000_0000;
            endcase
        end
    end

endmodule

// ----------------------------------------------------------------------------
// Optional pad wrapper: bidirectional pins_io bus with tri-state buffers,
// exactly as drawn in Block Guide Figure 1 (use for ChipInventor / ASIC pads).
// ----------------------------------------------------------------------------
module GPIO_Pads_equipe41 #(
    parameter NPINS = 8
)(
    inout  wire [NPINS-1:0] pins_io,
    input  wire [NPINS-1:0] gpio_out,
    input  wire [NPINS-1:0] gpio_oe,
    output wire [NPINS-1:0] gpio_in
);
    genvar i;
    generate
        for (i = 0; i < NPINS; i = i + 1) begin : g_pad
            assign pins_io[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;
        end
    endgenerate
    assign gpio_in = pins_io;
endmodule
