
# Control Unit Interface Reference

This document defines the inputs, outputs, encodings and integration contract for `ControlUnit.v`.

## Inputs

| Signal | Width | Source | Meaning |
|---|---:|---|---|
| `clk` | 1 | Top-level clock | FSM state changes on each rising edge. |
| `rst_n` | 1 | Top-level reset | Asynchronous active-low reset. A value of `0` returns the FSM to `ST_FETCH`. |
| `i_instruction` | 32 | Instruction Register output | Current instruction being decoded and executed. |
| `i_branch_taken` | 1 | Branch Comparator | `1` when the selected branch condition is true. |

The controller extracts the following fields from `i_instruction`:

| Field | Instruction bits | Purpose |
|---|---:|---|
| `opcode` | `[6:0]` | Selects the instruction category. |
| `funct3` | `[14:12]` | Selects an operation within the category. |
| `funct7` | `[31:25]` | Distinguishes ALU, multiplication and CRC variants. |

## Sequential-register enables

All register-enable signals are active high.

| Signal | Width | Destination | Asserted states | Purpose |
|---|---:|---|---|---|
| `o_pc_write` | 1 | Program Counter | `ST_LOAD_WB`, `ST_STORE_WRITE`, `ST_BRANCH_COMMIT`, `ST_JAL_COMMIT`, `ST_JALR_COMMIT`, `ST_ALU_WB`, `ST_FENCE_COMMIT` | Allows the PC to capture its selected next value. |
| `o_ir_write` | 1 | Instruction Register | `ST_FETCH` | Captures the instruction read from IMEM. |
| `o_operand_write` | 1 | A/B Operand Registers | `ST_DECODE` | Captures the register-file `rs1` and `rs2` outputs. |
| `o_aluout_write` | 1 | ALUOut Register | Execution, target and effective-address states | Captures the selected ALU, multiplier or CRC result. |
| `o_mdr_write` | 1 | Memory Data Register | `ST_LOAD_CAPTURE` | Captures the formatted LSU load result. |
| `o_reg_write` | 1 | Register File | `ST_ALU_WB`, `ST_LOAD_WB`, `ST_JAL_COMMIT`, `ST_JALR_COMMIT` | Writes the selected writeback value into `rd`. |

## PC-path outputs

| Signal | Width | Destination | Encoding |
|---|---:|---|---|
| `o_pc_sel` | 1 | Program Counter next-address mux | `0 = PC+4`, `1 = ALUOut target` |
| `o_pc_lsb_clear` | 1 | JALR target masking logic | `1 = force target bit 0 to zero` |

| Instruction outcome | `o_pc_write` | `o_pc_sel` | `o_pc_lsb_clear` |
|---|---:|---:|---:|
| Normal instruction completes | 1 | 0 | 0 |
| Branch not taken | 1 | 0 | 0 |
| Branch taken | 1 | 1 | 0 |
| JAL | 1 | 1 | 0 |
| JALR | 1 | 1 | 1 |
| Instruction still executing | 0 | Don't care | 0 |

Suggested target masking logic:

```verilog
assign pc_target = o_pc_lsb_clear
                 ? {aluout_data[31:1], 1'b0}
                 : aluout_data;
```

## ALU outputs

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_alu_a_sel` | 1 | ALU input-A mux | Selects registered `rs1` or the current PC. |
| `o_alu_b_sel` | 1 | ALU input-B mux | Selects registered `rs2` or the extended immediate. |
| `o_alu_control` | 4 | ALU | Selects the arithmetic or logical operation. |

### ALU input-A selection

| `o_alu_a_sel` | ALU input A |
|---:|---|
| `0` | A Operand Register containing `rs1` |
| `1` | Current PC |

### ALU input-B selection

| `o_alu_b_sel` | ALU input B |
|---:|---|
| `0` | B Operand Register containing `rs2` |
| `1` | Extended immediate |

### ALU operation encoding

| `o_alu_control` | Operation | Result |
|---:|---|---|
| `4'h0` | PASS_B | `B` |
| `4'h1` | ADD | `A + B` |
| `4'h2` | SUB | `A - B` |
| `4'h3` | AND | `A & B` |
| `4'h4` | OR | `A \| B` |
| `4'h5` | XOR | `A ^ B` |
| `4'h6` | SLL | `A << B[4:0]` |
| `4'h7` | SRL | Logical `A >> B[4:0]` |
| `4'h8` | SRA | Arithmetic `A >>> B[4:0]` |
| `4'h9` | SLT | Signed `A < B` |
| `4'hA` | SLTU | Unsigned `A < B` |

