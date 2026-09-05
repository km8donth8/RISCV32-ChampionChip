module PC_Target_Align (
    input  wire [31:0] alu_out,
    output wire [31:0] pc_target
);

assign pc_target = {alu_out[31:1], 1'b0};

endmodule