# *****************************************************************************
# SPDX-License-Identifier: Apache-2.0
# *****************************************************************************
# Copyright (c) 2026 Tenstorrent USA Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
#
# cocotb Makefile for the AOU_CORE_TOP FDI loopback + CSR reset readback
# testbench. This is the only verification flow shipped with this repo.
#
# Usage:
#   make                       # Verilator (default), 8 parallel C++ compile jobs
#   make SIM=vcs               # Synopsys VCS
#   make WAVES=1               # enable waveform dump
#                              #   verilator -> dump.vcd  (in this directory)
#                              #   vcs       -> dump.fsdb (if Verdi available)
#                              #             or dump.vpd  (otherwise)
#   make SIM=vcs WAVES=1 WAVES_FORMAT=vpd   # force VPD instead of FSDB
#   make FDI_LOG=1             # enable fdi_flit_decoder under +define+FDI_LOG
#   make JOBS=16               # override C++ compile parallelism (default 8)
#   make JOBS=1                # serial compile (useful when debugging errors)
#   make JOBS=0                # use all available cores
#   make clean                 # remove sim_build/ and generated artefacts
#
# *****************************************************************************

SIM             ?= verilator
TOPLEVEL_LANG   ?= verilog
TOPLEVEL        ?= aou_cocotb_top
# Comma-separated list of cocotb modules to load in one simulator run.
# All modules share a single elab/build, so adding a module here only
# costs the per-test simulation time, not another verilator/vcs compile.
MODULE          ?= test_aou_loopback,test_csr_reset

# Parallel-build job count for the Verilator-driven C++ compile phase.
# JOBS=0 means "use all cores"; any other positive integer is the cap.
JOBS            ?= 8

# ----------------------------------------------------------------------------
# Resolve absolute paths so cocotb's Makefile (which chdirs to sim_build/)
# still finds the RTL sources listed in aou_cocotb.f relative to this dir.
# ----------------------------------------------------------------------------
VERIF_DIR       := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
FLIST           := $(VERIF_DIR)/aou_cocotb.f

# Pull source files out of the .f file (strip comments, blanks, +incdir lines).
# Each path in the .f is relative to VERIF_DIR; rewrite to absolute.
_FLIST_LINES    := $(shell sed -e 's|//.*||' $(FLIST) | grep -v '^[[:space:]]*$$' | grep -v '^[[:space:]]*+')
VERILOG_SOURCES := $(foreach f,$(_FLIST_LINES),$(abspath $(VERIF_DIR)/$(f)))

# Tell cocotb where to find Python tests.
export PYTHONPATH := $(VERIF_DIR)/tests:$(PYTHONPATH)

# Optional defines.
ifeq ($(FDI_LOG),1)
EXTRA_ARGS     += +define+FDI_LOG
COMPILE_ARGS   += +define+FDI_LOG
endif

# ----------------------------------------------------------------------------
# Verilator-specific options
# ----------------------------------------------------------------------------
ifeq ($(SIM),verilator)
# Two parallelism knobs:
#   1. --build-jobs N  : passed to verilator at SV->C++ generation time.
#                        Only kicks in if verilator is also driving its own
#                        C++ build (it is NOT here -- cocotb runs the C++
#                        build separately, see #2). Kept for completeness.
#   2. BUILD_ARGS += -j: passed to the cocotb-launched recursive make of
#                        sim_build/Vtop.mk that actually does the g++
#                        compiles. THIS is the one that gives you parallel
#                        g++ invocations. JOBS=0 maps to bare -j (unlimited
#                        parallelism = use all available cores).
EXTRA_ARGS     += --build-jobs $(JOBS)
ifeq ($(JOBS),0)
BUILD_ARGS     += -j
else
BUILD_ARGS     += -j $(JOBS)
endif
EXTRA_ARGS     += --timing
EXTRA_ARGS     += -sv
EXTRA_ARGS     += --timescale 1ns/1ps
EXTRA_ARGS     += -Wno-WIDTHEXPAND
EXTRA_ARGS     += -Wno-WIDTHTRUNC
EXTRA_ARGS     += -Wno-UNUSEDSIGNAL
EXTRA_ARGS     += -Wno-UNUSEDPARAM
EXTRA_ARGS     += -Wno-DECLFILENAME
EXTRA_ARGS     += -Wno-PINCONNECTEMPTY
EXTRA_ARGS     += -Wno-TIMESCALEMOD
EXTRA_ARGS     += -Wno-fatal
ifeq ($(WAVES),1)
EXTRA_ARGS     += --trace --trace-structs
endif
endif

# ----------------------------------------------------------------------------
# VCS-specific options
# ----------------------------------------------------------------------------
ifeq ($(SIM),vcs)
COMPILE_ARGS   += -sverilog -full64 -timescale=1ns/1ps
COMPILE_ARGS   += -debug_access+all
COMPILE_ARGS   += +warn=noTFIPC
COMPILE_ARGS   += -suppress=IFSF
COMPILE_ARGS   += -kdb

# Waveform dumping for VCS.
#   WAVES=1                  -> default to FSDB if Verdi is available, else VPD.
#   WAVES_FORMAT=fsdb        -> force FSDB
#   WAVES_FORMAT=vpd         -> force VPD
#
# `+vcdpluson` / `+fsdb` plusargs are gated by the harness's initial blocks
# (see aou_cocotb_top.sv) which call $vcdplusfile/$vcdpluson or
# $fsdbDumpfile/$fsdbDumpvars. Just compiling with -kdb / -debug_access+all
# is not enough -- VCS will not start a dump on its own.
ifeq ($(WAVES),1)
WAVES_FORMAT   ?= $(if $(shell command -v verdi 2>/dev/null),fsdb,vpd)
ifeq ($(WAVES_FORMAT),fsdb)
COMPILE_ARGS   += +define+DUMP_FSDB
# -kdb already wires the Verdi FSDB system tasks into the simv at runtime in
# Y-2024.06 and later, so a manual -P verdi.tab is not strictly required.
# If your VCS setup needs explicit PLI loading, set VERDI_HOME and uncomment:
#COMPILE_ARGS  += -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/verdi.tab \
#                  $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a -lpthread
SIM_ARGS       += +fsdb+autoflush +fsdb
endif
ifeq ($(WAVES_FORMAT),vpd)
COMPILE_ARGS   += +define+DUMP_VPD
SIM_ARGS       += +vcdpluson
endif
endif
endif

# ----------------------------------------------------------------------------
# Cocotb's standard simulation Makefile fragments.
# Provides 'make' and 'make clean' targets.
# ----------------------------------------------------------------------------
include $(shell cocotb-config --makefiles)/Makefile.sim

# Augment 'make clean' with our own artefacts.
clean::
	rm -rf sim_build results.xml
	rm -f *.fst *.vcd *.fsdb dump.vcd
	rm -f dut1_fdi.log dut2_fdi.log
	rm -f *.log
	rm -rf __pycache__ tests/__pycache__ .pytest_cache
