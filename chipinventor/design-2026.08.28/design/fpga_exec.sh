#!/usr/bin/bash
yosys -p "read_verilog /chipinventor/design/hdl.v; synth_gowin -noalu -top top -json /chipinventor/compile/synYosys.json"