// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
//  Copyright (c) 2026 Tenstorrent USA Inc
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// *****************************************************************************
// AOU_CORE_TOP cocotb Testbench -- File List
// All paths relative to the VERIF/ directory.
// =============================================================================
// All three harness top modules are compiled into the same binary; the
// Makefile selects which one is elaborated as the simulation TOPLEVEL via
// the FDI_CONFIG=sp32b|sp64b|sp128b knob:
//
//   - aou_cocotb_top         : single-PHY 32B  FDI (FDI_CFG_SP_32B,  256b)
//   - aou_cocotb_top_sp64b   : single-PHY 64B  FDI (FDI_CFG_SP_64B,  512b)
//   - aou_cocotb_top_sp128b  : single-PHY 128B FDI (FDI_CFG_SP_128B, 1024b)
//
// TWO_PHY is intentionally NOT defined.

// RTL package (must come before modules that import it)
../RTL/packet_def_pkg.sv

// RTL LIB cells
../RTL/LIB/AOU_SOC_BUF.v
../RTL/LIB/AOU_SOC_GFMUX_LVT.v
../RTL/LIB/AOU_SOC_SYNCHSR.v
../RTL/LIB/ASYNC_APB_BRIDGE/ASYNC_APB_BRIDGE_SI.v
../RTL/LIB/ASYNC_APB_BRIDGE/ASYNC_APB_BRIDGE_MI.v
../RTL/LIB/ASYNC_APB_BRIDGE/ASYNC_APB_BRIDGE.v

// RTL Verilog modules
../RTL/AOU_2X1_ARBITER.v
../RTL/AOU_3X1_ARBITER.v
../RTL/AOU_4X1_ARBITER.v
../RTL/AOU_AXIMUX_1XN_SS.v
../RTL/AOU_AXI_WLAST_GEN.v
../RTL/AOU_CORE_SFR.v
../RTL/AOU_SYNC_FIFO_REG.v

// RTL AXI4MUX_3X1 (submodules before parents)
../RTL/AXI4MUX_3X1/AOU_AGGREGATOR_INFO.sv
../RTL/AXI4MUX_3X1/AOU_AXI_DOWN_RDATA_ORDER.sv
../RTL/AXI4MUX_3X1/AOU_SPLIT_RD_PENDING_INFO.sv
../RTL/AXI4MUX_3X1/AOU_SPLIT_WR_PENDING_INFO.sv
../RTL/AXI4MUX_3X1/AOU_UP_FIFO.v
../RTL/AXI4MUX_3X1/AOU_AXI_UP.v
../RTL/AXI4MUX_3X1/AOU_AXI_SPLIT_TR.v
../RTL/AXI4MUX_3X1/AOU_AXI_SPLIT_ADDRGEN.v
../RTL/AXI4MUX_3X1/AOU_AXI_INST_SPLITTER.v
../RTL/AXI4MUX_3X1/AOU_AXI_DOWN.v
../RTL/AXI4MUX_3X1/AOU_AGGREGATOR.v
../RTL/AXI4MUX_3X1/AOU_AXI4MUX_3X1_1024.v
../RTL/AXI4MUX_3X1/AOU_AXI4MUX_3X1_512.v
../RTL/AXI4MUX_3X1/AOU_AXI4MUX_3X1_256.v
../RTL/AXI4MUX_3X1/AOU_AXI4MUX_3X1_TOP.v

// RTL SystemVerilog modules (submodules before parents)
../RTL/AOU_ACTIVATION_CTRL.sv
../RTL/AOU_AW_W_ALIGNER.sv
../RTL/AOU_CRD_CTRL.sv
../RTL/AOU_DATA_R_FIFO_NS1M_TPSRAM.sv
../RTL/AOU_DATA_W_FIFO_NS1M_TPSRAM.sv
../RTL/AOU_SYNC_FIFO_NS1M_SREADY.sv
../RTL/AOU_TPSRAM.sv
../RTL/AOU_EARLY_BRESP_CTRL_AWCACHE.sv
../RTL/AOU_EARLY_TABLE.sv
../RTL/AOU_ERROR_INFO.sv
../RTL/AOU_FIFO_RP.sv
../RTL/AOU_FWD_RS.sv
../RTL/AOU_ISO_RS.sv
../RTL/AOU_REV_RS.sv
../RTL/AOU_RX_CORE.sv
../RTL/AOU_RX_CORE_IN_MUX.sv
../RTL/AOU_RX_CRD_CTRL.sv
../RTL/AOU_RX_FDI_IF.sv
../RTL/AOU_SLV_AXI_INFO.sv
../RTL/AOU_SYNC_FIFO_NS1M.sv
../RTL/AOU_TX_ARBITER.sv
../RTL/AOU_TX_AXI_BUFFER.sv
../RTL/AOU_TX_CORE.sv
../RTL/AOU_TX_CORE_OUT_MUX.sv
../RTL/AOU_TX_CRD_CTRL.sv
../RTL/AOU_TX_FDI_IF.sv
../RTL/AOU_TX_QOS_ARBITER.sv
../RTL/AOU_TX_QOS_BUFFER.sv
../RTL/AOU_CORE_RP.sv
../RTL/AOU_CORE.sv
../RTL/AOU_CORE_TOP.sv
../RTL/AOU_FDI_BRINGUP_CTRL.sv
../RTL/AOU_TOP.sv

// FDI flit decoder (passive; only instantiated under +define+FDI_LOG)
decoder/fdi_flit_decoder.sv

// cocotb harness top-level modules. All three are compiled together; the
// Makefile picks which one is the simulation TOPLEVEL.
aou_cocotb_top.sv
aou_cocotb_top_sp64b.sv
aou_cocotb_top_sp128b.sv
