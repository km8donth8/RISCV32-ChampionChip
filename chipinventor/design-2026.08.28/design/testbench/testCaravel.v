 entrou module top ( ---( 
 module 
  --- 
  
   input wire clk, ---inputwireclk, 
 clk 
   input wire rst_n, ---inputwirerst_n, 
 rst_n 
   output wire o_halt ---outputwireo_halt 
 o_halt 
  --- 
  
 ); --- 
 ); 
  --- 
  
 //Internal Wires --- 
 //Internal 
  wire [31:0] w_1; ---[31:0]w_1; 
  
  wire w_2; ---w_2; 
  
  wire w_3; ---w_3; 
  
  wire [31:0] w_4; ---[31:0]w_4; 
  
  wire [31:0] w_6; ---[31:0]w_6; 
  
  wire [31:0] w_7; ---[31:0]w_7; 
  
  wire w_8; ---w_8; 
  
  wire [31:0] w_9; ---[31:0]w_9; 
  
  wire w_10; ---w_10; 
  
  wire w_11; ---w_11; 
  
  wire [2:0] w_12; ---[2:0]w_12; 
  
  wire [31:0] w_13; ---[31:0]w_13; 
  
  wire [31:0] w_14; ---[31:0]w_14; 
  
  wire w_16; ---w_16; 
  
  wire [31:0] w_17; ---[31:0]w_17; 
  
  wire [31:0] w_20; ---[31:0]w_20; 
  
  wire w_21; ---w_21; 
  
  wire w_22; ---w_22; 
  
  wire w_23; ---w_23; 
  
  wire w_25; ---w_25; 
  
  wire w_26; ---w_26; 
  
  wire [2:0] w_27; ---[2:0]w_27; 
  
  wire [3:0] w_28; ---[3:0]w_28; 
  
  wire w_29; ---w_29; 
  
  wire w_30; ---w_30; 
  
  wire [3:0] w_31; ---[3:0]w_31; 
  
  wire [1:0] w_32; ---[1:0]w_32; 
  
  wire [2:0] w_33; ---[2:0]w_33; 
  
  wire [31:0] w_34; ---[31:0]w_34; 
  
  wire [31:0] w_35; ---[31:0]w_35; 
  
  wire [31:0] w_36; ---[31:0]w_36; 
  
  wire [31:0] w_37; ---[31:0]w_37; 
  
  wire [31:0] w_38; ---[31:0]w_38; 
  
  wire [31:0] w_45; ---[31:0]w_45; 
  
  wire [31:0] w_46; ---[31:0]w_46; 
  
  wire [31:0] w_50; ---[31:0]w_50; 
  
  --- 
  
 //Instances of Modules ---Modules 
 //Instances 
 ProgramCounter blk3198_1 ( ---( 
 ProgramCounter 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .i_ALU_output (w_1), --- 
  
          .PC_sel (w_2), --- 
  
          .PC_write (w_3), --- 
  
          .o_PC_Output (w_4), --- 
  
          .o_PC_Plus_4 (w_6) --- 
  
      ); --- 
  
  --- 
  
 Memory_Address_MUX blk3208_3 ( ---( 
 Memory_Address_MUX 
          .pc (w_4), --- 
  
          .alu_out (w_7), --- 
  
          .mem_addr_sel (w_8), --- 
  
          .mem_addr (w_9) --- 
  
      ); --- 
  
  --- 
  
 MemoryUnit #(.FIRMWARE("firmware.hex")) blk3196_4 ( ---blk3196_4( 
 MemoryUnit 
          .clk (clk), --- 
  
          .core_address_o (w_9), --- 
  
          .write_enable (w_10), --- 
  
          .read_enable (w_11), --- 
  
          .op_size_o (w_12), --- 
  
          .core_data_o (w_13), --- 
  
          .core_data_i (w_14) --- 
  
      ); --- 
  
  --- 
  
 ALU_OUT_Register blk3205_6 ( ---( 
 ALU_OUT_Register 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .alu_out (w_7), --- 
  
          .alu_write (w_16), --- 
  
          .alu_q (w_17) --- 
  
      ); --- 
  
  --- 
  
 ControlUnit blk3189_7 ( ---( 
 ControlUnit 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .halt (o_halt), --- 
  
          .pc_sel (w_2), --- 
  
          .pc_write (w_3), --- 
  
          .mem_addr_sel (w_8), --- 
  
          .mem_write (w_10), --- 
  
          .mem_read (w_11), --- 
  
          .op_size (w_12), --- 
  
          .alu_write (w_16), --- 
  
          .instruction (w_20), --- 
  
          .branch_taken (w_21), --- 
  
          .ir_write (w_22), --- 
  
          .ab_write (w_23), --- 
  
          .mdr_write (w_25), --- 
  
          .reg_write (w_26), --- 
  
          .wb_sel (w_27), --- 
  
          .alu_control (w_28), --- 
  
          .a_sel (w_29), --- 
  
          .b_sel (w_30), --- 
  
          .mult_sel (w_31), --- 
  
          .crc_sel (w_32), --- 
  
          .branch_sel (w_33) --- 
  
      ); --- 
  
  --- 
  
 WB_MUX blk3207_9 ( ---( 
 WB_MUX 
          .pc_plus4 (w_6), --- 
  
          .alu_out (w_7), --- 
  
          .wb_sel (w_27), --- 
  
          .mdr (w_34), --- 
  
          .mult_result (w_35), --- 
  
          .crc_result (w_36), --- 
  
          .wb_data (w_37) --- 
  
      ); --- 
  
  --- 
  
 B_Register blk3204_10 ( ---( 
 B_Register 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .B (w_13), --- 
  
          .ab_write (w_23), --- 
  
          .rs2_data (w_38) --- 
  
      ); --- 
  
  --- 
  
 IR_Register blk3202_11 ( ---( 
 IR_Register 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .mem_rdata (w_14), --- 
  
          .ir (w_20), --- 
  
          .ir_write (w_22) --- 
  
      ); --- 
  
  --- 
  
 RegisterFile #(.DATA_MEM_SIZE(8192)) blk3199_13 ( ---blk3199_13( 
 RegisterFile 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .reg_write (w_26), --- 
  
          .reg_rd_data (w_37), --- 
  
          .reg_rs_2_data (w_38), --- 
  
          .instruction (w_20), --- 
  
          .reg_rs_1_data (w_45) --- 
  
      ); --- 
  
  --- 
  
 A_Register blk3203_17 ( ---( 
 A_Register 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .ab_write (w_23), --- 
  
          .rs1_data (w_45), --- 
  
          .A (w_46) --- 
  
      ); --- 
  
  --- 
  
 ALU blk3187_18 ( ---( 
 ALU 
          .pc_output (w_4), --- 
  
          .Q (w_17), --- 
  
          .ALU_control (w_28), --- 
  
          .A_sel (w_29), --- 
  
          .B_sel (w_30), --- 
  
          .reg_rs_2 (w_13), --- 
  
          .reg_rs_1 (w_46), --- 
  
          .immediate (w_50) --- 
  
      ); --- 
  
  --- 
  
 BranchComparator blk3188_19 ( ---( 
 BranchComparator 
          .o_Branch_Taken (w_21), --- 
  
          .Branch_Sel (w_33), --- 
  
          .reg_rs_2 (w_13), --- 
  
          .reg_rs_1 (w_46) --- 
  
      ); --- 
  
  --- 
  
 Multiplier blk3197_20 ( ---( 
 Multiplier 
          .mult_sel (w_31), --- 
  
          .rd (w_35), --- 
  
          .reg_rs_2 (w_13), --- 
  
          .reg_rs_1 (w_46) --- 
  
      ); --- 
  
  --- 
  
 CRC blk3190_21 ( ---( 
 CRC 
          .crc_sel (w_32), --- 
  
          .rd (w_36), --- 
  
          .reg_rs_2 (w_13), --- 
  
          .reg_rs_1 (w_46) --- 
  
      ); --- 
  
  --- 
  
 PC_Target_Align blk3211_23 ( ---( 
 PC_Target_Align 
          .pc_target (w_1), --- 
  
          .alu_out (w_7) --- 
  
      ); --- 
  
  --- 
  
 ImmediateGenerator blk3194_25 ( ---( 
 ImmediateGenerator 
          .instruction (w_20), --- 
  
          .extended_immediate (w_50) --- 
  
      ); --- 
  
  --- 
  
 MDR_Register blk3206_26 ( ---( 
 MDR_Register 
          .clk (clk), --- 
  
          .rst_n (rst_n), --- 
  
          .mem_rdata (w_14), --- 
  
          .mdr_write (w_25), --- 
  
          .mdr (w_34) --- 
  
      ); --- 
  
  --- 
  
 AddressDecoder blk3186_27 ( ---( 
 AddressDecoder 
  --- 
  
      ); --- 
  
  --- 
  
 DMEM #(.WORDS(2048)) blk3192_28 ( ---blk3192_28( 
 DMEM 
  --- 
  
      ); --- 
  
  --- 
  
 IMEM #(.WORDS(1048576), .FIRMWARE("firmware.hex")) blk3193_29 ( ---.FIRMWARE("firmware.hex"))blk3193_29( 
 (IMEM 
  --- 
  
      ); --- 
  
  --- 
  
 crc_calc blk3191_30 ( ---( 
 crc_calc 
  --- 
  
      ); --- 
  
  --- 
  
  --- 
  
 endmodule --- 
 endmodule 
  --- 
  
