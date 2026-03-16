#!/bin/bash
set -e

echo "=== VCS Compile ==="
vcs -sverilog -full64 -timescale=1ns/1ps \
    -f aou_tb.f \
    -top aou_tb \
    -o simv \
    -debug_access+all \
    +warn=noTFIPC \
    -suppress=IFSF \
    +define+AXI_LOG \
    -kdb

echo "=== VCS Run ==="
./simv +vcs+flush+all
