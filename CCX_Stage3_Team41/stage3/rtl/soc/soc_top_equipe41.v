// ============================================================================
// soc_top_equipe41 - Stage 3 RISC-V SoC top level
// Team 41 (Equipe 41)
//
// Stage 2 top (ChipInventor-generated wiring, unchanged) with the Stage 2
// MemoryUnit replaced by MemoryUnit_SoC_equipe41, which adds the GPIO
// (0xF0000000) and UART (0xF1000000) peripherals on the same load/store bus.
// ============================================================================
module soc_top_equipe41 #(
  parameter integer CLK_FREQ_HZ = 50_000_000,
  parameter integer BAUD_RATE   = 115_200
)(
  input  wire       clk,
  input  wire       rst_n,
  output wire       o_halt,
  // GPIO (split pins_io bus: P7..P0)
  input  wire [7:0] gpio_in,
  output wire [7:0] gpio_out,
  output wire [7:0] gpio_oe,
  // UART
  input  wire       uart_rx_i,
  output wire       uart_tx_o,
  // debug: program counter (exposed to the FPGA top / emulator PC register)
  output wire [31:0] o_pc
);

//Internal Wires
 wire w_1;
 wire [31:0] w_2;
 wire [31:0] w_3;
 wire w_4;
 wire [31:0] w_5;
 wire [31:0] w_6;
 wire [31:0] w_7;
 wire [31:0] w_8;
 wire [31:0] w_9;
 wire [1:0] w_10;
 wire [31:0] w_11;
 wire [31:0] w_12;
 wire [1:0] w_13;
 wire [31:0] w_14;
 wire [31:0] w_15;
 wire w_17;
 wire [31:0] w_18;
 wire [31:0] w_19;
 wire [31:0] w_20;
 wire [3:0] w_21;
 wire w_23;
 wire w_24;
 wire [31:0] w_25;
 wire w_26;
 wire [31:0] w_27;
 wire [31:0] w_28;
 wire [31:0] w_29;
 wire [2:0] w_32;
 wire w_33;
 wire [1:0] w_36;
 wire w_37;
 wire [31:0] w_38;
 wire [31:0] w_42;
 wire w_46;
 wire [31:0] w_47;
 wire [31:0] w_50;
 wire w_52;
 wire w_53;
 wire w_54;
 wire [3:0] w_55;
 wire w_56;
 wire w_57;
 wire [2:0] w_58;

//Instances of Modules
ALU_OUT_Register blk4367_2 (
         .clk (clk),
         .rst_n (rst_n),
         .alu_write (w_1),
         .alu_q (w_2),
         .alu_out (w_3)
     );

MDR_Register blk4370_5 (
         .clk (clk),
         .rst_n (rst_n),
         .mdr_write (w_4),
         .mem_rdata (w_5),
         .mdr (w_6)
     );

Exec_Result_MUX blk4371_6 (
         .exec_result (w_2),
         .alu_result (w_7),
         .mult_result (w_8),
         .crc_result (w_9),
         .exec_result_sel (w_10)
     );

WB_MUX blk4372_7 (
         .mdr (w_6),
         .alu_out (w_11),
         .pc_plus4 (w_12),
         .wb_sel (w_13),
         .wb_data (w_14)
     );

Memory_Address_MUX blk4373_8 (
         .pc (w_15),
         .alu_out (w_11),
         .mem_addr_sel (w_17),
         .mem_addr (w_18)
     );

Multiplier_equipe41 blk4299_9 (
         .rd (w_8),
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .mult_sel (w_21)
     );

ProgramCounter_equipe41 blk4300_10 (
         .clk (clk),
         .rst_n (rst_n),
         .o_PC_Plus_4 (w_12),
         .o_PC_Output (w_15),
         .i_ALU_output (w_11),
         .PC_sel (w_23),
         .PC_write (w_24)
     );

RegisterFile_equipe41 #(.DATA_MEM_SIZE(2**13)) blk4352_11 (
         .clk (clk),
         .rst_n (rst_n),
         .reg_rd_data (w_14),
         .reg_write (w_26),
         .instruction (w_27),
         .reg_rs_1_data (w_28),
         .reg_rs_2_data (w_29)
     );

BranchComparator_equipe41 blk4296_12 (
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .Branch_Sel (w_32),
         .o_Branch_Taken (w_33)
     );

CRC_equipe41 blk4295_13 (
         .rd (w_9),
         .reg_rs_1 (w_19),
         .reg_rs_2 (w_20),
         .crc_sel (w_36)
     );

A_Register blk4369_15 (
         .clk (clk),
         .rst_n (rst_n),
         .A (w_19),
         .rs1_data (w_28),
         .ab_write (w_37)
     );

B_Register blk4366_16 (
         .clk (clk),
         .rst_n (rst_n),
         .B (w_20),
         .rs2_data (w_29),
         .ab_write (w_37)
     );

PC_Target_Align_equipe41 blk4353_18 (
         .alu_out (w_3),
         .pc_target (w_11),
         .pc_lsb_clear (w_46)
     );

ImmediateGenerator_equipe41 blk4297_19 (
         .instruction (w_27),
         .extended_immediate (w_50)
     );

ControlUnit_equipe41 blk4354_26 (
         .clk (clk),
         .rst_n (rst_n),
         .o_halt (o_halt),
         .o_aluout_write (w_1),
         .o_mdr_write (w_4),
         .o_exec_result_sel (w_10),
         .o_wb_sel (w_13),
         .o_mem_addr_sel (w_17),
         .o_mult_sel (w_21),
         .o_pc_sel (w_23),
         .o_pc_write (w_24),
         .o_reg_write (w_26),
         .o_branch_sel (w_32),
         .i_branch_taken (w_33),
         .o_crc_sel (w_36),
         .o_operand_write (w_37),
         .o_pc_lsb_clear (w_46),
         .i_instruction (w_27),
         .o_ir_write (w_52),
         .o_alu_a_sel (w_53),
         .o_alu_b_sel (w_54),
         .o_alu_control (w_55),
         .o_mem_read (w_56),
         .o_mem_write (w_57),
         .o_lsu_op (w_58)
     );

IR_Register blk4368_28 (
         .clk (clk),
         .rst_n (rst_n),
         .ir (w_27),
         .ir_write (w_52),
         .mem_rdata (w_5)
     );

ALU_equipe41 blk4294_30 (
         .Q (w_7),
        .pc_output (w_15),
    .reg_rs_1 (w_19),
    .reg_rs_2 (w_20),
         .immediate (w_50),
         .A_sel (w_53),
         .B_sel (w_54),
         .ALU_control (w_55)
     );

MemoryUnit_SoC_equipe41 #(
         .CLK_FREQ_HZ (CLK_FREQ_HZ),
         .BAUD_RATE   (BAUD_RATE)
     ) blk_mem_soc (
         .clk (clk),
         .rst_n (rst_n),
         .core_data_i (w_5),
         .core_address_o (w_18),
         .core_data_o (w_20),
         .read_enable (w_56),
         .write_enable (w_57),
         .op_size_o (w_58),
         .gpio_in (gpio_in),
         .gpio_out (gpio_out),
         .gpio_oe (gpio_oe),
         .uart_rx_i (uart_rx_i),
         .uart_tx_o (uart_tx_o)
     );

assign o_pc = w_15;

endmodule
