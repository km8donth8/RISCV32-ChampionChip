#!/usr/bin/env python3
"""Render report waveform figures from results/*.vcd -> results/figures/*.png"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vcd2png import load, plot
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
os.makedirs("results/figures", exist_ok=True)
which = sys.argv[1:] or ["official", "app"]

if "official" in which:
    T = "tb_official_fw."
    rows = [("clk", T+"clk", "clk", ""), ("rst_n", T+"rst_n", "bit", ""),
            ("PC", T+"o_pc", "bus", "hex"),
            ("P3-P0 (in)", T+"P3_P0", "bus", "hex"), ("DATADIR", T+"DATADIR", "bus", "hex"),
            ("DATAOUT", T+"DATAOUT", "bus", "hex"), ("P7-P4 (out)", T+"P7_P4", "bus", "hex"),
            ("uart_rx (in)", T+"uart_rx", "bit", ""), ("RXDATA", T+"RXDATA", "bus", "hex"),
            ("CONTROL[2:0]", T+"UART_CONTROL", "bus", "hex"), ("TXDATA", T+"TXDATA", "bus", "hex"),
            ("uart_tx (out)", T+"uart_tx", "bit", "")]
    s = load("results/tb_official_fw.vcd", [r[1] for r in rows])
    plot(s, rows, 0, 340_000, "results/figures/official_full.png",
         "Official GPIO & UART test firmware - full run (GPIO 0xA->0xA, UART 0x30->0x30, loop: UART 0x4B->0x4B, GPIO 0x5->0x5)")
    plot(s, rows, 0, 1_200, "results/figures/official_gpio_zoom.png",
         "Official test - GPIO echo after reset: DATADIR=0xF0, DATAIN=0x0A -> DATAOUT=0xA0 (P7-P4 = 0xA)", unit="ns")
    plot(s, rows[:2] + rows[7:], 0, 175_000, "results/figures/official_uart_zoom.png",
         "Official test - UART echo: 0x30 received on rx (RXDONE=CONTROL[1]) and re-sent on tx (TRANSMIT/TXDONE)")

if "app" in which:
    T = "tb_app_fw."
    rows = [("clk", T+"clk", "clk", ""), ("rst_n", T+"rst_n", "bit", ""),
            ("P3 VEHICLE", T+"VEHICLE", "bit", ""), ("P2 PEAK", T+"PEAK", "bit", ""),
            ("P1:P0 CLASS", T+"CLASS", "bus", "dec"),
            ("uart_rx (tag)", T+"uart_rx", "bit", ""),
            ("s3 CRC running", T+"crc_running", "bus", "hex"),
            ("s4 balance", T+"balance_rx", "bus", "dec"), ("s5 km", T+"km_rx", "bus", "dec"),
            ("a1 fare", T+"fare_reg", "bus", "dec"),
            ("uart_tx (receipt)", T+"uart_tx", "bit", ""),
            ("P4 GATE", T+"GATE", "bit", ""), ("P5 LOWBAL", T+"LOWBAL", "bit", ""),
            ("P6 FRAMEERR", T+"FRAMEERR", "bit", ""), ("P7 READY", T+"READY", "bit", "")]
    s = load("results/tb_app_fw.vcd", [r[1] for r in rows] + [T+"pc", T+"cu_state"])
    # locate pass-B vehicle #1 (van, peak): 2nd rising edge of VEHICLE after the pass-B reset
    rst = [t for t, v in s[T+"rst_n"][1] if v == "0"]
    tB = rst[-1]
    veh = [t for t, v in s[T+"VEHICLE"][1] if v == "1" and t > tB]
    vl  = [t for t, v in s[T+"VEHICLE"][1] if v == "0" and t > tB]
    a, b = veh[1] / 1000 - 25_000, [x for x in vl if x > veh[1]][0] / 1000 + 30_000
    plot(s, rows, a, b, "results/figures/app_vehicle_peak_van.png",
         "TollGuard - Class 2 van, peak hour: RM100.00 tag, 120 km -> fare 3725 sen, new balance 6275 sen, GATE opens")
    # processing window: last RX byte -> first TX byte
    tx0 = [t for t, v in s[T+"uart_tx"][1] if v == "0" and t > veh[1]][0] / 1000
    rows_z = rows[:1] + [("PC", T+"pc", "bus", "hex"), ("CU state", T+"cu_state", "bus", "dec")] + rows[5:]
    rows_z = [r for r in rows_z if r[0] not in ("clk", "CU state", "uart_rx (tag)", "s4 balance", "s5 km")]
    plot(s, rows_z, tx0 - 4_300, tx0 + 150, "results/figures/app_processing_zoom.png",
         "TollGuard - processing window: CRC check (Xicrc) -> tariff MUL -> peak MUL/MULHU -> debit -> lamps -> receipt", unit="ns", figw=26, label_min=0.012, rel=True)
    # whole regression overview
    end = s[T+"READY"][1][-1][0] / 1000 + 50_000
    plot(s, [r for r in rows if r[2] != "bus" or r[0].startswith(("P1", "a1"))], 0, end,
         "results/figures/app_regression_overview.png",
         "TollGuard regression - Pass A (reset per vehicle, ./emu style) then Pass B (continuous gantry), 7 scenarios each")