## Execution-result mux

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_exec_result_sel` | 2 | Execution-result mux | Selects the execution result captured in ALUOut. |

| `o_exec_result_sel` | Selected source |
|---:|---|
| `2'b00` | ALU result |
| `2'b01` | Multiplier result |
| `2'b10` | CRC result |
| `2'b11` | Reserved |

The connection order is:

```text
ALU -----------+
Multiplier ----+--> execution-result mux --> ALUOut Register
CRC -----------+
```

## Writeback mux

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_wb_sel` | 2 | Register-file writeback mux | Selects the data written into `rd`. |

| `o_wb_sel` | Selected source | Used by |
|---:|---|---|
| `2'b00` | ALUOut | ALU, multiplication, CRC, LUI and AUIPC instructions |
| `2'b01` | MDR | Loads |
| `2'b10` | PC+4 | JAL and JALR |
| `2'b11` | Reserved | Not used |

## Memory-address mux

| Signal | Width | Destination | Encoding |
|---|---:|---|---|
| `o_mem_addr_sel` | 1 | Memory-address mux | `0 = PC`, `1 = ALUOut effective address` |

| Operation | Selected address |
|---|---|
| Instruction fetch | Current PC |
| Load | ALUOut effective address |
| Store | ALUOut effective address |

Suggested logic:

```verilog
assign memory_address = o_mem_addr_sel
                      ? aluout_data
                      : pc_output;
```

## Memory-control outputs

| Signal | Width | Destination | Asserted states | Purpose |
|---|---:|---|---|---|
| `o_mem_read` | 1 | MemoryUnit/Address Decoder | `ST_FETCH`, `ST_LOAD_REQUEST`, `ST_LOAD_CAPTURE` | Enables an IMEM or DMEM read. |
| `o_mem_write` | 1 | MemoryUnit/Address Decoder | `ST_STORE_WRITE` | Enables a DMEM write. |
| `o_lsu_op` | 3 | LSU | Fetch and load/store memory states | Selects load formatting or store byte enables. |

`o_mem_read` and `o_mem_write` must never be asserted simultaneously.

## LSU operation encoding

These are internal LSU codes and are not the raw instruction `funct3` values.

| `o_lsu_op` | Operation | Function |
|---:|---|---|
| `3'b000` | LW | Read a complete 32-bit word. |
| `3'b001` | LH | Read and sign-extend 16 bits. |
| `3'b010` | LB | Read and sign-extend 8 bits. |
| `3'b011` | LHU | Read and zero-extend 16 bits. |
| `3'b100` | LBU | Read and zero-extend 8 bits. |
| `3'b101` | SW | Write all four bytes. |
| `3'b110` | SH | Write the selected two-byte halfword. |
| `3'b111` | SB | Write the selected byte. |

## Multiplier output

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_mult_sel` | 4 | Multiplier | Selects the required multiplication result. |

| `o_mult_sel` | Instruction | Result |
|---:|---|---|
| `4'h0` | MUL | Product bits `[31:0]` |
| `4'h1` | MULH | Signed x signed product `[63:32]` |
| `4'h2` | MULHSU | Signed x unsigned product `[63:32]` |
| `4'h3` | MULHU | Unsigned x unsigned product `[63:32]` |

`o_mult_sel` is meaningful during `ST_EXEC_MUL`.

## CRC output

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_crc_sel` | 2 | CRC unit | Selects how many bits of `rs1` are processed. |

| `o_crc_sel` | Instruction | CRC data | Seed |
|---:|---|---|---|
| `2'b00` | CRCB | `rs1[7:0]` | `rs2[15:0]` |
| `2'b01` | CRCH | `rs1[15:0]` | `rs2[15:0]` |
| `2'b10` | CRCW | `rs1[31:0]` | `rs2[15:0]` |
| `2'b11` | Reserved | Not used | Not used |

The CRC result is zero-extended to 32 bits:

```verilog
{16'b0, crc_result[15:0]}
```

`o_crc_sel` is meaningful during `ST_EXEC_CRC`.

## Branch-comparator output

