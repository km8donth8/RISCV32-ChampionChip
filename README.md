## Modules

### ALU

<p align="center">
  <img src="pic/ALU.png" width="600" alt="ALU block diagram">
</p>

Eleven operations selected by a 4-bit control code derived from `funct7[25]`
concatenated with `funct3[14:12]`. Two input multiplexers let the same ALU serve
register operations, immediate operations, and PC-relative address computation:
`A_sel` chooses between `reg_rs_1` and `pc_output`, `B_sel` between `reg_rs_2`
and `immediate`.

| Control | Operation | Notes |
|---|---|---|
| `4'h0` | PASS_B | passes B through, used by LUI |
| `4'h1` | ADD | |
| `4'h2` | SUB | |
| `4'h3` | AND | |
| `4'h4` | OR | |
| `4'h5` | XOR | |
| `4'h6` | SLL | shift amount from `B_Mux[4:0]` |
| `4'h7` | SRL | logical right shift |
| `4'h8` | MRS | arithmetic right shift, `>>>` on a signed operand |
| `4'h9` | SLT | signed comparison |
| `4'hA` | SLTU | operands cast with `$unsigned` |

<details>
<summary><b>ALU.v</b> — click to expand</summary>

```verilog
module ALU(
    input wire [31:0] reg_rs_1,
    input wire [31:0] reg_rs_2,
    input wire [31:0] pc_output,
    input wire [31:0] immediate,
    input wire [3:0]  ALU_control,
    input wire        A_sel,
    input wire        B_sel,
    output reg signed [31:0] Q
    );
    wire signed [31:0] A_Mux;
    wire signed [31:0] B_Mux;

    assign A_Mux = (A_sel) ? pc_output : reg_rs_1;
    assign B_Mux = (B_sel) ? immediate : reg_rs_2;

    always @ (*) begin
        case (ALU_control)
            `c_ALU_OP_PASS_B: Q = B_Mux;
            `c_ALU_OP_ADD:    Q = A_Mux + B_Mux;
            `c_ALU_OP_SUB:    Q = A_Mux - B_Mux;
            `c_ALU_OP_AND:    Q = A_Mux & B_Mux;
            `c_ALU_OP_OR:     Q = A_Mux | B_Mux;
            `c_ALU_OP_XOR:    Q = A_Mux ^ B_Mux;
            `c_ALU_OP_SLL:    Q = A_Mux << B_Mux[4:0];
            `c_ALU_OP_SRL:    Q = A_Mux >> B_Mux[4:0];
            `c_ALU_OP_MRS:    Q = A_Mux >>> B_Mux[4:0];
            `c_ALU_OP_SLT:    Q = (A_Mux < B_Mux) ? 32'h1 : 32'h0;
            `c_ALU_OP_SLTU:   Q = ($unsigned(A_Mux) < $unsigned(B_Mux)) ? 32'h1 : 32'h0;
            default:          Q = 32'h0;
        endcase
    end
endmodule
```

[Full source →](rtl/ALU.v)

</details>

#### Testbench

Exercises all eleven operations. Directed cases cover the sign-sensitive paths:
`0x8000000F` shifted right to distinguish SRL from MRS, and `-2` against `+10`
to distinguish SLT from SLTU.

<p align="center">
  <img src="pic/tb_ALU.png" width="700" alt="ALU simulation log">
</p>

| Test | Operands | Result | Expected |
|---|---|---|---|
| ADD | `0x00000100 + 0xFFFFFFFE` | `0x000000FE` | 256 − 2 = 254 |
| SLL | `0x8000000F << 4` | `0x000000F0` | upper bits shifted out |
| SRL | `0x8000000F >> 4` | `0x08000000` | zero-filled |
| MRS | `0x8000000F >>> 4` | `0xF8000000` | sign-extended |
| SLT | `-2 < 10` | `0x00000001` | signed → true |
| SLTU | `0xFFFFFFFE < 10` | `0x00000000` | unsigned → false |

All eleven operations produced the expected result.

<details>
<summary><b>tb_ALU.v</b> — click to expand</summary>

```verilog
// paste the testbench here
```

[Full source →](tb/tb_ALU.v)

</details>
