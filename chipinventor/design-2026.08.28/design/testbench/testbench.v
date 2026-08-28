module testbench(); 

reg clk = 0;
reg rst_n = 0;
wire o_halt;


always 
 #1 clk = ~clk;

 top ai45( .clk(clk), .rst_n(rst_n), .o_halt(o_halt)); 


initial begin 

	#1000 $finish; 

end 



initial begin 

	$dumpfile("testbench.vcd");

	$dumpvars(0,testbench);

end 



endmodule 

