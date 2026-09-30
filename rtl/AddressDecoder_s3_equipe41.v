module AddressDecoder_s3_equipe41 (
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
            periph_we_o  = write_enable_i & bw_i[0];   // word regs: lane 0 must be written
            region_sel_o = 2'd2;
        end else if (addr_i >= 32'hF1000000 && addr_i <= 32'hF1000FFF) begin
            uart_sel_o   = 1'b1;
            periph_we_o  = write_enable_i & bw_i[0];   // word regs: lane 0 must be written
            region_sel_o = 2'd3;
        end
    end
endmodule
