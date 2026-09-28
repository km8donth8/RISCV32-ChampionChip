// LSU and DMEM - unchanged from Stage 2 (rtl/top.v)
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


