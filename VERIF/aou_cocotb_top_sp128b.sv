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
//
//  Harness   : aou_cocotb_top_sp128b
//  Description: Thin SystemVerilog wrapper for the cocotb testbench.
//
//               Instantiates two AOU_CORE_TOP cores connected back-to-back
//               via single-PHY 128B FDI loopback. The four AXI interfaces
//               and two APB slave interfaces are exposed as flat top-level
//               ports using cocotbext-axi's canonical signal naming
//               (s_axi_d1_*, m_axi_d1_*, s_axi_d2_*, m_axi_d2_*,
//               apb1_*, apb2_*) so the Python side can use
//               AxiBus.from_prefix(dut, "<prefix>") /
//               ApbBus.from_prefix(dut, "<prefix>") directly.
//
//               Clocks and resets are top-level inputs driven by cocotb.
//               The APB activate write (paddr=0x8, pwdata=0x1) is driven
//               from Python by cocotbext.axi ApbMaster after each reset
//               deassertion; the harness has no SV-side APB activate
//               sequence and no o_apb_init_done handshake.
//
//               u_dut1: 512b AXI, RP_COUNT=1, FDI_CFG_SP_128B (FDI=1024b,
//                       2-step packing)
//               u_dut2: 256b AXI, RP_COUNT=1, FDI_CFG_SP_128B (FDI=1024b,
//                       2-step packing)
//
//               Two fdi_flit_decoder instances are retained under
//               `ifdef FDI_LOG for protocol-aware decode of the
//               loopback FDI traffic into dut{1,2}_fdi.log.
//
// *****************************************************************************

