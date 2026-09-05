module B_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ab_write,
    input  wire [31:0] rs2_data,
    output reg  [31:0] B
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        B <= 32'h00000000;
    else if (ab_write)
        B <= rs2_data;
end

endmodule