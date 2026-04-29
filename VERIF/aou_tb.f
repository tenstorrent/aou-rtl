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
// AOU_CORE_TOP AXI VIP Testbench -- File List
// All paths relative to the VERIF/ directory
// =============================================================================
// FDI data widths are now SystemVerilog parameters (FDI_IF_WD0 / FDI_IF_WD1)
// on AOU_CORE_TOP and AOU_TOP. The +define+FDI_32B / FDI_64B / FDI_128B
// preprocessor switches have been removed; aou_tb.sv overrides the
// parameters on each DUT instance.
//
// TWO_PHY is intentionally NOT defined here: the parameter-refactor scope is
// single-PHY only. AOU_TOP and AOU_CORE_TOP both wrap the second-PHY ports
// and the I_PHY_TYPE port in `ifdef TWO_PHY` so the single-PHY build does
// not require it. TWO_PHY enablement is tracked in a separate change.

// Include paths
+incdir+axi_vip/include

// AXI VIP (compile order: pkg -> interface -> test classes)
axi_vip/src/axi_pkg.sv
axi_vip/src/axi_intf.sv
common_verification/src/rand_id_queue.sv
axi_vip/src/axi_test.sv
axi_vip/src/axi_sim_mem.sv

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
../RTL/AOU_SYNC_FIFO_NS1M_SREADY.sv
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
../RTL/AOU_TPSRAM.sv
../RTL/AOU_TOP.sv

// FDI flit decoder (must precede testbench)
decoder/fdi_flit_decoder.sv

// Testbench
aou_tb.sv
