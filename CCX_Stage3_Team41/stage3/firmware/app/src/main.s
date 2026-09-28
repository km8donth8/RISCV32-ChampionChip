# =============================================================================
#  TollGuard - Smart Highway Toll Gantry Controller
#  Application firmware for the Team 41 (Equipe 41) RV32I_Zmmul_Xicrc SoC
#  ChampionCHIP eXperience Malaysia Edition - Stage 3
#
#  The processor sits in an electronic toll gantry. When a vehicle arrives,
#  roadside sensors raise VEHICLE and report its class; the RFID reader then
#  forwards the tag frame over UART. The firmware checks the frame integrity
#  with the hardware CRC unit (Xicrc), computes the fare with the multiplier
#  (Zmmul), debits the balance, opens the barrier (or raises an alarm) on the
#  GPIO and returns a receipt over UART.
#
#  ---------------------------------------------------------------- GPIO ----
#   P3 VEHICLE   in   1 = vehicle at the gantry (start trigger)
#   P2 PEAK      in   1 = peak-hour tariff (+25 %)
#   P1:P0 CLASS  in   0..3 = vehicle Class 1..4
#   P4 GATE      out  1 = paid, barrier open
#   P5 LOWBAL    out  1 = insufficient balance
#   P6 FRAMEERR  out  1 = tag frame rejected (CRC error / out of range)
#   P7 READY     out  1 = gantry idle, waiting for a vehicle
#
#  ------------------------------------------------ UART RX (8 bytes) ------
#   BALANCE  uint32  tag balance in sen (RM0.01)        bytes 0-3, LSB first
#   DISTANCE uint16  distance travelled in km           bytes 4-5, LSB first
#   CRC16    uint16  CRC-16/CCITT-FALSE of bytes 0-5    bytes 6-7, LSB first
#                    (poly 0x1021, init 0xFFFF, no reflection, no final XOR)
#
#  ------------------------------------------------ UART TX (7 bytes) ------
#   STATUS   uint8   0 OK, 1 LOW_BALANCE, 2 CRC_ERROR, 3 OUT_OF_RANGE
#   FARE     uint16  fare charged / required, in sen    LSB first
#   BALANCE  uint32  balance after the transaction      LSB first
#
#  Fare = BASE[class] + RATE[class] * km        (MUL)
#  Peak = Fare * 1.25 = (Fare * 0x14000) >> 16  (64-bit product, MUL + MULHU)
# =============================================================================

# ---------------- peripheral map (Block Guide) ----------------
.equ GPIO_BASE,             0xF0000000
.equ GPIO_DATAOUT,          0x0000
.equ GPIO_DATAIN,           0x0004
.equ GPIO_DATADIR,          0x0008

.equ UART_BASE,             0xF1000000
.equ UART_TXDATA,           0x0000
.equ UART_RXDATA,           0x0004
.equ UART_CONTROL,          0x0008
.equ UART_CONTROL_TRANSMIT, 0x01
.equ UART_CONTROL_RXDONE,   0x02
.equ UART_CONTROL_TXDONE,   0x04

# ---------------- application constants ----------------
.equ PIN_DIR,       0xF0        # P7-P4 outputs, P3-P0 inputs
.equ IN_VEHICLE,    0x08
.equ IN_PEAK,       0x04
.equ IN_CLASS,      0x03
.equ OUT_GATE,      0x10
.equ OUT_LOWBAL,    0x20
.equ OUT_FRAMEERR,  0x40
.equ OUT_READY,     0x80

.equ ST_OK,         0
.equ ST_LOWBAL,     1
.equ ST_CRC_ERR,    2
.equ ST_RANGE_ERR,  3

.equ CRC_SEED,      0xFFFF
.equ MAX_KM,        1000        # longest valid trip (sanity check)
.equ PEAK_Q16,      0x14000     # 1.25 in Q16.16 fixed point

# ---------------- Xicrc custom instruction (Stage 2 encoding) --------------
# CRCB rd, rs1, rs2 : rd = CRC16(seed = rs2[15:0], data = rs1[7:0])
# R-type: opcode 0110011, funct3 000, funct7 1000000
.macro crcb rd, rs1, rs2
    .insn r 0x33, 0, 0x40, \rd, \rs1, \rs2
.endm

# =============================================================================
_start:
    li   s0, GPIO_BASE
    li   s1, UART_BASE

    li   t0, PIN_DIR                    # configure pin directions
    sw   t0, GPIO_DATADIR(s0)
    sw   zero, UART_CONTROL(s1)         # clear any stale RXDONE

# ---------------------------------------------------------------- idle -----
_idle:
    li   t0, OUT_READY
    sw   t0, GPIO_DATAOUT(s0)           # READY lamp on

_wait_vehicle:
    lw   t0, GPIO_DATAIN(s0)
    andi t0, t0, IN_VEHICLE
    beq  t0, zero, _wait_vehicle

    lw   s2, GPIO_DATAIN(s0)            # s2 = sensors (class, peak) latched
    sw   zero, GPIO_DATAOUT(s0)         # busy: all lamps off

