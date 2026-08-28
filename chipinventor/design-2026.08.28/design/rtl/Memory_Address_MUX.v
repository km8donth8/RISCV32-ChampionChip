module Memory_Address_MUX (
    input  wire [31:0] pc,
    input  wire [31:0] alu_out,
    input  wire        mem_addr_sel,
    output wire [31:0] mem_addr
);

assign mem_addr = mem_addr_sel ? alu_out : pc;

endmodule