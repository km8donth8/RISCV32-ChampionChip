module MemoryUnit(
    input  wire        clk,
    input  wire        write_enable,
    input  wire        read_enable,
    input  wire [2:0]  op_size_o,
    input  wire [31:0] core_data_o,     // rs2 data from core for stores
    input  wire [31:0] core_address_o,  // Memory address from core
    output wire [31:0] core_data_i      // Formatted load data to core
);

    // -------------------------------------------------------------------------
    // Internal Wires for Interconnects
    // -------------------------------------------------------------------------
    wire [31:0] lsu_mem_addr;
    wire [31:0] lsu_mem_data;
    wire [3:0]  lsu_byte_write;

    wire [31:0] imem_addr;
    wire        imem_read_en;

    wire [31:0] dmem_addr;
    wire        dmem_read_en;
    wire        dmem_write_en;
    wire [3:0]  dmem_bw;

    wire        addr_decoder_sel;
    wire [31:0] imem_out;
    wire [31:0] dmem_out;
    wire [31:0] mux_mem_data_out;

    // Register decoder select to match the 1-cycle memory read latency
    reg addr_decoder_sel_q;
    always @(posedge clk) begin
        addr_decoder_sel_q <= addr_decoder_sel;
    end

    // -------------------------------------------------------------------------
    // 1. Read Data MUX (Mixed Latency: Async IMEM vs. Sync DMEM)
    // -------------------------------------------------------------------------
    // - If current cycle is accessing DMEM (addr_decoder_sel = 1), wait for 
    //   addr_decoder_sel_q to select dmem_out on the next cycle.
    // - If accessing IMEM (addr_decoder_sel = 0), route imem_out combinationally.
    // -------------------------------------------------------------------------
    assign mux_mem_data_out = (addr_decoder_sel) ? ((addr_decoder_sel_q) ? dmem_out : 32'h00000000) 
                                                  : imem_out;

    // -------------------------------------------------------------------------
    // 2. Load-Store Unit (LSU) Instance
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // 3. Address Decoder Instance
    // -------------------------------------------------------------------------
    AddressDecoder u_addr_decoder (
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

        .addr_decoder_sel(addr_decoder_sel)
    );

    // -------------------------------------------------------------------------
    // 4. Instruction Memory (IMEM) Instance
    // -------------------------------------------------------------------------
    IMEM #(
      .WORDS(1048576)
    ) u_imem (
        .clk        (clk),
        .imem_addr  (imem_addr),
        .read_enable(imem_read_en),
        .imem_output(imem_out)
    );

    // -------------------------------------------------------------------------
    // 5. Data Memory (DMEM) Instance
    // -------------------------------------------------------------------------
    DMEM #(
      .WORDS(2048)
    ) u_dmem (
        .clk         (clk),
        .dmem_addr   (dmem_addr),
        .dmem_data_i (lsu_mem_data),
        .bw          (dmem_bw),
        .write_enable(dmem_write_en),
        .read_enable (dmem_read_en),
        .dmem_output (dmem_out)
    );

endmodule

