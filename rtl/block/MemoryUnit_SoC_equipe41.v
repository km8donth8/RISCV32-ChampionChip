// ============================================================================
// BLOCK: MemoryUnit_Soc_TG_equipe41   (ChipInventor block - Stage 3, Team 41)
// IMEM FIRMWARE IN THIS FILE: TollGuard application firmware
//
// Replaces the Stage 2 block MemoryUnit_ff_equipe41. The six core-side ports
// are IDENTICAL to Stage 2, so connect them to the same wires as before:
//   core_data_i    -> IR_Register.mem_rdata and MDR_Register.mem_rdata
//   core_address_o <- Memory_Address_MUX.mem_addr
//   core_data_o    <- B_Register.B
//   read_enable    <- ControlUnit_equipe41.o_mem_read
//   write_enable   <- ControlUnit_equipe41.o_mem_write
//   op_size_o      <- ControlUnit_equipe41.o_lsu_op
// New peripheral bus ports (to GPIO_equipe41 and UART_equipe41):
//   periph_addr, periph_wdata, periph_we  -> both GPIO and UART
//   gpio_sel -> GPIO.sel_i      uart_sel -> UART.sel_i
//   gpio_rdata <- GPIO.rdata_o  uart_rdata <- UART.rdata_o
//
// Memory map: IMEM 0x00400000-0x007FFFFF | DMEM 0x10010000-0x10011FFF
//             GPIO 0xF0000000-0xF0000FFF | UART 0xF1000000-0xF1000FFF
//
// To change firmware: replace the lines between "FIRMWARE START" and
// "FIRMWARE END" with the contents of the new firmware.txt.
// ============================================================================
module MemoryUnit_Soc_TG_equipe41 (
    input  wire        clk,
    // core side (same as Stage 2)
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,
    input  wire [31:0] core_address_o,
    output wire [31:0] core_data_i,
    // peripheral bus (new in Stage 3)
    output wire [31:0] periph_addr,
    output wire [31:0] periph_wdata,
    output wire        periph_we,
    output wire        gpio_sel,
    output wire        uart_sel,
    input  wire [31:0] gpio_rdata,
    input  wire [31:0] uart_rdata
);

    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;
    wire [31:0] imem_addr, dmem_addr, imem_out, dmem_out;
    wire        imem_read_en, dmem_read_en, dmem_write_en;
    wire [3:0]  dmem_bw;
    wire [1:0]  region_sel;              // 0 IMEM, 1 DMEM, 2 GPIO, 3 UART
    reg  [31:0] mux_mem_data_out;
    reg         dmem_sel_q;

    assign periph_addr  = lsu_mem_addr;
    assign periph_wdata = lsu_mem_data;

    // DMEM answers one cycle after the request (as in Stage 2)
    always @(posedge clk) dmem_sel_q <= (region_sel == 2'd1);

    always @(*) begin
        case (region_sel)
            2'd1:    mux_mem_data_out = dmem_sel_q ? dmem_out : 32'h00000000;
            2'd2:    mux_mem_data_out = gpio_rdata;
            2'd3:    mux_mem_data_out = uart_rdata;
            default: mux_mem_data_out = imem_out;
        endcase
    end

    LSU_TG_equipe41 u_lsu (
        .core_data_o   (core_data_o),
        .core_address_o(core_address_o),
        .op_size_o     (op_size_o),
        .core_data_i   (core_data_i),
        .mem_address_i (lsu_mem_addr),
        .mem_data_i    (lsu_mem_data),
        .byte_write_i  (lsu_byte_write),
        .mem_data_o    (mux_mem_data_out)
    );

    AddressDecoder_TG_equipe41 u_dec (
        .addr_i         (lsu_mem_addr),
        .read_enable_i  (read_enable),
        .write_enable_i (write_enable),
        .bw_i           (lsu_byte_write),
        .imem_addr_o    (imem_addr),
        .imem_read_en_o (imem_read_en),
        .dmem_addr_o    (dmem_addr),
        .dmem_read_en_o (dmem_read_en),
        .dmem_write_en_o(dmem_write_en),
        .dmem_bw_o      (dmem_bw),
        .gpio_sel_o     (gpio_sel),
        .uart_sel_o     (uart_sel),
        .periph_we_o    (periph_we),
        .region_sel_o   (region_sel)
    );

    IMEM_TG_equipe41 u_imem (
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    DMEM_TG_equipe41 #(.WORDS(2048)) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

endmodule

// ----------------------------------------------------------------------------
// Address decoder: Stage 2 IMEM/DMEM windows + GPIO and UART windows
// ----------------------------------------------------------------------------
module AddressDecoder_TG_equipe41 (
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
    output reg  [1:0]  region_sel_o
);
    always @(*) begin
        imem_addr_o     = 32'h00000000;
        imem_read_en_o  = 1'b0;
        dmem_addr_o     = 32'h00000000;
        dmem_read_en_o  = 1'b0;
        dmem_write_en_o = 1'b0;
        dmem_bw_o       = 4'b0000;
        gpio_sel_o      = 1'b0;
        uart_sel_o      = 1'b0;
        periph_we_o     = 1'b0;
        region_sel_o    = 2'd0;
        if (addr_i >= 32'h00400000 && addr_i <= 32'h007FFFFF) begin
            imem_addr_o    = addr_i - 32'h00400000;
            imem_read_en_o = read_enable_i;
            region_sel_o   = 2'd0;
        end else if (addr_i >= 32'h10010000 && addr_i <= 32'h10011FFF) begin
            dmem_addr_o     = addr_i - 32'h10010000;
            dmem_read_en_o  = read_enable_i;
            dmem_write_en_o = write_enable_i;
            dmem_bw_o       = bw_i;
            region_sel_o    = 2'd1;
        end else if (addr_i >= 32'hF0000000 && addr_i <= 32'hF0000FFF) begin
            gpio_sel_o   = 1'b1;
            periph_we_o  = write_enable_i;
            region_sel_o = 2'd2;
        end else if (addr_i >= 32'hF1000000 && addr_i <= 32'hF1000FFF) begin
            uart_sel_o   = 1'b1;
            periph_we_o  = write_enable_i;
            region_sel_o = 2'd3;
        end
    end
endmodule

// ----------------------------------------------------------------------------
// IMEM: combinational ROM. Lines are pasted verbatim from firmware.txt.
// ----------------------------------------------------------------------------
module IMEM_TG_equipe41 (
    input  wire [31:0] imem_addr,          // decoder-relative address
    input  wire        read_enable,
    output wire [31:0] imem_output
);
    wire [31:0] i_Address = imem_addr + 32'h00400000;
    reg  [31:0] r_Instruction;

    always @(*) begin
        case (i_Address)
            // ===== FIRMWARE START (TollGuard application firmware, 113 words) =====
            32'h00400000: r_Instruction = 32'hF0000437;
            32'h00400004: r_Instruction = 32'hF10004B7;
            32'h00400008: r_Instruction = 32'h0F000293;
            32'h0040000C: r_Instruction = 32'h00542423;
            32'h00400010: r_Instruction = 32'h0004A423;
            32'h00400014: r_Instruction = 32'h08000293;
            32'h00400018: r_Instruction = 32'h00542023;
            32'h0040001C: r_Instruction = 32'h00442283;
            32'h00400020: r_Instruction = 32'h0082F293;
            32'h00400024: r_Instruction = 32'hFE028CE3;
            32'h00400028: r_Instruction = 32'h00442903;
            32'h0040002C: r_Instruction = 32'h00042023;
            32'h00400030: r_Instruction = 32'h000109B7;
            32'h00400034: r_Instruction = 32'hFFF98993;
            32'h00400038: r_Instruction = 32'h00000A13;
            32'h0040003C: r_Instruction = 32'h00000B13;
            32'h00400040: r_Instruction = 32'h02000B93;
            32'h00400044: r_Instruction = 32'h124000EF;
            32'h00400048: r_Instruction = 32'h813509B3;
            32'h0040004C: r_Instruction = 32'h01651533;
            32'h00400050: r_Instruction = 32'h00AA6A33;
            32'h00400054: r_Instruction = 32'h008B0B13;
            32'h00400058: r_Instruction = 32'hFF7B16E3;
            32'h0040005C: r_Instruction = 32'h10C000EF;
            32'h00400060: r_Instruction = 32'h813509B3;
            32'h00400064: r_Instruction = 32'h00050A93;
            32'h00400068: r_Instruction = 32'h100000EF;
            32'h0040006C: r_Instruction = 32'h813509B3;
            32'h00400070: r_Instruction = 32'h00851513;
            32'h00400074: r_Instruction = 32'h00AAEAB3;
            32'h00400078: r_Instruction = 32'h0F0000EF;
            32'h0040007C: r_Instruction = 32'h00050B93;
            32'h00400080: r_Instruction = 32'h0E8000EF;
            32'h00400084: r_Instruction = 32'h00851513;
            32'h00400088: r_Instruction = 32'h00ABEBB3;
            32'h0040008C: r_Instruction = 32'h07799A63;
            32'h00400090: r_Instruction = 32'h3E800293;
            32'h00400094: r_Instruction = 32'h0752EA63;
            32'h00400098: r_Instruction = 32'h00397293;
            32'h0040009C: r_Instruction = 32'h00229293;
            32'h004000A0: r_Instruction = 32'h00000317;
            32'h004000A4: r_Instruction = 32'h10430313;
            32'h004000A8: r_Instruction = 32'h00530333;
            32'h004000AC: r_Instruction = 32'h00032383;
            32'h004000B0: r_Instruction = 32'h01032E03;
            32'h004000B4: r_Instruction = 32'h035E0E33;
            32'h004000B8: r_Instruction = 32'h01C385B3;
            32'h004000BC: r_Instruction = 32'h00497293;
            32'h004000C0: r_Instruction = 32'h00028E63;
            32'h004000C4: r_Instruction = 32'h000142B7;
            32'h004000C8: r_Instruction = 32'h02558333;
            32'h004000CC: r_Instruction = 32'h0255B3B3;
            32'h004000D0: r_Instruction = 32'h01035313;
            32'h004000D4: r_Instruction = 32'h01039393;
            32'h004000D8: r_Instruction = 32'h007365B3;
            32'h004000DC: r_Instruction = 32'h00BA6A63;
            32'h004000E0: r_Instruction = 32'h40BA0633;
            32'h004000E4: r_Instruction = 32'h00000513;
            32'h004000E8: r_Instruction = 32'h01000693;
            32'h004000EC: r_Instruction = 32'h02C0006F;
            32'h004000F0: r_Instruction = 32'h000A0613;
            32'h004000F4: r_Instruction = 32'h00100513;
            32'h004000F8: r_Instruction = 32'h02000693;
            32'h004000FC: r_Instruction = 32'h01C0006F;
            32'h00400100: r_Instruction = 32'h00200513;
            32'h00400104: r_Instruction = 32'h0080006F;
            32'h00400108: r_Instruction = 32'h00300513;
            32'h0040010C: r_Instruction = 32'h00000593;
            32'h00400110: r_Instruction = 32'h00000613;
            32'h00400114: r_Instruction = 32'h04000693;
            32'h00400118: r_Instruction = 32'h00D42023;
            32'h0040011C: r_Instruction = 32'h00058C13;
            32'h00400120: r_Instruction = 32'h00060C93;
            32'h00400124: r_Instruction = 32'h060000EF;
            32'h00400128: r_Instruction = 32'h0FFC7513;
            32'h0040012C: r_Instruction = 32'h058000EF;
            32'h00400130: r_Instruction = 32'h008C5513;
            32'h00400134: r_Instruction = 32'h0FF57513;
            32'h00400138: r_Instruction = 32'h04C000EF;
            32'h0040013C: r_Instruction = 32'h00000B13;
            32'h00400140: r_Instruction = 32'h02000B93;
            32'h00400144: r_Instruction = 32'h016CD533;
            32'h00400148: r_Instruction = 32'h0FF57513;
            32'h0040014C: r_Instruction = 32'h038000EF;
            32'h00400150: r_Instruction = 32'h008B0B13;
            32'h00400154: r_Instruction = 32'hFF7B18E3;
            32'h00400158: r_Instruction = 32'h00442283;
            32'h0040015C: r_Instruction = 32'h0082F293;
            32'h00400160: r_Instruction = 32'hFE029CE3;
            32'h00400164: r_Instruction = 32'hEB1FF06F;
            32'h00400168: r_Instruction = 32'h0084A283;
            32'h0040016C: r_Instruction = 32'h0022F293;
            32'h00400170: r_Instruction = 32'hFE028CE3;
            32'h00400174: r_Instruction = 32'h0004A423;
            32'h00400178: r_Instruction = 32'h0044A503;
            32'h0040017C: r_Instruction = 32'h0FF57513;
            32'h00400180: r_Instruction = 32'h00008067;
            32'h00400184: r_Instruction = 32'h0084A283;
            32'h00400188: r_Instruction = 32'h0042F293;
            32'h0040018C: r_Instruction = 32'hFE028CE3;
            32'h00400190: r_Instruction = 32'h00A4A023;
            32'h00400194: r_Instruction = 32'h0084A303;
            32'h00400198: r_Instruction = 32'h00136313;
            32'h0040019C: r_Instruction = 32'h0064A423;
            32'h004001A0: r_Instruction = 32'h00008067;
            32'h004001A4: r_Instruction = 32'h00000032;
            32'h004001A8: r_Instruction = 32'h00000064;
            32'h004001AC: r_Instruction = 32'h00000096;
            32'h004001B0: r_Instruction = 32'h0000001E;
            32'h004001B4: r_Instruction = 32'h0000000C;
            32'h004001B8: r_Instruction = 32'h00000018;
            32'h004001BC: r_Instruction = 32'h00000024;
            32'h004001C0: r_Instruction = 32'h00000006;
            // ===== FIRMWARE END =====
            default: r_Instruction = 32'h00000000;
        endcase
    end

    assign imem_output = read_enable ? r_Instruction : 32'h00000000;
endmodule

// ----------------------------------------------------------------------------
// LSU and DMEM: Stage 2 logic, renamed so they cannot clash with the
// Stage 2 MemoryUnit_ff_equipe41 block if it is still in the project.
// ----------------------------------------------------------------------------
module LSU_TG_equipe41(
    // RISC-V Core Interface
    input  wire [31:0] core_data_o,     // rs2 data for stores
    input  wire [31:0] core_address_o,  // Target memory address
    input  wire [2:0]  op_size_o,       // LSU operation code
    output reg  [31:0] core_data_i,     // rd formatted data for loads

    // Address Decoder Interface
    output reg  [31:0] mem_address_i,   // Full 32-bit address passed to Decoder
    output reg  [31:0] mem_data_i,      // Lane-shifted store data
    output reg  [3:0]  byte_write_i,    // 4-bit byte-write mask
    input  wire [31:0] mem_data_o       // 32-bit word read from memory
);

    localparam c_LW  = 3'b000;
    localparam c_LH  = 3'b001;
    localparam c_LB  = 3'b010;
    localparam c_LHU = 3'b011;
    localparam c_LBU = 3'b100;
    localparam c_SW  = 3'b101;
    localparam c_SH  = 3'b110;
    localparam c_SB  = 3'b111;

    wire [1:0] offset = core_address_o[1:0];

    // Select target byte from memory word based on offset
    reg [7:0] selected_byte;
    always @(*) begin
        case(offset)
            2'b00: selected_byte = mem_data_o[7:0];
            2'b01: selected_byte = mem_data_o[15:8];
            2'b10: selected_byte = mem_data_o[23:16];
            2'b11: selected_byte = mem_data_o[31:24];
        endcase
    end

    // Select target half-word from memory word based on offset
    reg [15:0] selected_half;
    always @(*) begin
        case(offset[1])
            1'b0: selected_half = mem_data_o[15:0];
            1'b1: selected_half = mem_data_o[31:16];
        endcase
    end

    // 1. Address Passthrough
    always @(*) begin
        mem_address_i = core_address_o;
    end

    // 2. Store Data Alignment & Byte Write Generation
    always @(*) begin
        case(op_size_o)
            c_SW: begin
                byte_write_i = 4'b1111;
                mem_data_i   = core_data_o;
            end
            c_SH: begin
                case(offset[1])
                    1'b0: begin
                        byte_write_i = 4'b0011;
                        mem_data_i   = {16'h0000, core_data_o[15:0]};
                    end
                    1'b1: begin
                        byte_write_i = 4'b1100;
                        mem_data_i   = {core_data_o[15:0], 16'h0000};
                    end
                endcase
            end
            c_SB: begin
                case(offset)
                    2'b00: begin
                        byte_write_i = 4'b0001;
                        mem_data_i   = {24'h000000, core_data_o[7:0]};
                    end
                    2'b01: begin
                        byte_write_i = 4'b0010;
                        mem_data_i   = {16'h0000, core_data_o[7:0], 8'h00};
                    end
                    2'b10: begin
                        byte_write_i = 4'b0100;
                        mem_data_i   = {8'h00, core_data_o[7:0], 16'h0000};
                    end
                    2'b11: begin
                        byte_write_i = 4'b1000;
                        mem_data_i   = {core_data_o[7:0], 24'h000000};
                    end
                endcase
            end
            default: begin
                byte_write_i = 4'b0000;
                mem_data_i   = 32'h00000000;
            end
        endcase
    end

    // 3. Load Data Formatting (Sign / Zero Extension)
    always @(*) begin
        case(op_size_o)
            c_LW:  core_data_i = mem_data_o;
            c_LH:  core_data_i = {{16{selected_half[15]}}, selected_half};
            c_LB:  core_data_i = {{24{selected_byte[7]}}, selected_byte};
            c_LHU: core_data_i = {16'h0000, selected_half};
            c_LBU: core_data_i = {24'h000000, selected_byte};
            default: core_data_i = 32'h00000000;
        endcase
    end

endmodule

module DMEM_TG_equipe41 #(
    parameter WORDS = 2048// 8 kB / 4 bytes per word
)(
    input  wire        clk,
    input  wire [31:0] dmem_addr,    // Relative address from decoder
    input  wire [31:0] dmem_data_i,  // Shifted store payload from LSU
    input  wire [3:0]  bw,           // Byte-write mask from decoder
    input  wire        write_enable,
    input  wire        read_enable,
    output reg  [31:0] dmem_output   // Changed from wire to reg
);

    // Memory array: 4 byte lanes per word
    reg [7:0] mem_b0 [0:WORDS-1];
    reg [7:0] mem_b1 [0:WORDS-1];
    reg [7:0] mem_b2 [0:WORDS-1];
    reg [7:0] mem_b3 [0:WORDS-1];

    // Initialize memory to zero to prevent 'x' propagation in simulation
    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1) begin
            mem_b0[i] = 8'h00;
            mem_b1[i] = 8'h00;
            mem_b2[i] = 8'h00;
            mem_b3[i] = 8'h00;
        end
    end

    // Word indexing: Ignore lower 2 offset bits (Range: 0 to 2047)
    localparam ADDR_WIDTH = $clog2(WORDS);
    wire [ADDR_WIDTH-1:0] word_idx = dmem_addr[(ADDR_WIDTH + 1) : 2];

    // Synchronous Write & Read Operations
    always @(posedge clk) begin
        if (write_enable) begin
            if (bw[0]) mem_b0[word_idx] <= dmem_data_i[7:0];
            if (bw[1]) mem_b1[word_idx] <= dmem_data_i[15:8];
            if (bw[2]) mem_b2[word_idx] <= dmem_data_i[23:16];
            if (bw[3]) mem_b3[word_idx] <= dmem_data_i[31:24];
        end

        // Synchronous Read Output
        if (read_enable) begin
            dmem_output <= {mem_b3[word_idx], mem_b2[word_idx], mem_b1[word_idx], mem_b0[word_idx]};
        end else begin
            dmem_output <= 32'h00000000;
        end
    end

endmodule
