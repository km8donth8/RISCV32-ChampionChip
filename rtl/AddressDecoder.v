`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.08.2026 00:13:47
// Design Name: 
// Module Name: AddressDecoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// module AddressDecoder (
//     input  wire [31:0] addr_i,          // Address from LSU / MUX
//     input  wire        read_enable_i,   // Read signal from Control Unit
//     input  wire        write_enable_i,  // Write signal from Control Unit
//     input  wire [3:0]  bw_i,            // Byte-write mask from LSU

//     output reg  [31:0] imem_addr_o,     // Local address offset for IMEM
//     output reg         imem_read_en_o,  // IMEM read enable
    
//     output reg  [31:0] dmem_addr_o,     // Local address offset for DMEM
//     output reg         dmem_read_en_o,  // DMEM read enable
//     output reg         dmem_write_en_o, // DMEM write enable
//     output reg  [3:0]  dmem_bw_o,       // Byte-write mask forwarded to DMEM
    
//     output reg         addr_decoder_sel // MUX select (0: IMEM, 1: DMEM)
// );

//     // Memory Range Constants
//     localparam IMEM_BASE = 32'h00400000;
//     localparam IMEM_HIGH = 32'h007FFFFF; // 4 MB Range

//     localparam DMEM_BASE = 32'h10010000;
//     localparam DMEM_HIGH = 32'h10011FFF; // 8 kB Range (0x2000 bytes)

//     always @(*) begin
//         // Default Outputs
//         imem_addr_o      = 32'h0;
//         imem_read_en_o   = 1'b0;
//         dmem_addr_o      = 32'h0;
//         dmem_read_en_o   = 1'b0;
//         dmem_write_en_o  = 1'b0;
//         dmem_bw_o        = 4'b0000;
//         addr_decoder_sel = 1'b0;

//         // IMEM Address Decoding
//         if (addr_i >= IMEM_BASE && addr_i <= IMEM_HIGH) begin
//             imem_addr_o      = addr_i - IMEM_BASE; // Map 0x00400000 -> 0x00000000
//             imem_read_en_o   = read_enable_i;
//             addr_decoder_sel = 1'b0;
//         end
//         // DMEM Address Decoding
//         else if (addr_i >= DMEM_BASE && addr_i <= DMEM_HIGH) begin
//             dmem_addr_o      = addr_i - DMEM_BASE; // Map 0x10010000 -> 0x00000000
//             dmem_read_en_o   = read_enable_i;
//             dmem_write_en_o  = write_enable_i;
//             dmem_bw_o        = bw_i;
//             addr_decoder_sel = 1'b1;
//         end
//     end

// endmodule

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