`timescale 1ns/1ps

module aou_cocotb_top_sp128b #(
    parameter int RP_COUNT          = 1,
    parameter int APB_ADDR_WD       = 32,
    parameter int APB_DATA_WD       = 32,
    parameter int AXI_ADDR_WIDTH    = 64,
    parameter int AXI_DATA_WIDTH    = 512,
    parameter int AXI_ID_WIDTH      = 10,
    parameter int AXI_STRB_WIDTH    = AXI_DATA_WIDTH / 8,
    parameter int D2_AXI_DATA_WIDTH = 256,
    parameter int D2_AXI_STRB_WIDTH = D2_AXI_DATA_WIDTH / 8
) (
    // ---------------- Clocks / resets (driven by cocotb) ----------------
    input  logic                            clk,
    input  logic                            resetn,
    input  logic                            pclk,
    input  logic                            presetn,

    // ============================================================
    // apb1 -- DUT1 APB slave (driven by Python ApbMaster on pclk/presetn)
    // pstrb is required by cocotbext-axi's ApbBus but unused by AOU; the
    // port is intentionally left dangling (no internal connection).
    // ============================================================
    input  logic                            apb1_psel,
    input  logic                            apb1_penable,
    input  logic [APB_ADDR_WD-1:0]          apb1_paddr,
    input  logic                            apb1_pwrite,
    input  logic [APB_DATA_WD-1:0]          apb1_pwdata,
    input  logic [APB_DATA_WD/8-1:0]        apb1_pstrb,
    output logic [APB_DATA_WD-1:0]          apb1_prdata,
    output logic                            apb1_pready,
    output logic                            apb1_pslverr,

    // ============================================================
    // apb2 -- DUT2 APB slave (driven by Python ApbMaster on pclk/presetn)
    // ============================================================
    input  logic                            apb2_psel,
    input  logic                            apb2_penable,
    input  logic [APB_ADDR_WD-1:0]          apb2_paddr,
    input  logic                            apb2_pwrite,
    input  logic [APB_DATA_WD-1:0]          apb2_pwdata,
    input  logic [APB_DATA_WD/8-1:0]        apb2_pstrb,
    output logic [APB_DATA_WD-1:0]          apb2_prdata,
    output logic                            apb2_pready,
    output logic                            apb2_pslverr,

    // ============================================================
    // s_axi_d1 -- DUT1 slave (driven by AxiMaster from cocotb, 512b)
    // ============================================================
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_d1_awid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_d1_awaddr,
    input  logic [7:0]                      s_axi_d1_awlen,
    input  logic [2:0]                      s_axi_d1_awsize,
    input  logic [1:0]                      s_axi_d1_awburst,
    input  logic                            s_axi_d1_awlock,
    input  logic [3:0]                      s_axi_d1_awcache,
    input  logic [2:0]                      s_axi_d1_awprot,
    input  logic [3:0]                      s_axi_d1_awqos,
    input  logic                            s_axi_d1_awvalid,
    output logic                            s_axi_d1_awready,
    input  logic [AXI_DATA_WIDTH-1:0]       s_axi_d1_wdata,
    input  logic [AXI_STRB_WIDTH-1:0]       s_axi_d1_wstrb,
    input  logic                            s_axi_d1_wlast,
    input  logic                            s_axi_d1_wvalid,
    output logic                            s_axi_d1_wready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_d1_bid,
    output logic [1:0]                      s_axi_d1_bresp,
    output logic                            s_axi_d1_bvalid,
    input  logic                            s_axi_d1_bready,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_d1_arid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_d1_araddr,
    input  logic [7:0]                      s_axi_d1_arlen,
    input  logic [2:0]                      s_axi_d1_arsize,
    input  logic [1:0]                      s_axi_d1_arburst,
    input  logic                            s_axi_d1_arlock,
    input  logic [3:0]                      s_axi_d1_arcache,
    input  logic [2:0]                      s_axi_d1_arprot,
    input  logic [3:0]                      s_axi_d1_arqos,
    input  logic                            s_axi_d1_arvalid,
    output logic                            s_axi_d1_arready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_d1_rid,
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_d1_rdata,
    output logic [1:0]                      s_axi_d1_rresp,
    output logic                            s_axi_d1_rlast,
    output logic                            s_axi_d1_rvalid,
    input  logic                            s_axi_d1_rready,

    // ============================================================
    // m_axi_d1 -- DUT1 master (terminated by AxiRam in cocotb, 512b)
    // ============================================================
    output logic [AXI_ID_WIDTH-1:0]         m_axi_d1_awid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_d1_awaddr,
    output logic [7:0]                      m_axi_d1_awlen,
    output logic [2:0]                      m_axi_d1_awsize,
    output logic [1:0]                      m_axi_d1_awburst,
    output logic                            m_axi_d1_awlock,
    output logic [3:0]                      m_axi_d1_awcache,
    output logic [2:0]                      m_axi_d1_awprot,
    output logic [3:0]                      m_axi_d1_awqos,
    output logic                            m_axi_d1_awvalid,
    input  logic                            m_axi_d1_awready,
    output logic [AXI_DATA_WIDTH-1:0]       m_axi_d1_wdata,
    output logic [AXI_STRB_WIDTH-1:0]       m_axi_d1_wstrb,
    output logic                            m_axi_d1_wlast,
    output logic                            m_axi_d1_wvalid,
    input  logic                            m_axi_d1_wready,
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_d1_bid,
    input  logic [1:0]                      m_axi_d1_bresp,
    input  logic                            m_axi_d1_bvalid,
    output logic                            m_axi_d1_bready,
    output logic [AXI_ID_WIDTH-1:0]         m_axi_d1_arid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_d1_araddr,
    output logic [7:0]                      m_axi_d1_arlen,
    output logic [2:0]                      m_axi_d1_arsize,
    output logic [1:0]                      m_axi_d1_arburst,
    output logic                            m_axi_d1_arlock,
    output logic [3:0]                      m_axi_d1_arcache,
    output logic [2:0]                      m_axi_d1_arprot,
    output logic [3:0]                      m_axi_d1_arqos,
    output logic                            m_axi_d1_arvalid,
    input  logic                            m_axi_d1_arready,
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_d1_rid,
    input  logic [AXI_DATA_WIDTH-1:0]       m_axi_d1_rdata,
    input  logic [1:0]                      m_axi_d1_rresp,
    input  logic                            m_axi_d1_rlast,
    input  logic                            m_axi_d1_rvalid,
    output logic                            m_axi_d1_rready,

    // ============================================================
    // s_axi_d2 -- DUT2 slave (driven by AxiMaster from cocotb, 256b)
    // ============================================================
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_d2_awid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_d2_awaddr,
    input  logic [7:0]                      s_axi_d2_awlen,
    input  logic [2:0]                      s_axi_d2_awsize,
    input  logic [1:0]                      s_axi_d2_awburst,
    input  logic                            s_axi_d2_awlock,
    input  logic [3:0]                      s_axi_d2_awcache,
    input  logic [2:0]                      s_axi_d2_awprot,
    input  logic [3:0]                      s_axi_d2_awqos,
    input  logic                            s_axi_d2_awvalid,
    output logic                            s_axi_d2_awready,
    input  logic [D2_AXI_DATA_WIDTH-1:0]    s_axi_d2_wdata,
    input  logic [D2_AXI_STRB_WIDTH-1:0]    s_axi_d2_wstrb,
    input  logic                            s_axi_d2_wlast,
    input  logic                            s_axi_d2_wvalid,
    output logic                            s_axi_d2_wready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_d2_bid,
    output logic [1:0]                      s_axi_d2_bresp,
    output logic                            s_axi_d2_bvalid,
    input  logic                            s_axi_d2_bready,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_d2_arid,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_d2_araddr,
    input  logic [7:0]                      s_axi_d2_arlen,
    input  logic [2:0]                      s_axi_d2_arsize,
    input  logic [1:0]                      s_axi_d2_arburst,
    input  logic                            s_axi_d2_arlock,
    input  logic [3:0]                      s_axi_d2_arcache,
    input  logic [2:0]                      s_axi_d2_arprot,
    input  logic [3:0]                      s_axi_d2_arqos,
    input  logic                            s_axi_d2_arvalid,
    output logic                            s_axi_d2_arready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_d2_rid,
    output logic [D2_AXI_DATA_WIDTH-1:0]    s_axi_d2_rdata,
    output logic [1:0]                      s_axi_d2_rresp,
    output logic                            s_axi_d2_rlast,
    output logic                            s_axi_d2_rvalid,
    input  logic                            s_axi_d2_rready,

    // ============================================================
    // m_axi_d2 -- DUT2 master (terminated by AxiRam in cocotb, 256b)
    // ============================================================
    output logic [AXI_ID_WIDTH-1:0]         m_axi_d2_awid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_d2_awaddr,
    output logic [7:0]                      m_axi_d2_awlen,
    output logic [2:0]                      m_axi_d2_awsize,
    output logic [1:0]                      m_axi_d2_awburst,
    output logic                            m_axi_d2_awlock,
    output logic [3:0]                      m_axi_d2_awcache,
    output logic [2:0]                      m_axi_d2_awprot,
    output logic [3:0]                      m_axi_d2_awqos,
    output logic                            m_axi_d2_awvalid,
    input  logic                            m_axi_d2_awready,
    output logic [D2_AXI_DATA_WIDTH-1:0]    m_axi_d2_wdata,
    output logic [D2_AXI_STRB_WIDTH-1:0]    m_axi_d2_wstrb,
    output logic                            m_axi_d2_wlast,
    output logic                            m_axi_d2_wvalid,
    input  logic                            m_axi_d2_wready,
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_d2_bid,
    input  logic [1:0]                      m_axi_d2_bresp,
    input  logic                            m_axi_d2_bvalid,
    output logic                            m_axi_d2_bready,
    output logic [AXI_ID_WIDTH-1:0]         m_axi_d2_arid,
    output logic [AXI_ADDR_WIDTH-1:0]       m_axi_d2_araddr,
    output logic [7:0]                      m_axi_d2_arlen,
    output logic [2:0]                      m_axi_d2_arsize,
    output logic [1:0]                      m_axi_d2_arburst,
    output logic                            m_axi_d2_arlock,
    output logic [3:0]                      m_axi_d2_arcache,
    output logic [2:0]                      m_axi_d2_arprot,
    output logic [3:0]                      m_axi_d2_arqos,
    output logic                            m_axi_d2_arvalid,
    input  logic                            m_axi_d2_arready,
    input  logic [AXI_ID_WIDTH-1:0]         m_axi_d2_rid,
    input  logic [D2_AXI_DATA_WIDTH-1:0]    m_axi_d2_rdata,
    input  logic [1:0]                      m_axi_d2_rresp,
    input  logic                            m_axi_d2_rlast,
    input  logic                            m_axi_d2_rvalid,
    output logic                            m_axi_d2_rready
);

    // ================================================================
    // 1D <-> 2D packed-array glue (RP_COUNT=1)
    // AOU_CORE_TOP wants [RP_COUNT-1:0][...] packed arrays on its AXI ports.
    // For RP_COUNT=1 this is essentially a re-wrap.
    // ================================================================

    // ---- DUT1 SI ----
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_si_awid    = s_axi_d1_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_si_awaddr  = s_axi_d1_awaddr;
    wire [RP_COUNT-1:0][7:0]                d1_si_awlen   = s_axi_d1_awlen;
    wire [RP_COUNT-1:0][2:0]                d1_si_awsize  = s_axi_d1_awsize;
    wire [RP_COUNT-1:0][1:0]                d1_si_awburst = s_axi_d1_awburst;
    wire [RP_COUNT-1:0]                     d1_si_awlock  = s_axi_d1_awlock;
    wire [RP_COUNT-1:0][3:0]                d1_si_awcache = s_axi_d1_awcache;
    wire [RP_COUNT-1:0][2:0]                d1_si_awprot  = s_axi_d1_awprot;
    wire [RP_COUNT-1:0][3:0]                d1_si_awqos   = s_axi_d1_awqos;
    wire [RP_COUNT-1:0]                     d1_si_awvalid = s_axi_d1_awvalid;
    wire [RP_COUNT-1:0]                     d1_si_awready;
    assign s_axi_d1_awready = d1_si_awready[0];

    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_si_wdata  = s_axi_d1_wdata;
    wire [RP_COUNT-1:0][AXI_STRB_WIDTH-1:0] d1_si_wstrb  = s_axi_d1_wstrb;
    wire [RP_COUNT-1:0]                     d1_si_wlast  = s_axi_d1_wlast;
    wire [RP_COUNT-1:0]                     d1_si_wvalid = s_axi_d1_wvalid;
    wire [RP_COUNT-1:0]                     d1_si_wready;
    assign s_axi_d1_wready = d1_si_wready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_si_bid;
    wire [RP_COUNT-1:0][1:0]                d1_si_bresp;
    wire [RP_COUNT-1:0]                     d1_si_bvalid;
    wire [RP_COUNT-1:0]                     d1_si_bready = s_axi_d1_bready;
    assign s_axi_d1_bid    = d1_si_bid[0];
    assign s_axi_d1_bresp  = d1_si_bresp[0];
    assign s_axi_d1_bvalid = d1_si_bvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_si_arid    = s_axi_d1_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_si_araddr  = s_axi_d1_araddr;
    wire [RP_COUNT-1:0][7:0]                d1_si_arlen   = s_axi_d1_arlen;
    wire [RP_COUNT-1:0][2:0]                d1_si_arsize  = s_axi_d1_arsize;
    wire [RP_COUNT-1:0][1:0]                d1_si_arburst = s_axi_d1_arburst;
    wire [RP_COUNT-1:0]                     d1_si_arlock  = s_axi_d1_arlock;
    wire [RP_COUNT-1:0][3:0]                d1_si_arcache = s_axi_d1_arcache;
    wire [RP_COUNT-1:0][2:0]                d1_si_arprot  = s_axi_d1_arprot;
    wire [RP_COUNT-1:0][3:0]                d1_si_arqos   = s_axi_d1_arqos;
    wire [RP_COUNT-1:0]                     d1_si_arvalid = s_axi_d1_arvalid;
    wire [RP_COUNT-1:0]                     d1_si_arready;
    assign s_axi_d1_arready = d1_si_arready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_si_rid;
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_si_rdata;
    wire [RP_COUNT-1:0][1:0]                d1_si_rresp;
    wire [RP_COUNT-1:0]                     d1_si_rlast;
    wire [RP_COUNT-1:0]                     d1_si_rvalid;
    wire [RP_COUNT-1:0]                     d1_si_rready = s_axi_d1_rready;
    assign s_axi_d1_rid    = d1_si_rid[0];
    assign s_axi_d1_rdata  = d1_si_rdata[0];
    assign s_axi_d1_rresp  = d1_si_rresp[0];
    assign s_axi_d1_rlast  = d1_si_rlast[0];
    assign s_axi_d1_rvalid = d1_si_rvalid[0];

    // ---- DUT1 MI ----
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_mi_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_mi_awaddr;
    wire [RP_COUNT-1:0][7:0]                d1_mi_awlen;
    wire [RP_COUNT-1:0][2:0]                d1_mi_awsize;
    wire [RP_COUNT-1:0][1:0]                d1_mi_awburst;
    wire [RP_COUNT-1:0]                     d1_mi_awlock;
    wire [RP_COUNT-1:0][3:0]                d1_mi_awcache;
    wire [RP_COUNT-1:0][2:0]                d1_mi_awprot;
    wire [RP_COUNT-1:0][3:0]                d1_mi_awqos;
    wire [RP_COUNT-1:0]                     d1_mi_awvalid;
    wire [RP_COUNT-1:0]                     d1_mi_awready = m_axi_d1_awready;
    assign m_axi_d1_awid    = d1_mi_awid[0];
    assign m_axi_d1_awaddr  = d1_mi_awaddr[0];
    assign m_axi_d1_awlen   = d1_mi_awlen[0];
    assign m_axi_d1_awsize  = d1_mi_awsize[0];
    assign m_axi_d1_awburst = d1_mi_awburst[0];
    assign m_axi_d1_awlock  = d1_mi_awlock[0];
    assign m_axi_d1_awcache = d1_mi_awcache[0];
    assign m_axi_d1_awprot  = d1_mi_awprot[0];
    assign m_axi_d1_awqos   = d1_mi_awqos[0];
    assign m_axi_d1_awvalid = d1_mi_awvalid[0];

    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_mi_wdata;
    wire [RP_COUNT-1:0][AXI_STRB_WIDTH-1:0] d1_mi_wstrb;
    wire [RP_COUNT-1:0]                     d1_mi_wlast;
    wire [RP_COUNT-1:0]                     d1_mi_wvalid;
    wire [RP_COUNT-1:0]                     d1_mi_wready = m_axi_d1_wready;
    assign m_axi_d1_wdata  = d1_mi_wdata[0];
    assign m_axi_d1_wstrb  = d1_mi_wstrb[0];
    assign m_axi_d1_wlast  = d1_mi_wlast[0];
    assign m_axi_d1_wvalid = d1_mi_wvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_mi_bid    = m_axi_d1_bid;
    wire [RP_COUNT-1:0][1:0]                d1_mi_bresp  = m_axi_d1_bresp;
    wire [RP_COUNT-1:0]                     d1_mi_bvalid = m_axi_d1_bvalid;
    wire [RP_COUNT-1:0]                     d1_mi_bready;
    assign m_axi_d1_bready = d1_mi_bready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_mi_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_mi_araddr;
    wire [RP_COUNT-1:0][7:0]                d1_mi_arlen;
    wire [RP_COUNT-1:0][2:0]                d1_mi_arsize;
    wire [RP_COUNT-1:0][1:0]                d1_mi_arburst;
    wire [RP_COUNT-1:0]                     d1_mi_arlock;
    wire [RP_COUNT-1:0][3:0]                d1_mi_arcache;
    wire [RP_COUNT-1:0][2:0]                d1_mi_arprot;
    wire [RP_COUNT-1:0][3:0]                d1_mi_arqos;
    wire [RP_COUNT-1:0]                     d1_mi_arvalid;
    wire [RP_COUNT-1:0]                     d1_mi_arready = m_axi_d1_arready;
    assign m_axi_d1_arid    = d1_mi_arid[0];
    assign m_axi_d1_araddr  = d1_mi_araddr[0];
    assign m_axi_d1_arlen   = d1_mi_arlen[0];
    assign m_axi_d1_arsize  = d1_mi_arsize[0];
    assign m_axi_d1_arburst = d1_mi_arburst[0];
    assign m_axi_d1_arlock  = d1_mi_arlock[0];
    assign m_axi_d1_arcache = d1_mi_arcache[0];
    assign m_axi_d1_arprot  = d1_mi_arprot[0];
    assign m_axi_d1_arqos   = d1_mi_arqos[0];
    assign m_axi_d1_arvalid = d1_mi_arvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_mi_rid    = m_axi_d1_rid;
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_mi_rdata  = m_axi_d1_rdata;
    wire [RP_COUNT-1:0][1:0]                d1_mi_rresp  = m_axi_d1_rresp;
    wire [RP_COUNT-1:0]                     d1_mi_rlast  = m_axi_d1_rlast;
    wire [RP_COUNT-1:0]                     d1_mi_rvalid = m_axi_d1_rvalid;
    wire [RP_COUNT-1:0]                     d1_mi_rready;
    assign m_axi_d1_rready = d1_mi_rready[0];

    // ---- DUT2 SI ----
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_si_awid    = s_axi_d2_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    d2_si_awaddr  = s_axi_d2_awaddr;
    wire [RP_COUNT-1:0][7:0]                   d2_si_awlen   = s_axi_d2_awlen;
    wire [RP_COUNT-1:0][2:0]                   d2_si_awsize  = s_axi_d2_awsize;
    wire [RP_COUNT-1:0][1:0]                   d2_si_awburst = s_axi_d2_awburst;
    wire [RP_COUNT-1:0]                        d2_si_awlock  = s_axi_d2_awlock;
    wire [RP_COUNT-1:0][3:0]                   d2_si_awcache = s_axi_d2_awcache;
    wire [RP_COUNT-1:0][2:0]                   d2_si_awprot  = s_axi_d2_awprot;
    wire [RP_COUNT-1:0][3:0]                   d2_si_awqos   = s_axi_d2_awqos;
    wire [RP_COUNT-1:0]                        d2_si_awvalid = s_axi_d2_awvalid;
    wire [RP_COUNT-1:0]                        d2_si_awready;
    assign s_axi_d2_awready = d2_si_awready[0];

    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_si_wdata  = s_axi_d2_wdata;
    wire [RP_COUNT-1:0][D2_AXI_STRB_WIDTH-1:0] d2_si_wstrb  = s_axi_d2_wstrb;
    wire [RP_COUNT-1:0]                        d2_si_wlast  = s_axi_d2_wlast;
    wire [RP_COUNT-1:0]                        d2_si_wvalid = s_axi_d2_wvalid;
    wire [RP_COUNT-1:0]                        d2_si_wready;
    assign s_axi_d2_wready = d2_si_wready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_si_bid;
    wire [RP_COUNT-1:0][1:0]                   d2_si_bresp;
    wire [RP_COUNT-1:0]                        d2_si_bvalid;
    wire [RP_COUNT-1:0]                        d2_si_bready = s_axi_d2_bready;
    assign s_axi_d2_bid    = d2_si_bid[0];
    assign s_axi_d2_bresp  = d2_si_bresp[0];
    assign s_axi_d2_bvalid = d2_si_bvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_si_arid    = s_axi_d2_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    d2_si_araddr  = s_axi_d2_araddr;
    wire [RP_COUNT-1:0][7:0]                   d2_si_arlen   = s_axi_d2_arlen;
    wire [RP_COUNT-1:0][2:0]                   d2_si_arsize  = s_axi_d2_arsize;
    wire [RP_COUNT-1:0][1:0]                   d2_si_arburst = s_axi_d2_arburst;
    wire [RP_COUNT-1:0]                        d2_si_arlock  = s_axi_d2_arlock;
    wire [RP_COUNT-1:0][3:0]                   d2_si_arcache = s_axi_d2_arcache;
    wire [RP_COUNT-1:0][2:0]                   d2_si_arprot  = s_axi_d2_arprot;
    wire [RP_COUNT-1:0][3:0]                   d2_si_arqos   = s_axi_d2_arqos;
    wire [RP_COUNT-1:0]                        d2_si_arvalid = s_axi_d2_arvalid;
    wire [RP_COUNT-1:0]                        d2_si_arready;
    assign s_axi_d2_arready = d2_si_arready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_si_rid;
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_si_rdata;
    wire [RP_COUNT-1:0][1:0]                   d2_si_rresp;
    wire [RP_COUNT-1:0]                        d2_si_rlast;
    wire [RP_COUNT-1:0]                        d2_si_rvalid;
    wire [RP_COUNT-1:0]                        d2_si_rready = s_axi_d2_rready;
    assign s_axi_d2_rid    = d2_si_rid[0];
    assign s_axi_d2_rdata  = d2_si_rdata[0];
    assign s_axi_d2_rresp  = d2_si_rresp[0];
    assign s_axi_d2_rlast  = d2_si_rlast[0];
    assign s_axi_d2_rvalid = d2_si_rvalid[0];

    // ---- DUT2 MI ----
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_mi_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    d2_mi_awaddr;
    wire [RP_COUNT-1:0][7:0]                   d2_mi_awlen;
    wire [RP_COUNT-1:0][2:0]                   d2_mi_awsize;
    wire [RP_COUNT-1:0][1:0]                   d2_mi_awburst;
    wire [RP_COUNT-1:0]                        d2_mi_awlock;
    wire [RP_COUNT-1:0][3:0]                   d2_mi_awcache;
    wire [RP_COUNT-1:0][2:0]                   d2_mi_awprot;
    wire [RP_COUNT-1:0][3:0]                   d2_mi_awqos;
    wire [RP_COUNT-1:0]                        d2_mi_awvalid;
    wire [RP_COUNT-1:0]                        d2_mi_awready = m_axi_d2_awready;
    assign m_axi_d2_awid    = d2_mi_awid[0];
    assign m_axi_d2_awaddr  = d2_mi_awaddr[0];
    assign m_axi_d2_awlen   = d2_mi_awlen[0];
    assign m_axi_d2_awsize  = d2_mi_awsize[0];
    assign m_axi_d2_awburst = d2_mi_awburst[0];
    assign m_axi_d2_awlock  = d2_mi_awlock[0];
    assign m_axi_d2_awcache = d2_mi_awcache[0];
    assign m_axi_d2_awprot  = d2_mi_awprot[0];
    assign m_axi_d2_awqos   = d2_mi_awqos[0];
    assign m_axi_d2_awvalid = d2_mi_awvalid[0];

    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_mi_wdata;
    wire [RP_COUNT-1:0][D2_AXI_STRB_WIDTH-1:0] d2_mi_wstrb;
    wire [RP_COUNT-1:0]                        d2_mi_wlast;
    wire [RP_COUNT-1:0]                        d2_mi_wvalid;
    wire [RP_COUNT-1:0]                        d2_mi_wready = m_axi_d2_wready;
    assign m_axi_d2_wdata  = d2_mi_wdata[0];
    assign m_axi_d2_wstrb  = d2_mi_wstrb[0];
    assign m_axi_d2_wlast  = d2_mi_wlast[0];
    assign m_axi_d2_wvalid = d2_mi_wvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_mi_bid    = m_axi_d2_bid;
    wire [RP_COUNT-1:0][1:0]                   d2_mi_bresp  = m_axi_d2_bresp;
    wire [RP_COUNT-1:0]                        d2_mi_bvalid = m_axi_d2_bvalid;
    wire [RP_COUNT-1:0]                        d2_mi_bready;
    assign m_axi_d2_bready = d2_mi_bready[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_mi_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0]    d2_mi_araddr;
    wire [RP_COUNT-1:0][7:0]                   d2_mi_arlen;
    wire [RP_COUNT-1:0][2:0]                   d2_mi_arsize;
    wire [RP_COUNT-1:0][1:0]                   d2_mi_arburst;
    wire [RP_COUNT-1:0]                        d2_mi_arlock;
    wire [RP_COUNT-1:0][3:0]                   d2_mi_arcache;
    wire [RP_COUNT-1:0][2:0]                   d2_mi_arprot;
    wire [RP_COUNT-1:0][3:0]                   d2_mi_arqos;
    wire [RP_COUNT-1:0]                        d2_mi_arvalid;
    wire [RP_COUNT-1:0]                        d2_mi_arready = m_axi_d2_arready;
    assign m_axi_d2_arid    = d2_mi_arid[0];
    assign m_axi_d2_araddr  = d2_mi_araddr[0];
    assign m_axi_d2_arlen   = d2_mi_arlen[0];
    assign m_axi_d2_arsize  = d2_mi_arsize[0];
    assign m_axi_d2_arburst = d2_mi_arburst[0];
    assign m_axi_d2_arlock  = d2_mi_arlock[0];
    assign m_axi_d2_arcache = d2_mi_arcache[0];
    assign m_axi_d2_arprot  = d2_mi_arprot[0];
    assign m_axi_d2_arqos   = d2_mi_arqos[0];
    assign m_axi_d2_arvalid = d2_mi_arvalid[0];

    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]      d2_mi_rid    = m_axi_d2_rid;
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_mi_rdata  = m_axi_d2_rdata;
    wire [RP_COUNT-1:0][1:0]                   d2_mi_rresp  = m_axi_d2_rresp;
    wire [RP_COUNT-1:0]                        d2_mi_rlast  = m_axi_d2_rlast;
    wire [RP_COUNT-1:0]                        d2_mi_rvalid = m_axi_d2_rvalid;
    wire [RP_COUNT-1:0]                        d2_mi_rready;
    assign m_axi_d2_rready = d2_mi_rready[0];

    // ================================================================
    // FDI cross-connect wires (single-PHY 128B / 1024b)
    // ================================================================
    wire [1023:0] dut1_lp_128b_data;
    wire          dut1_lp_128b_valid;
    wire          dut1_lp_128b_irdy;
    wire          dut1_lp_128b_stallack;

    wire [1023:0] dut2_lp_128b_data;
    wire          dut2_lp_128b_valid;
    wire          dut2_lp_128b_irdy;
    wire          dut2_lp_128b_stallack;

`ifdef FDI_LOG
    fdi_flit_decoder #(.LOG_FILE("dut1_fdi_sp128b.log"), .FDI_BYTES(128)) u_fdi_dec1 (
        .clk    (clk),
        .resetn (resetn),
        .valid  (dut1_lp_128b_valid),
        .data   (dut1_lp_128b_data)
    );
    fdi_flit_decoder #(.LOG_FILE("dut2_fdi_sp128b.log"), .FDI_BYTES(128)) u_fdi_dec2 (
        .clk    (clk),
        .resetn (resetn),
        .valid  (dut2_lp_128b_valid),
        .data   (dut2_lp_128b_data)
    );
