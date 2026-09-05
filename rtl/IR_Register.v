module IR_Register (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ir_write,
    input  wire [31:0] mem_rdata,
    output reg  [31:0] ir
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ir <= 32'h00000000;
    else if (ir_write)
        ir <= mem_rdata;
end

endmodule