module LSU(
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

module AddressDecoder (
    input  wire [31:0] addr_i,          // Address from LSU / MUX
    input  wire        read_enable_i,   // Read signal from Control Unit
    input  wire        write_enable_i,  // Write signal from Control Unit
    input  wire [3:0]  bw_i,            // Byte-write mask from LSU

    output reg  [31:0] imem_addr_o,     // Local address offset for IMEM
    output reg         imem_read_en_o,  // IMEM read enable
    
    output reg  [31:0] dmem_addr_o,     // Local address offset for DMEM
    output reg         dmem_read_en_o,  // DMEM read enable
    output reg         dmem_write_en_o, // DMEM write enable
    output reg  [3:0]  dmem_bw_o,       // Byte-write mask forwarded to DMEM
    
    output reg         addr_decoder_sel // MUX select (0: IMEM, 1: DMEM)
);

    // Memory Range Constants
    localparam IMEM_BASE = 32'h00400000;
    localparam IMEM_HIGH = 32'h007FFFFF; // 4 MB Range

    localparam DMEM_BASE = 32'h10010000;
    localparam DMEM_HIGH = 32'h10011FFF; // 8 kB Range (0x2000 bytes)

    always @(*) begin
        // Default Outputs
        imem_addr_o      = 32'h0;
        imem_read_en_o   = 1'b0;
        dmem_addr_o      = 32'h0;
        dmem_read_en_o   = 1'b0;
        dmem_write_en_o  = 1'b0;
        dmem_bw_o        = 4'b0000;
        addr_decoder_sel = 1'b0;

        // IMEM Address Decoding
        if (addr_i >= IMEM_BASE && addr_i <= IMEM_HIGH) begin
            imem_addr_o      = addr_i - IMEM_BASE; // Map 0x00400000 -> 0x00000000
            imem_read_en_o   = read_enable_i;
            addr_decoder_sel = 1'b0;
        end
        // DMEM Address Decoding
        else if (addr_i >= DMEM_BASE && addr_i <= DMEM_HIGH) begin
            dmem_addr_o      = addr_i - DMEM_BASE; // Map 0x10010000 -> 0x00000000
            dmem_read_en_o   = read_enable_i;
            dmem_write_en_o  = write_enable_i;
            dmem_bw_o        = bw_i;
            addr_decoder_sel = 1'b1;
        end
    end

endmodule

module DMEM #(
    parameter WORDS = 4// 8 kB / 4 bytes per word
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
module IMEM #(
    parameter WORDS = 1048576 // 4 MB / 4 bytes per word (0x00400000 to 0x007FFFFC)
)(
    input  wire        clk,
    input  wire [31:0] imem_addr,   // Relative address from decoder (0x00000000 - 0x003FFFFC)
    input  wire        read_enable,
    output wire [31:0] imem_output
);

    // -----------------------------------------------------------------------
    // RISC-V test firmware held in decode logic.
    //
    // Replaces $readmemh("firmware.hex") so no external file is required -
    // this elaborates in ChipInventor and synthesises directly.
    //
    // Addresses below are RELATIVE: the AddressDecoder already subtracts
    // IMEM_BASE, so program address 0x00400000 appears here as 0x00000000.
    // Unmapped addresses return 0x00000000, matching the behaviour of an
    // uninitialised memory array.
    // -----------------------------------------------------------------------
    reg [31:0] instruction;

    always @(*) begin
        case (imem_addr)
            32'h00000000: instruction = 32'h100100B7; // lui  x1, 0x10010    ; x1 = DMEM base
            32'h00000004: instruction = 32'hDEADB137; // lui  x2, 0xDEADB    ; x2 upper
            32'h00000008: instruction = 32'hEEF10113; // addi x2, x2, -273   ; x2 = 0xDEADBEEF
            32'h0000000C: instruction = 32'h0020A023; // sw   x2, 0(x1)
            32'h00000010: instruction = 32'h00209223; // sh   x2, 4(x1)
            32'h00000014: instruction = 32'h00208323; // sb   x2, 6(x1)
            32'h00000018: instruction = 32'h0000A183; // lw   x3, 0(x1)      ; expect 0xDEADBEEF
            32'h0000001C: instruction = 32'h0060C203; // lbu  x4, 6(x1)      ; expect 0x000000EF
            32'h00000020: instruction = 32'h004002B7; // lui  x5, 0x00400    ; x5 = IMEM base
            32'h00000024: instruction = 32'h1002A303; // lw   x6, 256(x5)    ; expect 0x0000000A
            32'h00000028: instruction = 32'h0000006F; // jal  x0, 0          ; spin forever

            32'h00000100: instruction = 32'h0000000A; // constant data at 0x00400100

            default:      instruction = 32'h00000000;
        endcase
    end

    assign imem_output = (read_enable) ? instruction : 32'h00000000;

endmodule
