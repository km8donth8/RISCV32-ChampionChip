module ALU_OUT_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        alu_write,
    input  wire [31:0] alu_q,
    output reg  [31:0] alu_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        alu_out <= 32'h00000000;
    else if (alu_write)
        alu_out <= alu_q;
end

endmodule