module MDR_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mdr_write,
    input  wire [31:0] mem_rdata,
    output reg  [31:0] mdr
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        mdr <= 32'h00000000;
    else if (mdr_write)
        mdr <= mem_rdata;
end

endmodule