# ------------------------------------------ receive tag frame (8 bytes) ----
    li   s3, CRC_SEED                   # s3 = running CRC
    li   s4, 0                          # s4 = balance
    li   s6, 0                          # s6 = shift amount
    li   s7, 32
_rx_balance:                            # bytes 0-3, CRC computed on the fly
    jal  ra, _uart_getc
    crcb s3, a0, s3
    sll  a0, a0, s6
    or   s4, s4, a0
    addi s6, s6, 8
    bne  s6, s7, _rx_balance

    jal  ra, _uart_getc                 # byte 4: distance LSB
    crcb s3, a0, s3
    mv   s5, a0
    jal  ra, _uart_getc                 # byte 5: distance MSB
    crcb s3, a0, s3
    slli a0, a0, 8
    or   s5, s5, a0                     # s5 = distance (km)

    jal  ra, _uart_getc                 # byte 6: CRC LSB
    mv   s7, a0
    jal  ra, _uart_getc                 # byte 7: CRC MSB
    slli a0, a0, 8
    or   s7, s7, a0                     # s7 = received CRC

# ------------------------------------------------------- validate frame ----
    bne  s3, s7, _crc_error             # integrity (Xicrc)
    li   t0, MAX_KM
    bltu t0, s5, _range_error           # km > MAX_KM ?

# --------------------------------------------------------------- tariff ----
    andi t0, s2, IN_CLASS               # class index 0..3
    slli t0, t0, 2
    la   t1, tariff_base
    add  t1, t1, t0
    lw   t2, 0(t1)                      # base fare (sen)
    lw   t3, 16(t1)                     # rate (sen / km)
    mul  t3, t3, s5                     # rate * km          (Zmmul)
    add  a1, t2, t3                     # a1 = fare

    andi t0, s2, IN_PEAK
    beq  t0, zero, _charge
    li   t0, PEAK_Q16                   # fare * 1.25 as a 64-bit product
    mul   t1, a1, t0                    #   low  word        (Zmmul)
    mulhu t2, a1, t0                    #   high word        (Zmmul)
    srli t1, t1, 16
    slli t2, t2, 16
    or   a1, t1, t2                     # a1 = (fare * 0x14000) >> 16

# --------------------------------------------------------------- charge ----
_charge:
    bltu s4, a1, _low_balance
    sub  a2, s4, a1                     # new balance
    li   a0, ST_OK
    li   a3, OUT_GATE
    j    _respond

_low_balance:
    mv   a2, s4                         # balance untouched
    li   a0, ST_LOWBAL
    li   a3, OUT_LOWBAL
    j    _respond

_crc_error:
    li   a0, ST_CRC_ERR
    j    _frame_error
_range_error:
    li   a0, ST_RANGE_ERR
_frame_error:
    li   a1, 0                          # nothing charged, no data echoed
    li   a2, 0
    li   a3, OUT_FRAMEERR

# -------------------------------------------------------------- respond ----
_respond:
    sw   a3, GPIO_DATAOUT(s0)           # barrier / alarm lamps
    mv   s8, a1
    mv   s9, a2

    jal  ra, _uart_putc                 # STATUS
    andi a0, s8, 0xFF
    jal  ra, _uart_putc                 # FARE[7:0]
    srli a0, s8, 8
    andi a0, a0, 0xFF
    jal  ra, _uart_putc                 # FARE[15:8]

    li   s6, 0
    li   s7, 32
_tx_balance:                            # BALANCE, LSB first
    srl  a0, s9, s6
    andi a0, a0, 0xFF
    jal  ra, _uart_putc
    addi s6, s6, 8
    bne  s6, s7, _tx_balance

_wait_leave:                            # hold lamps until vehicle leaves
    lw   t0, GPIO_DATAIN(s0)
    andi t0, t0, IN_VEHICLE
    bne  t0, zero, _wait_leave
    j    _idle

# =============================================================================
# _uart_getc : wait for RXDONE, clear it, return byte in a0   (uses t0)
# =============================================================================
_uart_getc:
    lw   t0, UART_CONTROL(s1)
    andi t0, t0, UART_CONTROL_RXDONE
    beq  t0, zero, _uart_getc
    sw   zero, UART_CONTROL(s1)         # clear RXDONE
    lw   a0, UART_RXDATA(s1)
    andi a0, a0, 0xFF
    ret

# =============================================================================
# _uart_putc : wait for TXDONE, send byte in a0               (uses t0, t1)
# =============================================================================
_uart_putc:
    lw   t0, UART_CONTROL(s1)
    andi t0, t0, UART_CONTROL_TXDONE
    beq  t0, zero, _uart_putc
    sw   a0, UART_TXDATA(s1)
    lw   t1, UART_CONTROL(s1)           # read-modify-write keeps RXDONE
    ori  t1, t1, UART_CONTROL_TRANSMIT
    sw   t1, UART_CONTROL(s1)
    ret

# =============================================================================
# Tariff tables (read-only, stored in IMEM) - illustrative values, in sen
#             Class 1   Class 2   Class 3   Class 4
#             car       van/2-axle lorry(3+) taxi
# =============================================================================
.section .rodata
.align 2
tariff_base:
    .word 50, 100, 150, 30              # entry charge
tariff_rate:
    .word 12, 24, 36, 6                 # per km
