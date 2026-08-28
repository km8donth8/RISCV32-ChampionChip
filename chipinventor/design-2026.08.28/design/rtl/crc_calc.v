`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 20:30:06
// Design Name: 
// Module Name: crc_calc
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

module crc_calc #(
    parameter [63:0]  POLY       = 64'h8005,
    parameter integer CRC_SIZE   = 16,
    parameter integer DATA_WIDTH = 8,
    parameter integer REF_IN     = 1,
    parameter integer REF_OUT    = 1,
    parameter [63:0]  XOR_OUT    = 64'hFFFF
)(
    input  [CRC_SIZE - 1 : 0]   crc_in,   // Seed or previous CRC result from reg_rs_2
    input  [DATA_WIDTH - 1 : 0] data_i,   // Data payload segment
    output [CRC_SIZE - 1 : 0]   crc_o     // Calculated 16-bit CRC output
);

    // Un-XOR the incoming seed state so output results can chain directly back into crc_in
    wire [CRC_SIZE - 1 : 0] current_state = crc_in ^ XOR_OUT[CRC_SIZE - 1 : 0];

    reg [CRC_SIZE - 1 : 0] crc_next;
    reg [CRC_SIZE - 1 : 0] crc_prev;

    integer i, j;

    assign crc_o = crc_next ^ XOR_OUT[CRC_SIZE - 1 : 0];

    generate
        if (REF_OUT) begin : g_ref_out
            if (REF_IN) begin : g_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[CRC_SIZE - 1] = crc_prev[0] ^ data_i[i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j] ^ crc_prev[0] ^ data_i[i];
                            else
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j];
                        end
                        crc_prev = crc_next;
                    end
                end
            end else begin : g_n_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[0] = crc_prev[CRC_SIZE - 1] ^ data_i[i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[j] = crc_prev[j - 1] ^ crc_prev[CRC_SIZE - 1] ^ data_i[i];
                            else
                                crc_next[j] = crc_prev[j - 1];
                        end
                        crc_prev = crc_next;
                    end
                end
            end
        end else begin : g_n_ref_out
            if (REF_IN) begin : g_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[CRC_SIZE - 1] = crc_prev[0] ^ data_i[DATA_WIDTH - 1 - i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j] ^ crc_prev[0] ^ data_i[DATA_WIDTH - 1 - i];
                            else
                                crc_next[CRC_SIZE - 1 - j] = crc_prev[CRC_SIZE - j];
                        end
                        crc_prev = crc_next;
                    end
                end
            end else begin : g_n_ref_in
                always @(*) begin
                    crc_next = current_state;
                    crc_prev = current_state;
                    for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                        crc_next[0] = crc_prev[CRC_SIZE - 1] ^ data_i[DATA_WIDTH - 1 - i];
                        for (j = 1; j < CRC_SIZE; j = j + 1) begin
                            if (POLY[j])
                                crc_next[j] = crc_prev[j - 1] ^ crc_prev[CRC_SIZE - 1] ^ data_i[DATA_WIDTH - 1 - i];
                            else
                                crc_next[j] = crc_prev[j - 1];
                        end
                        crc_prev = crc_next;
                    end
                end
            end
        end
    endgenerate

endmodule