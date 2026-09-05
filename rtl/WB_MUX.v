module WB_MUX (
    input  wire [31:0] alu_out,
    input  wire [31:0] mdr,
    input  wire [31:0] mult_result,
    input  wire [31:0] crc_result,
    input  wire [31:0] pc_plus4,
    input  wire [2:0]  wb_sel,

    output reg  [31:0] wb_data
);

always @(*) begin
    case (wb_sel)
        3'd0: wb_data = alu_out;
        3'd1: wb_data = mdr;
        3'd2: wb_data = mult_result;
        3'd3: wb_data = crc_result;
        3'd4: wb_data = pc_plus4;
        default: wb_data = 32'h00000000;
    endcase
end

endmodule