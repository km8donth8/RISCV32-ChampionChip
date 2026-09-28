#!/usr/bin/env bash
# usage: sim/run.sh official|app      (run from anywhere; Icarus Verilog >= 11)
set -e
cd "$(dirname "$0")/.."
T=${1:?usage: run.sh official|app}
mkdir -p results
RTL="rtl/core/core_modules_equipe41.v rtl/soc/lsu_dmem_equipe41.v \
     rtl/periph/GPIO_equipe41.v rtl/periph/UART_equipe41.v \
     rtl/soc/MemoryUnit_SoC_equipe41.v rtl/soc/soc_top_equipe41.v \
     rtl/imem/IMEM_$T.v"
iverilog -g2012 -Wall -Wno-timescale -I tb -o results/sim_$T.vvp tb/tb_${T}_fw.v $RTL
vvp -n results/sim_$T.vvp | tee results/tb_${T}_fw.log
