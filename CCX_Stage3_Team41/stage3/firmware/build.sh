#!/usr/bin/env bash
# Build a firmware with the organisers' RVBL-Firmware-Builder Makefile (unchanged)
# usage: firmware/build.sh official|app
set -e
cd "$(dirname "$0")"
FW=${1:?usage: build.sh official|app}
make -s -f builder/Makefile SRC_DIR=$FW/src OBJ_DIR=$FW/build BSP_DIR=builder/bsp SCRIPTS_DIR=builder/scripts clean
make -f builder/Makefile SRC_DIR=$FW/src OBJ_DIR=$FW/build BSP_DIR=builder/bsp SCRIPTS_DIR=builder/scripts
python3 ../scripts/gen_imem.py $FW/build/firmware.txt "$FW firmware" > ../rtl/imem/IMEM_$FW.v
echo "-> rtl/imem/IMEM_$FW.v ($(wc -l < $FW/build/firmware.txt) instructions)"
