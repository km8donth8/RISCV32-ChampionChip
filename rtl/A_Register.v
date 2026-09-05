module A_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ab_write,
    input  wire [31:0] rs1_data,
    output reg  [31:0] A
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        A <= 32'h00000000;
    else if (ab_write)
        A <= rs1_data;
end

endmodule