| Signal | Width | Destination | Purpose |
|---|---:|---|---|
| `o_branch_sel` | 3 | Branch Comparator | Selects the comparison operation. |

| `o_branch_sel`/`funct3` | Instruction | Comparison |
|---:|---|---|
| `3'b000` | BEQ | `rs1 == rs2` |
| `3'b001` | BNE | `rs1 != rs2` |
| `3'b100` | BLT | Signed `rs1 < rs2` |
| `3'b101` | BGE | Signed `rs1 >= rs2` |
| `3'b110` | BLTU | Unsigned `rs1 < rs2` |
| `3'b111` | BGEU | Unsigned `rs1 >= rs2` |

The Branch Comparator returns its decision through `i_branch_taken`.

## Status outputs

| Signal | Width | Destination | Meaning |
|---|---:|---|---|
| `o_halt` | 1 | Top-level/debug/testbench | Processor execution is stopped. |
| `o_illegal` | 1 | Top-level/debug/testbench | Processor stopped because of an invalid instruction. |
| `o_state` | 6 | Debug/testbench | Current FSM state. |

| Condition | `o_halt` | `o_illegal` |
|---|---:|---:|
| Normal operation | 0 | 0 |
| ECALL/EBREAK halt | 1 | 0 |
| Illegal instruction | 1 | 1 |

## FSM-state encoding

| `o_state` | State | Main action |
|---:|---|---|
| `6'd0` | `ST_FETCH` | Read IMEM and capture IR. |
| `6'd1` | `ST_DECODE` | Capture `rs1` and `rs2`; decode the instruction. |
| `6'd2` | `ST_EXEC_REG` | Execute a register-register ALU operation. |
| `6'd3` | `ST_EXEC_IMM` | Execute an immediate ALU operation. |
| `6'd4` | `ST_EXEC_MUL` | Execute multiplication. |
| `6'd5` | `ST_EXEC_CRC` | Execute CRC. |
| `6'd6` | `ST_EXEC_LUI` | Pass the upper immediate. |
| `6'd7` | `ST_EXEC_AUIPC` | Calculate PC plus upper immediate. |
| `6'd8` | `ST_EXEC_MEM_ADDR` | Calculate a load/store effective address. |
| `6'd9` | `ST_LOAD_REQUEST` | Start a synchronous memory read. |
| `6'd10` | `ST_LOAD_CAPTURE` | Capture the formatted memory response in MDR. |
| `6'd11` | `ST_LOAD_WB` | Write MDR into `rd`. |
| `6'd12` | `ST_STORE_WRITE` | Write `rs2` data into memory. |
| `6'd13` | `ST_BRANCH_TARGET` | Calculate the branch target. |
| `6'd14` | `ST_BRANCH_COMMIT` | Select the target or PC+4. |
| `6'd15` | `ST_JAL_TARGET` | Calculate the JAL target. |
| `6'd16` | `ST_JAL_COMMIT` | Write the link address and jump. |
| `6'd17` | `ST_JALR_TARGET` | Calculate the JALR target. |
| `6'd18` | `ST_JALR_COMMIT` | Write the link, clear target bit zero and jump. |
| `6'd19` | `ST_ALU_WB` | Write ALUOut into `rd`. |
| `6'd20` | `ST_FENCE_COMMIT` | Treat FENCE as a no-op and advance the PC. |
| `6'd21` | `ST_HALT` | Stop until reset. |
| `6'd22` | `ST_ILLEGAL` | Report an illegal instruction and stop. |

## Integration rules

- `i_instruction` must come from the Instruction Register, not directly from memory.
- Both Register File outputs must pass through the A/B Operand Registers.
- `o_pc_write` must connect to the Program Counter's write enable.
- The ALU, Multiplier and CRC unit must feed the execution-result mux before ALUOut.
- The LSU load output must pass through MDR before writeback.
- `i_branch_taken` must come from the Branch Comparator.
- `o_pc_lsb_clear` must clear ALUOut bit zero only for JALR.
- `o_mult_sel`, `o_crc_sel` and `o_lsu_op` are meaningful only in their associated states. Their default values should otherwise be ignored.

## Required PC behavior

The Program Counter must update only when `o_pc_write` is high:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc_q <= 32'h0040_0000;
    else if (o_pc_write)
        pc_q <= pc_next;
end
```

Do not gate the clock signal. Implement the PC write enable inside the sequential block.