`endif

    // ================================================================
    // u_dut1 -- 512b AXI, single-PHY 128B FDI, RP_COUNT=1
    // ================================================================
    AOU_CORE_TOP #(
        .RP_COUNT    (RP_COUNT),
        .FDI_CONFIG  (packet_def_pkg::FDI_CFG_SP_128B),
        .APB_ADDR_WD (APB_ADDR_WD),
        .APB_DATA_WD (APB_DATA_WD)
    ) u_dut1 (
        .I_CLK                       (clk),
        .I_RESETN                    (resetn),
        .I_PCLK                      (pclk),
        .I_PRESETN                   (presetn),

        .I_AOU_APB_SI0_PSEL          (apb1_psel),
        .I_AOU_APB_SI0_PENABLE       (apb1_penable),
        .I_AOU_APB_SI0_PADDR         (apb1_paddr),
        .I_AOU_APB_SI0_PWRITE        (apb1_pwrite),
        .I_AOU_APB_SI0_PWDATA        (apb1_pwdata),
        .O_AOU_APB_SI0_PRDATA        (apb1_prdata),
        .O_AOU_APB_SI0_PREADY        (apb1_pready),
        .O_AOU_APB_SI0_PSLVERR       (apb1_pslverr),

        // AXI MI
        .O_AOU_RX_AXI_M_ARID         (d1_mi_arid),
        .O_AOU_RX_AXI_M_ARADDR       (d1_mi_araddr),
        .O_AOU_RX_AXI_M_ARLEN        (d1_mi_arlen),
        .O_AOU_RX_AXI_M_ARSIZE       (d1_mi_arsize),
        .O_AOU_RX_AXI_M_ARBURST      (d1_mi_arburst),
        .O_AOU_RX_AXI_M_ARLOCK       (d1_mi_arlock),
        .O_AOU_RX_AXI_M_ARCACHE      (d1_mi_arcache),
        .O_AOU_RX_AXI_M_ARPROT       (d1_mi_arprot),
        .O_AOU_RX_AXI_M_ARQOS        (d1_mi_arqos),
        .O_AOU_RX_AXI_M_ARVALID      (d1_mi_arvalid),
        .I_AOU_RX_AXI_M_ARREADY      (d1_mi_arready),
        .I_AOU_TX_AXI_M_RID          (d1_mi_rid),
        .I_AOU_TX_AXI_M_RDATA        (d1_mi_rdata),
        .I_AOU_TX_AXI_M_RRESP        (d1_mi_rresp),
        .I_AOU_TX_AXI_M_RLAST        (d1_mi_rlast),
        .I_AOU_TX_AXI_M_RVALID       (d1_mi_rvalid),
        .O_AOU_TX_AXI_M_RREADY       (d1_mi_rready),
        .O_AOU_RX_AXI_M_AWID         (d1_mi_awid),
        .O_AOU_RX_AXI_M_AWADDR       (d1_mi_awaddr),
        .O_AOU_RX_AXI_M_AWLEN        (d1_mi_awlen),
        .O_AOU_RX_AXI_M_AWSIZE       (d1_mi_awsize),
        .O_AOU_RX_AXI_M_AWBURST      (d1_mi_awburst),
        .O_AOU_RX_AXI_M_AWLOCK       (d1_mi_awlock),
        .O_AOU_RX_AXI_M_AWCACHE      (d1_mi_awcache),
        .O_AOU_RX_AXI_M_AWPROT       (d1_mi_awprot),
        .O_AOU_RX_AXI_M_AWQOS        (d1_mi_awqos),
        .O_AOU_RX_AXI_M_AWVALID      (d1_mi_awvalid),
        .I_AOU_RX_AXI_M_AWREADY      (d1_mi_awready),
        .O_AOU_RX_AXI_M_WDATA        (d1_mi_wdata),
        .O_AOU_RX_AXI_M_WSTRB        (d1_mi_wstrb),
        .O_AOU_RX_AXI_M_WLAST        (d1_mi_wlast),
        .O_AOU_RX_AXI_M_WVALID       (d1_mi_wvalid),
        .I_AOU_RX_AXI_M_WREADY       (d1_mi_wready),
        .I_AOU_TX_AXI_M_BID          (d1_mi_bid),
        .I_AOU_TX_AXI_M_BRESP        (d1_mi_bresp),
        .I_AOU_TX_AXI_M_BVALID       (d1_mi_bvalid),
        .O_AOU_TX_AXI_M_BREADY       (d1_mi_bready),

        // AXI SI
        .I_AOU_TX_AXI_S_ARID         (d1_si_arid),
        .I_AOU_TX_AXI_S_ARADDR       (d1_si_araddr),
        .I_AOU_TX_AXI_S_ARLEN        (d1_si_arlen),
        .I_AOU_TX_AXI_S_ARSIZE       (d1_si_arsize),
        .I_AOU_TX_AXI_S_ARBURST      (d1_si_arburst),
        .I_AOU_TX_AXI_S_ARLOCK       (d1_si_arlock),
        .I_AOU_TX_AXI_S_ARCACHE      (d1_si_arcache),
        .I_AOU_TX_AXI_S_ARPROT       (d1_si_arprot),
        .I_AOU_TX_AXI_S_ARQOS        (d1_si_arqos),
        .I_AOU_TX_AXI_S_ARVALID      (d1_si_arvalid),
        .O_AOU_TX_AXI_S_ARREADY      (d1_si_arready),
        .O_AOU_RX_AXI_S_RID          (d1_si_rid),
        .O_AOU_RX_AXI_S_RDATA        (d1_si_rdata),
        .O_AOU_RX_AXI_S_RRESP        (d1_si_rresp),
        .O_AOU_RX_AXI_S_RLAST        (d1_si_rlast),
        .O_AOU_RX_AXI_S_RVALID       (d1_si_rvalid),
        .I_AOU_RX_AXI_S_RREADY       (d1_si_rready),
        .I_AOU_TX_AXI_S_AWID         (d1_si_awid),
        .I_AOU_TX_AXI_S_AWADDR       (d1_si_awaddr),
        .I_AOU_TX_AXI_S_AWLEN        (d1_si_awlen),
        .I_AOU_TX_AXI_S_AWSIZE       (d1_si_awsize),
        .I_AOU_TX_AXI_S_AWBURST      (d1_si_awburst),
        .I_AOU_TX_AXI_S_AWLOCK       (d1_si_awlock),
        .I_AOU_TX_AXI_S_AWCACHE      (d1_si_awcache),
        .I_AOU_TX_AXI_S_AWPROT       (d1_si_awprot),
        .I_AOU_TX_AXI_S_AWQOS        (d1_si_awqos),
        .I_AOU_TX_AXI_S_AWVALID      (d1_si_awvalid),
        .O_AOU_TX_AXI_S_AWREADY      (d1_si_awready),
        .I_AOU_TX_AXI_S_WDATA        (d1_si_wdata),
        .I_AOU_TX_AXI_S_WSTRB        (d1_si_wstrb),
        .I_AOU_TX_AXI_S_WLAST        (d1_si_wlast),
        .I_AOU_TX_AXI_S_WVALID       (d1_si_wvalid),
        .O_AOU_TX_AXI_S_WREADY       (d1_si_wready),
        .O_AOU_RX_AXI_S_BID          (d1_si_bid),
        .O_AOU_RX_AXI_S_BRESP        (d1_si_bresp),
        .O_AOU_RX_AXI_S_BVALID       (d1_si_bvalid),
        .I_AOU_RX_AXI_S_BREADY       (d1_si_bready),

        // FDI: u_dut1 RX <- u_dut2 TX, u_dut1 TX -> u_dut2 RX
        .I_FDI_PL_0_VALID            (dut2_lp_128b_valid),
        .I_FDI_PL_0_DATA             (dut2_lp_128b_data),
        .I_FDI_PL_0_FLIT_CANCEL      (1'b0),
        .I_FDI_PL_0_TRDY             (1'b1),
        .I_FDI_PL_0_STALLREQ         (1'b0),
        .I_FDI_PL_0_STATE_STS        (4'h1),
        .O_FDI_LP_0_DATA             (dut1_lp_128b_data),
        .O_FDI_LP_0_VALID            (dut1_lp_128b_valid),
        .O_FDI_LP_0_IRDY             (dut1_lp_128b_irdy),
        .O_FDI_LP_0_STALLACK         (dut1_lp_128b_stallack),

        .INT_REQ_LINKRESET            (),
        .INT_SI0_ID_MISMATCH          (),
        .INT_MI0_ID_MISMATCH          (),
        .INT_EARLY_RESP_ERR           (),
        .INT_ACTIVATE_START           (),
        .INT_DEACTIVATE_START         (),

        .I_INT_FSM_IN_ACTIVE          (1'b1),
        .I_MST_BUS_CLEANY_COMPLETE    (1'b1),
        .I_SLV_BUS_CLEANY_COMPLETE    (1'b1),
        .O_AOU_ACTIVATE_ST_DISABLED   (),
        .O_AOU_ACTIVATE_ST_ENABLED    (),
        .O_AOU_REQ_LINKRESET          (),

        .TIEL_DFT_MODESCAN            (1'b0)
    );

    // ================================================================
    // u_dut2 -- 256b AXI, single-PHY 128B FDI, RP_COUNT=1
    // ================================================================
    // u_dut2 needs all four RP*_AXI_DATA_WD overrides because AOU_CORE_TOP's
    // port widths are sized to max4(RP0..RP3_AXI_DATA_WD); leaving any at the
    // default (512) would force 512-bit ports and create width truncations
    // against the 256-bit harness wires.
    AOU_CORE_TOP #(
        .RP_COUNT        (RP_COUNT),
        .RP0_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP1_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP2_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP3_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .FDI_CONFIG      (packet_def_pkg::FDI_CFG_SP_128B),
        .APB_ADDR_WD     (APB_ADDR_WD),
        .APB_DATA_WD     (APB_DATA_WD)
    ) u_dut2 (
        .I_CLK                       (clk),
        .I_RESETN                    (resetn),
        .I_PCLK                      (pclk),
        .I_PRESETN                   (presetn),

        .I_AOU_APB_SI0_PSEL          (apb2_psel),
        .I_AOU_APB_SI0_PENABLE       (apb2_penable),
        .I_AOU_APB_SI0_PADDR         (apb2_paddr),
        .I_AOU_APB_SI0_PWRITE        (apb2_pwrite),
        .I_AOU_APB_SI0_PWDATA        (apb2_pwdata),
        .O_AOU_APB_SI0_PRDATA        (apb2_prdata),
        .O_AOU_APB_SI0_PREADY        (apb2_pready),
        .O_AOU_APB_SI0_PSLVERR       (apb2_pslverr),

        // AXI MI
        .O_AOU_RX_AXI_M_ARID         (d2_mi_arid),
        .O_AOU_RX_AXI_M_ARADDR       (d2_mi_araddr),
        .O_AOU_RX_AXI_M_ARLEN        (d2_mi_arlen),
        .O_AOU_RX_AXI_M_ARSIZE       (d2_mi_arsize),
        .O_AOU_RX_AXI_M_ARBURST      (d2_mi_arburst),
        .O_AOU_RX_AXI_M_ARLOCK       (d2_mi_arlock),
        .O_AOU_RX_AXI_M_ARCACHE      (d2_mi_arcache),
        .O_AOU_RX_AXI_M_ARPROT       (d2_mi_arprot),
        .O_AOU_RX_AXI_M_ARQOS        (d2_mi_arqos),
        .O_AOU_RX_AXI_M_ARVALID      (d2_mi_arvalid),
        .I_AOU_RX_AXI_M_ARREADY      (d2_mi_arready),
        .I_AOU_TX_AXI_M_RID          (d2_mi_rid),
        .I_AOU_TX_AXI_M_RDATA        (d2_mi_rdata),
        .I_AOU_TX_AXI_M_RRESP        (d2_mi_rresp),
        .I_AOU_TX_AXI_M_RLAST        (d2_mi_rlast),
        .I_AOU_TX_AXI_M_RVALID       (d2_mi_rvalid),
        .O_AOU_TX_AXI_M_RREADY       (d2_mi_rready),
        .O_AOU_RX_AXI_M_AWID         (d2_mi_awid),
        .O_AOU_RX_AXI_M_AWADDR       (d2_mi_awaddr),
        .O_AOU_RX_AXI_M_AWLEN        (d2_mi_awlen),
        .O_AOU_RX_AXI_M_AWSIZE       (d2_mi_awsize),
        .O_AOU_RX_AXI_M_AWBURST      (d2_mi_awburst),
        .O_AOU_RX_AXI_M_AWLOCK       (d2_mi_awlock),
        .O_AOU_RX_AXI_M_AWCACHE      (d2_mi_awcache),
        .O_AOU_RX_AXI_M_AWPROT       (d2_mi_awprot),
        .O_AOU_RX_AXI_M_AWQOS        (d2_mi_awqos),
        .O_AOU_RX_AXI_M_AWVALID      (d2_mi_awvalid),
        .I_AOU_RX_AXI_M_AWREADY      (d2_mi_awready),
        .O_AOU_RX_AXI_M_WDATA        (d2_mi_wdata),
        .O_AOU_RX_AXI_M_WSTRB        (d2_mi_wstrb),
        .O_AOU_RX_AXI_M_WLAST        (d2_mi_wlast),
        .O_AOU_RX_AXI_M_WVALID       (d2_mi_wvalid),
        .I_AOU_RX_AXI_M_WREADY       (d2_mi_wready),
        .I_AOU_TX_AXI_M_BID          (d2_mi_bid),
        .I_AOU_TX_AXI_M_BRESP        (d2_mi_bresp),
        .I_AOU_TX_AXI_M_BVALID       (d2_mi_bvalid),
        .O_AOU_TX_AXI_M_BREADY       (d2_mi_bready),

        // AXI SI
        .I_AOU_TX_AXI_S_ARID         (d2_si_arid),
        .I_AOU_TX_AXI_S_ARADDR       (d2_si_araddr),
        .I_AOU_TX_AXI_S_ARLEN        (d2_si_arlen),
        .I_AOU_TX_AXI_S_ARSIZE       (d2_si_arsize),
        .I_AOU_TX_AXI_S_ARBURST      (d2_si_arburst),
        .I_AOU_TX_AXI_S_ARLOCK       (d2_si_arlock),
        .I_AOU_TX_AXI_S_ARCACHE      (d2_si_arcache),
        .I_AOU_TX_AXI_S_ARPROT       (d2_si_arprot),
        .I_AOU_TX_AXI_S_ARQOS        (d2_si_arqos),
        .I_AOU_TX_AXI_S_ARVALID      (d2_si_arvalid),
        .O_AOU_TX_AXI_S_ARREADY      (d2_si_arready),
        .O_AOU_RX_AXI_S_RID          (d2_si_rid),
        .O_AOU_RX_AXI_S_RDATA        (d2_si_rdata),
        .O_AOU_RX_AXI_S_RRESP        (d2_si_rresp),
        .O_AOU_RX_AXI_S_RLAST        (d2_si_rlast),
        .O_AOU_RX_AXI_S_RVALID       (d2_si_rvalid),
        .I_AOU_RX_AXI_S_RREADY       (d2_si_rready),
        .I_AOU_TX_AXI_S_AWID         (d2_si_awid),
        .I_AOU_TX_AXI_S_AWADDR       (d2_si_awaddr),
        .I_AOU_TX_AXI_S_AWLEN        (d2_si_awlen),
        .I_AOU_TX_AXI_S_AWSIZE       (d2_si_awsize),
        .I_AOU_TX_AXI_S_AWBURST      (d2_si_awburst),
        .I_AOU_TX_AXI_S_AWLOCK       (d2_si_awlock),
        .I_AOU_TX_AXI_S_AWCACHE      (d2_si_awcache),
        .I_AOU_TX_AXI_S_AWPROT       (d2_si_awprot),
        .I_AOU_TX_AXI_S_AWQOS        (d2_si_awqos),
        .I_AOU_TX_AXI_S_AWVALID      (d2_si_awvalid),
        .O_AOU_TX_AXI_S_AWREADY      (d2_si_awready),
        .I_AOU_TX_AXI_S_WDATA        (d2_si_wdata),
        .I_AOU_TX_AXI_S_WSTRB        (d2_si_wstrb),
        .I_AOU_TX_AXI_S_WLAST        (d2_si_wlast),
        .I_AOU_TX_AXI_S_WVALID       (d2_si_wvalid),
        .O_AOU_TX_AXI_S_WREADY       (d2_si_wready),
        .O_AOU_RX_AXI_S_BID          (d2_si_bid),
        .O_AOU_RX_AXI_S_BRESP        (d2_si_bresp),
        .O_AOU_RX_AXI_S_BVALID       (d2_si_bvalid),
        .I_AOU_RX_AXI_S_BREADY       (d2_si_bready),

        // FDI: u_dut2 RX <- u_dut1 TX, u_dut2 TX -> u_dut1 RX
        .I_FDI_PL_0_VALID            (dut1_lp_128b_valid),
        .I_FDI_PL_0_DATA             (dut1_lp_128b_data),
        .I_FDI_PL_0_FLIT_CANCEL      (1'b0),
        .I_FDI_PL_0_TRDY             (1'b1),
        .I_FDI_PL_0_STALLREQ         (1'b0),
        .I_FDI_PL_0_STATE_STS        (4'h1),
        .O_FDI_LP_0_DATA             (dut2_lp_128b_data),
        .O_FDI_LP_0_VALID            (dut2_lp_128b_valid),
        .O_FDI_LP_0_IRDY             (dut2_lp_128b_irdy),
        .O_FDI_LP_0_STALLACK         (dut2_lp_128b_stallack),

        .INT_REQ_LINKRESET            (),
        .INT_SI0_ID_MISMATCH          (),
        .INT_MI0_ID_MISMATCH          (),
        .INT_EARLY_RESP_ERR           (),
        .INT_ACTIVATE_START           (),
        .INT_DEACTIVATE_START         (),

        .I_INT_FSM_IN_ACTIVE          (1'b1),
        .I_MST_BUS_CLEANY_COMPLETE    (1'b1),
        .I_SLV_BUS_CLEANY_COMPLETE    (1'b1),
        .O_AOU_ACTIVATE_ST_DISABLED   (),
        .O_AOU_ACTIVATE_ST_ENABLED    (),
        .O_AOU_REQ_LINKRESET          (),

        .TIEL_DFT_MODESCAN            (1'b0)
    );

    // ================================================================
    // VCS waveform dump enable.
    //
    // Activated by the Makefile when SIM=vcs WAVES=1 by passing
    // +define+DUMP_FSDB (preferred, Verdi FSDB) or +define+DUMP_VPD
    // (fallback, VCS native VPD). Each block is also gated at runtime
    // on its corresponding plusarg so the binary can still be re-run
    // without dumping by simply omitting the plusarg.
    //
    // Under Verilator these defines are never set, so the FSDB and VPD
    // system tasks (which it does not implement) are never elaborated.
    // ================================================================
`ifdef DUMP_FSDB
    initial begin
        if ($test$plusargs("fsdb")) begin
            $fsdbDumpfile("dump_sp128b.fsdb");
            $fsdbDumpvars(0, aou_cocotb_top_sp128b);
            $display("[%0t] aou_cocotb_top_sp128b: FSDB dump enabled -> dump_sp128b.fsdb", $time);
        end
    end
`endif
`ifdef DUMP_VPD
    initial begin
        if ($test$plusargs("vcdpluson")) begin
            $vcdplusfile("dump_sp128b.vpd");
            $vcdpluson(0);
            $display("[%0t] aou_cocotb_top_sp128b: VPD dump enabled -> dump_sp128b.vpd", $time);
        end
    end
`endif

    // ----------------------------------------------------------------
    // VCD dump enable (Verilator).
    //
    // The Makefile passes `+define+VLT_DUMP_FILE="dump_<config>.vcd"`
    // when WAVES=1 with SIM=verilator, so each FDI_CONFIG variant writes
    // its own VCD and concurrent makes do not collide on dump.vcd.
    // ----------------------------------------------------------------
`ifdef VLT_DUMP_FILE
    initial begin
        $dumpfile(`VLT_DUMP_FILE);
        $dumpvars(0, aou_cocotb_top_sp128b);
        $display("[%0t] aou_cocotb_top_sp128b: VCD dump enabled -> %s", $time, `VLT_DUMP_FILE);
    end
`endif

endmodule
