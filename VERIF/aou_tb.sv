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
//  Testbench : aou_tb
//  Description: Dual AOU_CORE_TOP FDI loopback with bidirectional traffic.
//               u_dut1 and u_dut2 are connected back-to-back via 64B FDI.
//               Forward path: axi_rand_master on u_dut1 SI -> FDI -> u_dut2 MI
//                             -> axi_sim_mem_intf.
//               Reverse path: axi_rand_master on u_dut2 SI -> FDI -> u_dut1 MI
//                             -> axi_sim_mem_intf.
//               Data integrity is checked by axi_scoreboard on each SI.
//               Both instances share the same AXI/APB clocks.
//
// *****************************************************************************

`timescale 1ns/1ps

`include "axi/assign.svh"
`include "axi/typedef.svh"

module aou_tb;

    // ================================================================
    // Parameters
    // ================================================================
    localparam RP_COUNT          = 1;
    localparam APB_ADDR_WD       = 32;
    localparam APB_DATA_WD       = 32;

    localparam AXI_ADDR_WIDTH    = 64;
    localparam AXI_DATA_WIDTH    = 512;
    localparam AXI_ID_WIDTH      = 10;
    localparam AXI_USER_WIDTH    = 1;
    localparam AXI_STRB_WIDTH    = AXI_DATA_WIDTH / 8;

    localparam D2_AXI_DATA_WIDTH = 256;
    localparam D2_AXI_STRB_WIDTH = D2_AXI_DATA_WIDTH / 8;

    localparam realtime CLK_PERIOD   = 1ns;
    localparam realtime PCLK_PERIOD  = 10ns;
    localparam realtime TA           = 100ps;
    localparam realtime TT           = 900ps;

    // ================================================================
    // Clocks and resets (shared by both instances and VIPs)
    // ================================================================
    logic clk;
    logic resetn;
    logic pclk;
    logic presetn;

    initial clk  = 1'b0;
    initial pclk = 1'b0;
    always #(CLK_PERIOD  / 2) clk  = ~clk;
    always #(PCLK_PERIOD / 2) pclk = ~pclk;

    // ================================================================
    // APB signals -- Instance 1
    // ================================================================
    logic                       apb1_psel;
    logic                       apb1_penable;
    logic [APB_ADDR_WD-1:0]     apb1_paddr;
    logic                       apb1_pwrite;
    logic [APB_DATA_WD-1:0]     apb1_pwdata;
    wire  [APB_DATA_WD-1:0]     apb1_prdata;
    wire                        apb1_pready;
    wire                        apb1_pslverr;

    // ================================================================
    // APB signals -- Instance 2
    // ================================================================
    logic                       apb2_psel;
    logic                       apb2_penable;
    logic [APB_ADDR_WD-1:0]     apb2_paddr;
    logic                       apb2_pwrite;
    logic [APB_DATA_WD-1:0]     apb2_pwdata;
    wire  [APB_DATA_WD-1:0]     apb2_prdata;
    wire                        apb2_pready;
    wire                        apb2_pslverr;

    // ================================================================
    // AXI master VIP interface (connects to u_dut1 AXI SI)
    // ================================================================
    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) axi_if (clk);

    // ================================================================
    // AXI_BUS for u_dut2 MI (connects to axi_sim_mem_intf, 256b)
    // ================================================================
    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (D2_AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) axi_slv_bus ();

    // ================================================================
    // u_dut1 AXI SI bridge (axi_if <-> u_dut1 flat SI ports)
    // ================================================================

    // AW
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   axi_s_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] axi_s_awaddr;
    wire [RP_COUNT-1:0][7:0]                axi_s_awlen;
    wire [RP_COUNT-1:0][2:0]                axi_s_awsize;
    wire [RP_COUNT-1:0][1:0]                axi_s_awburst;
    wire [RP_COUNT-1:0]                     axi_s_awlock;
    wire [RP_COUNT-1:0][3:0]                axi_s_awcache;
    wire [RP_COUNT-1:0][2:0]                axi_s_awprot;
    wire [RP_COUNT-1:0][3:0]                axi_s_awqos;
    wire [RP_COUNT-1:0]                     axi_s_awvalid;
    wire [RP_COUNT-1:0]                     axi_s_awready;

    assign axi_s_awid[0]    = axi_if.aw_id;
    assign axi_s_awaddr[0]  = axi_if.aw_addr;
    assign axi_s_awlen[0]   = axi_if.aw_len;
    assign axi_s_awsize[0]  = axi_if.aw_size;
    assign axi_s_awburst[0] = axi_if.aw_burst;
    assign axi_s_awlock[0]  = axi_if.aw_lock;
    assign axi_s_awcache[0] = axi_if.aw_cache;
    assign axi_s_awprot[0]  = axi_if.aw_prot;
    assign axi_s_awqos[0]   = axi_if.aw_qos;
    assign axi_s_awvalid[0] = axi_if.aw_valid;
    assign axi_if.aw_ready  = axi_s_awready[0];

    // W
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] axi_s_wdata;
    wire [RP_COUNT-1:0][AXI_STRB_WIDTH-1:0] axi_s_wstrb;
    wire [RP_COUNT-1:0]                     axi_s_wlast;
    wire [RP_COUNT-1:0]                     axi_s_wvalid;
    wire [RP_COUNT-1:0]                     axi_s_wready;

    assign axi_s_wdata[0]   = axi_if.w_data;
    assign axi_s_wstrb[0]   = axi_if.w_strb;
    assign axi_s_wlast[0]   = axi_if.w_last;
    assign axi_s_wvalid[0]  = axi_if.w_valid;
    assign axi_if.w_ready   = axi_s_wready[0];

    // B
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   axi_s_bid;
    wire [RP_COUNT-1:0][1:0]                axi_s_bresp;
    wire [RP_COUNT-1:0]                     axi_s_bvalid;
    wire [RP_COUNT-1:0]                     axi_s_bready;

    assign axi_if.b_id      = axi_s_bid[0];
    assign axi_if.b_resp    = axi_s_bresp[0];
    assign axi_if.b_valid   = axi_s_bvalid[0];
    assign axi_if.b_user    = '0;
    assign axi_s_bready[0]  = axi_if.b_ready;

    // AR
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   axi_s_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] axi_s_araddr;
    wire [RP_COUNT-1:0][7:0]                axi_s_arlen;
    wire [RP_COUNT-1:0][2:0]                axi_s_arsize;
    wire [RP_COUNT-1:0][1:0]                axi_s_arburst;
    wire [RP_COUNT-1:0]                     axi_s_arlock;
    wire [RP_COUNT-1:0][3:0]                axi_s_arcache;
    wire [RP_COUNT-1:0][2:0]                axi_s_arprot;
    wire [RP_COUNT-1:0][3:0]                axi_s_arqos;
    wire [RP_COUNT-1:0]                     axi_s_arvalid;
    wire [RP_COUNT-1:0]                     axi_s_arready;

    assign axi_s_arid[0]    = axi_if.ar_id;
    assign axi_s_araddr[0]  = axi_if.ar_addr;
    assign axi_s_arlen[0]   = axi_if.ar_len;
    assign axi_s_arsize[0]  = axi_if.ar_size;
    assign axi_s_arburst[0] = axi_if.ar_burst;
    assign axi_s_arlock[0]  = axi_if.ar_lock;
    assign axi_s_arcache[0] = axi_if.ar_cache;
    assign axi_s_arprot[0]  = axi_if.ar_prot;
    assign axi_s_arqos[0]   = axi_if.ar_qos;
    assign axi_s_arvalid[0] = axi_if.ar_valid;
    assign axi_if.ar_ready  = axi_s_arready[0];

    // R
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   axi_s_rid;
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] axi_s_rdata;
    wire [RP_COUNT-1:0][1:0]                axi_s_rresp;
    wire [RP_COUNT-1:0]                     axi_s_rlast;
    wire [RP_COUNT-1:0]                     axi_s_rvalid;
    wire [RP_COUNT-1:0]                     axi_s_rready;

    assign axi_if.r_id      = axi_s_rid[0];
    assign axi_if.r_data    = axi_s_rdata[0];
    assign axi_if.r_resp    = axi_s_rresp[0];
    assign axi_if.r_last    = axi_s_rlast[0];
    assign axi_if.r_valid   = axi_s_rvalid[0];
    assign axi_if.r_user    = '0;
    assign axi_s_rready[0]  = axi_if.r_ready;

    // ================================================================
    // u_dut2 AXI MI bridge (u_dut2 flat MI ports <-> axi_slv_bus)
    // ================================================================

    // AW: DUT2 MI master -> slave VIP
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_m_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d2_axi_m_awaddr;
    wire [RP_COUNT-1:0][7:0]                d2_axi_m_awlen;
    wire [RP_COUNT-1:0][2:0]                d2_axi_m_awsize;
    wire [RP_COUNT-1:0][1:0]                d2_axi_m_awburst;
    wire [RP_COUNT-1:0]                     d2_axi_m_awlock;
    wire [RP_COUNT-1:0][3:0]                d2_axi_m_awcache;
    wire [RP_COUNT-1:0][2:0]                d2_axi_m_awprot;
    wire [RP_COUNT-1:0][3:0]                d2_axi_m_awqos;
    wire [RP_COUNT-1:0]                     d2_axi_m_awvalid;
    wire [RP_COUNT-1:0]                     d2_axi_m_awready;

    assign axi_slv_bus.aw_id     = d2_axi_m_awid[0];
    assign axi_slv_bus.aw_addr   = d2_axi_m_awaddr[0];
    assign axi_slv_bus.aw_len    = d2_axi_m_awlen[0];
    assign axi_slv_bus.aw_size   = d2_axi_m_awsize[0];
    assign axi_slv_bus.aw_burst  = d2_axi_m_awburst[0];
    assign axi_slv_bus.aw_lock   = d2_axi_m_awlock[0];
    assign axi_slv_bus.aw_cache  = d2_axi_m_awcache[0];
    assign axi_slv_bus.aw_prot   = d2_axi_m_awprot[0];
    assign axi_slv_bus.aw_qos    = d2_axi_m_awqos[0];
    assign axi_slv_bus.aw_valid  = d2_axi_m_awvalid[0];
    assign axi_slv_bus.aw_region = '0;
    assign axi_slv_bus.aw_atop   = '0;
    assign axi_slv_bus.aw_user   = '0;
    assign d2_axi_m_awready[0]  = axi_slv_bus.aw_ready;

    // W: DUT2 MI master -> slave VIP
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_axi_m_wdata;
    wire [RP_COUNT-1:0][D2_AXI_STRB_WIDTH-1:0] d2_axi_m_wstrb;
    wire [RP_COUNT-1:0]                     d2_axi_m_wlast;
    wire [RP_COUNT-1:0]                     d2_axi_m_wvalid;
    wire [RP_COUNT-1:0]                     d2_axi_m_wready;

    assign axi_slv_bus.w_data    = d2_axi_m_wdata[0];
    assign axi_slv_bus.w_strb    = d2_axi_m_wstrb[0];
    assign axi_slv_bus.w_last    = d2_axi_m_wlast[0];
    assign axi_slv_bus.w_valid   = d2_axi_m_wvalid[0];
    assign axi_slv_bus.w_user    = '0;
    assign d2_axi_m_wready[0]   = axi_slv_bus.w_ready;

    // B: slave VIP -> DUT2 MI master
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_m_bid;
    wire [RP_COUNT-1:0][1:0]                d2_axi_m_bresp;
    wire [RP_COUNT-1:0]                     d2_axi_m_bvalid;
    wire [RP_COUNT-1:0]                     d2_axi_m_bready;

    assign d2_axi_m_bid[0]      = axi_slv_bus.b_id;
    assign d2_axi_m_bresp[0]    = axi_slv_bus.b_resp;
    assign d2_axi_m_bvalid[0]   = axi_slv_bus.b_valid;
    assign axi_slv_bus.b_ready   = d2_axi_m_bready[0];

    // AR: DUT2 MI master -> slave VIP
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_m_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d2_axi_m_araddr;
    wire [RP_COUNT-1:0][7:0]                d2_axi_m_arlen;
    wire [RP_COUNT-1:0][2:0]                d2_axi_m_arsize;
    wire [RP_COUNT-1:0][1:0]                d2_axi_m_arburst;
    wire [RP_COUNT-1:0]                     d2_axi_m_arlock;
    wire [RP_COUNT-1:0][3:0]                d2_axi_m_arcache;
    wire [RP_COUNT-1:0][2:0]                d2_axi_m_arprot;
    wire [RP_COUNT-1:0][3:0]                d2_axi_m_arqos;
    wire [RP_COUNT-1:0]                     d2_axi_m_arvalid;
    wire [RP_COUNT-1:0]                     d2_axi_m_arready;

    assign axi_slv_bus.ar_id     = d2_axi_m_arid[0];
    assign axi_slv_bus.ar_addr   = d2_axi_m_araddr[0];
    assign axi_slv_bus.ar_len    = d2_axi_m_arlen[0];
    assign axi_slv_bus.ar_size   = d2_axi_m_arsize[0];
    assign axi_slv_bus.ar_burst  = d2_axi_m_arburst[0];
    assign axi_slv_bus.ar_lock   = d2_axi_m_arlock[0];
    assign axi_slv_bus.ar_cache  = d2_axi_m_arcache[0];
    assign axi_slv_bus.ar_prot   = d2_axi_m_arprot[0];
    assign axi_slv_bus.ar_qos    = d2_axi_m_arqos[0];
    assign axi_slv_bus.ar_valid  = d2_axi_m_arvalid[0];
    assign axi_slv_bus.ar_region = '0;
    assign axi_slv_bus.ar_user   = '0;
    assign d2_axi_m_arready[0]  = axi_slv_bus.ar_ready;

    // R: slave VIP -> DUT2 MI master
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_m_rid;
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_axi_m_rdata;
    wire [RP_COUNT-1:0][1:0]                d2_axi_m_rresp;
    wire [RP_COUNT-1:0]                     d2_axi_m_rlast;
    wire [RP_COUNT-1:0]                     d2_axi_m_rvalid;
    wire [RP_COUNT-1:0]                     d2_axi_m_rready;

    assign d2_axi_m_rid[0]      = axi_slv_bus.r_id;
    assign d2_axi_m_rdata[0]    = axi_slv_bus.r_data;
    assign d2_axi_m_rresp[0]    = axi_slv_bus.r_resp;
    assign d2_axi_m_rlast[0]    = axi_slv_bus.r_last;
    assign d2_axi_m_rvalid[0]   = axi_slv_bus.r_valid;
    assign axi_slv_bus.r_ready   = d2_axi_m_rready[0];

    // ================================================================
    // u_dut2 AXI SI bridge (axi_mst2_if <-> u_dut2 flat SI ports)
    // Reverse direction: master VIP on u_dut2 SI -> FDI -> u_dut1 MI
    // ================================================================

    AXI_BUS_DV #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (D2_AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) axi_mst2_if (clk);

    // AW
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_s_awid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d2_axi_s_awaddr;
    wire [RP_COUNT-1:0][7:0]                d2_axi_s_awlen;
    wire [RP_COUNT-1:0][2:0]                d2_axi_s_awsize;
    wire [RP_COUNT-1:0][1:0]                d2_axi_s_awburst;
    wire [RP_COUNT-1:0]                     d2_axi_s_awlock;
    wire [RP_COUNT-1:0][3:0]                d2_axi_s_awcache;
    wire [RP_COUNT-1:0][2:0]                d2_axi_s_awprot;
    wire [RP_COUNT-1:0][3:0]                d2_axi_s_awqos;
    wire [RP_COUNT-1:0]                     d2_axi_s_awvalid;
    wire [RP_COUNT-1:0]                     d2_axi_s_awready;

    assign d2_axi_s_awid[0]    = axi_mst2_if.aw_id;
    assign d2_axi_s_awaddr[0]  = axi_mst2_if.aw_addr;
    assign d2_axi_s_awlen[0]   = axi_mst2_if.aw_len;
    assign d2_axi_s_awsize[0]  = axi_mst2_if.aw_size;
    assign d2_axi_s_awburst[0] = axi_mst2_if.aw_burst;
    assign d2_axi_s_awlock[0]  = axi_mst2_if.aw_lock;
    assign d2_axi_s_awcache[0] = axi_mst2_if.aw_cache;
    assign d2_axi_s_awprot[0]  = axi_mst2_if.aw_prot;
    assign d2_axi_s_awqos[0]   = axi_mst2_if.aw_qos;
    assign d2_axi_s_awvalid[0] = axi_mst2_if.aw_valid;
    assign axi_mst2_if.aw_ready = d2_axi_s_awready[0];

    // W
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_axi_s_wdata;
    wire [RP_COUNT-1:0][D2_AXI_STRB_WIDTH-1:0] d2_axi_s_wstrb;
    wire [RP_COUNT-1:0]                     d2_axi_s_wlast;
    wire [RP_COUNT-1:0]                     d2_axi_s_wvalid;
    wire [RP_COUNT-1:0]                     d2_axi_s_wready;

    assign d2_axi_s_wdata[0]   = axi_mst2_if.w_data;
    assign d2_axi_s_wstrb[0]   = axi_mst2_if.w_strb;
    assign d2_axi_s_wlast[0]   = axi_mst2_if.w_last;
    assign d2_axi_s_wvalid[0]  = axi_mst2_if.w_valid;
    assign axi_mst2_if.w_ready = d2_axi_s_wready[0];

    // B
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_s_bid;
    wire [RP_COUNT-1:0][1:0]                d2_axi_s_bresp;
    wire [RP_COUNT-1:0]                     d2_axi_s_bvalid;
    wire [RP_COUNT-1:0]                     d2_axi_s_bready;

    assign axi_mst2_if.b_id    = d2_axi_s_bid[0];
    assign axi_mst2_if.b_resp  = d2_axi_s_bresp[0];
    assign axi_mst2_if.b_valid = d2_axi_s_bvalid[0];
    assign axi_mst2_if.b_user  = '0;
    assign d2_axi_s_bready[0]  = axi_mst2_if.b_ready;

    // AR
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_s_arid;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d2_axi_s_araddr;
    wire [RP_COUNT-1:0][7:0]                d2_axi_s_arlen;
    wire [RP_COUNT-1:0][2:0]                d2_axi_s_arsize;
    wire [RP_COUNT-1:0][1:0]                d2_axi_s_arburst;
    wire [RP_COUNT-1:0]                     d2_axi_s_arlock;
    wire [RP_COUNT-1:0][3:0]                d2_axi_s_arcache;
    wire [RP_COUNT-1:0][2:0]                d2_axi_s_arprot;
    wire [RP_COUNT-1:0][3:0]                d2_axi_s_arqos;
    wire [RP_COUNT-1:0]                     d2_axi_s_arvalid;
    wire [RP_COUNT-1:0]                     d2_axi_s_arready;

    assign d2_axi_s_arid[0]    = axi_mst2_if.ar_id;
    assign d2_axi_s_araddr[0]  = axi_mst2_if.ar_addr;
    assign d2_axi_s_arlen[0]   = axi_mst2_if.ar_len;
    assign d2_axi_s_arsize[0]  = axi_mst2_if.ar_size;
    assign d2_axi_s_arburst[0] = axi_mst2_if.ar_burst;
    assign d2_axi_s_arlock[0]  = axi_mst2_if.ar_lock;
    assign d2_axi_s_arcache[0] = axi_mst2_if.ar_cache;
    assign d2_axi_s_arprot[0]  = axi_mst2_if.ar_prot;
    assign d2_axi_s_arqos[0]   = axi_mst2_if.ar_qos;
    assign d2_axi_s_arvalid[0] = axi_mst2_if.ar_valid;
    assign axi_mst2_if.ar_ready = d2_axi_s_arready[0];

    // R
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d2_axi_s_rid;
    wire [RP_COUNT-1:0][D2_AXI_DATA_WIDTH-1:0] d2_axi_s_rdata;
    wire [RP_COUNT-1:0][1:0]                d2_axi_s_rresp;
    wire [RP_COUNT-1:0]                     d2_axi_s_rlast;
    wire [RP_COUNT-1:0]                     d2_axi_s_rvalid;
    wire [RP_COUNT-1:0]                     d2_axi_s_rready;

    assign axi_mst2_if.r_id    = d2_axi_s_rid[0];
    assign axi_mst2_if.r_data  = d2_axi_s_rdata[0];
    assign axi_mst2_if.r_resp  = d2_axi_s_rresp[0];
    assign axi_mst2_if.r_last  = d2_axi_s_rlast[0];
    assign axi_mst2_if.r_valid = d2_axi_s_rvalid[0];
    assign axi_mst2_if.r_user  = '0;
    assign d2_axi_s_rready[0]  = axi_mst2_if.r_ready;

    // ================================================================
    // AXI_BUS for u_dut1 MI (connects to axi_sim_mem_intf, 512b)
    // ================================================================

    AXI_BUS #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH)
    ) axi_slv1_bus ();

    // AW: DUT1 MI master -> slave VIP
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_axi_m_awid_b;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_axi_m_awaddr_b;
    wire [RP_COUNT-1:0][7:0]                d1_axi_m_awlen_b;
    wire [RP_COUNT-1:0][2:0]                d1_axi_m_awsize_b;
    wire [RP_COUNT-1:0][1:0]                d1_axi_m_awburst_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_awlock_b;
    wire [RP_COUNT-1:0][3:0]                d1_axi_m_awcache_b;
    wire [RP_COUNT-1:0][2:0]                d1_axi_m_awprot_b;
    wire [RP_COUNT-1:0][3:0]                d1_axi_m_awqos_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_awvalid_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_awready_b;

    assign axi_slv1_bus.aw_id     = d1_axi_m_awid_b[0];
    assign axi_slv1_bus.aw_addr   = d1_axi_m_awaddr_b[0];
    assign axi_slv1_bus.aw_len    = d1_axi_m_awlen_b[0];
    assign axi_slv1_bus.aw_size   = d1_axi_m_awsize_b[0];
    assign axi_slv1_bus.aw_burst  = d1_axi_m_awburst_b[0];
    assign axi_slv1_bus.aw_lock   = d1_axi_m_awlock_b[0];
    assign axi_slv1_bus.aw_cache  = d1_axi_m_awcache_b[0];
    assign axi_slv1_bus.aw_prot   = d1_axi_m_awprot_b[0];
    assign axi_slv1_bus.aw_qos    = d1_axi_m_awqos_b[0];
    assign axi_slv1_bus.aw_valid  = d1_axi_m_awvalid_b[0];
    assign axi_slv1_bus.aw_region = '0;
    assign axi_slv1_bus.aw_atop   = '0;
    assign axi_slv1_bus.aw_user   = '0;
    assign d1_axi_m_awready_b[0] = axi_slv1_bus.aw_ready;

    // W: DUT1 MI master -> slave VIP
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_axi_m_wdata_b;
    wire [RP_COUNT-1:0][AXI_STRB_WIDTH-1:0] d1_axi_m_wstrb_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_wlast_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_wvalid_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_wready_b;

    assign axi_slv1_bus.w_data    = d1_axi_m_wdata_b[0];
    assign axi_slv1_bus.w_strb    = d1_axi_m_wstrb_b[0];
    assign axi_slv1_bus.w_last    = d1_axi_m_wlast_b[0];
    assign axi_slv1_bus.w_valid   = d1_axi_m_wvalid_b[0];
    assign axi_slv1_bus.w_user    = '0;
    assign d1_axi_m_wready_b[0]  = axi_slv1_bus.w_ready;

    // B: slave VIP -> DUT1 MI master
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_axi_m_bid_b;
    wire [RP_COUNT-1:0][1:0]                d1_axi_m_bresp_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_bvalid_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_bready_b;

    assign d1_axi_m_bid_b[0]    = axi_slv1_bus.b_id;
    assign d1_axi_m_bresp_b[0]  = axi_slv1_bus.b_resp;
    assign d1_axi_m_bvalid_b[0] = axi_slv1_bus.b_valid;
    assign axi_slv1_bus.b_ready  = d1_axi_m_bready_b[0];

    // AR: DUT1 MI master -> slave VIP
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_axi_m_arid_b;
    wire [RP_COUNT-1:0][AXI_ADDR_WIDTH-1:0] d1_axi_m_araddr_b;
    wire [RP_COUNT-1:0][7:0]                d1_axi_m_arlen_b;
    wire [RP_COUNT-1:0][2:0]                d1_axi_m_arsize_b;
    wire [RP_COUNT-1:0][1:0]                d1_axi_m_arburst_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_arlock_b;
    wire [RP_COUNT-1:0][3:0]                d1_axi_m_arcache_b;
    wire [RP_COUNT-1:0][2:0]                d1_axi_m_arprot_b;
    wire [RP_COUNT-1:0][3:0]                d1_axi_m_arqos_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_arvalid_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_arready_b;

    assign axi_slv1_bus.ar_id     = d1_axi_m_arid_b[0];
    assign axi_slv1_bus.ar_addr   = d1_axi_m_araddr_b[0];
    assign axi_slv1_bus.ar_len    = d1_axi_m_arlen_b[0];
    assign axi_slv1_bus.ar_size   = d1_axi_m_arsize_b[0];
    assign axi_slv1_bus.ar_burst  = d1_axi_m_arburst_b[0];
    assign axi_slv1_bus.ar_lock   = d1_axi_m_arlock_b[0];
    assign axi_slv1_bus.ar_cache  = d1_axi_m_arcache_b[0];
    assign axi_slv1_bus.ar_prot   = d1_axi_m_arprot_b[0];
    assign axi_slv1_bus.ar_qos    = d1_axi_m_arqos_b[0];
    assign axi_slv1_bus.ar_valid  = d1_axi_m_arvalid_b[0];
    assign axi_slv1_bus.ar_region = '0;
    assign axi_slv1_bus.ar_user   = '0;
    assign d1_axi_m_arready_b[0] = axi_slv1_bus.ar_ready;

    // R: slave VIP -> DUT1 MI master
    wire [RP_COUNT-1:0][AXI_ID_WIDTH-1:0]   d1_axi_m_rid_b;
    wire [RP_COUNT-1:0][AXI_DATA_WIDTH-1:0] d1_axi_m_rdata_b;
    wire [RP_COUNT-1:0][1:0]                d1_axi_m_rresp_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_rlast_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_rvalid_b;
    wire [RP_COUNT-1:0]                     d1_axi_m_rready_b;

    assign d1_axi_m_rid_b[0]    = axi_slv1_bus.r_id;
    assign d1_axi_m_rdata_b[0]  = axi_slv1_bus.r_data;
    assign d1_axi_m_rresp_b[0]  = axi_slv1_bus.r_resp;
    assign d1_axi_m_rlast_b[0]  = axi_slv1_bus.r_last;
    assign d1_axi_m_rvalid_b[0] = axi_slv1_bus.r_valid;
    assign axi_slv1_bus.r_ready  = d1_axi_m_rready_b[0];

    // ================================================================
    // axi_sim_mem_intf instances (memory-backed AXI slaves on MI sides)
    // ================================================================

    axi_sim_mem_intf #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (D2_AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH),
        .APPL_DELAY     (TA),
        .ACQ_DELAY      (TT)
    ) i_mem_d2mi (
        .clk_i  (clk),
        .rst_ni (resetn),
        .axi_slv(axi_slv_bus),
        .mon_w_valid_o      (),
        .mon_w_addr_o       (),
        .mon_w_data_o       (),
        .mon_w_id_o         (),
        .mon_w_user_o       (),
        .mon_w_beat_count_o (),
        .mon_w_last_o       (),
        .mon_r_valid_o      (),
        .mon_r_addr_o       (),
        .mon_r_data_o       (),
        .mon_r_id_o         (),
        .mon_r_user_o       (),
        .mon_r_beat_count_o (),
        .mon_r_last_o       ()
    );

    axi_sim_mem_intf #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH (AXI_USER_WIDTH),
        .APPL_DELAY     (TA),
        .ACQ_DELAY      (TT)
    ) i_mem_d1mi (
        .clk_i  (clk),
        .rst_ni (resetn),
        .axi_slv(axi_slv1_bus),
        .mon_w_valid_o      (),
        .mon_w_addr_o       (),
        .mon_w_data_o       (),
        .mon_w_id_o         (),
        .mon_w_user_o       (),
        .mon_w_beat_count_o (),
        .mon_w_last_o       (),
        .mon_r_valid_o      (),
        .mon_r_addr_o       (),
        .mon_r_data_o       (),
        .mon_r_id_o         (),
        .mon_r_user_o       (),
        .mon_r_beat_count_o (),
        .mon_r_last_o       ()
    );

    // ================================================================
    // AXI transaction logging (compile with +define+AXI_LOG to enable)
    // ================================================================
`ifdef AXI_LOG

    // ---- DUT1 SI (512b) ----
    always @(posedge clk) if (resetn && axi_s_awvalid[0] && axi_s_awready[0])
        $display("[%0t] D1_SI AW: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, axi_s_awaddr[0], axi_s_awid[0], axi_s_awlen[0], axi_s_awsize[0], axi_s_awburst[0]);
    always @(posedge clk) if (resetn && axi_s_wvalid[0] && axi_s_wready[0])
        $display("[%0t] D1_SI  W: data=%h strb=%h last=%0b",
                 $time, axi_s_wdata[0], axi_s_wstrb[0], axi_s_wlast[0]);
    always @(posedge clk) if (resetn && axi_s_bvalid[0] && axi_s_bready[0])
        $display("[%0t] D1_SI  B: id=%h resp=%0d",
                 $time, axi_s_bid[0], axi_s_bresp[0]);
    always @(posedge clk) if (resetn && axi_s_arvalid[0] && axi_s_arready[0])
        $display("[%0t] D1_SI AR: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, axi_s_araddr[0], axi_s_arid[0], axi_s_arlen[0], axi_s_arsize[0], axi_s_arburst[0]);
    always @(posedge clk) if (resetn && axi_s_rvalid[0] && axi_s_rready[0])
        $display("[%0t] D1_SI  R: data=%h id=%h resp=%0d last=%0b",
                 $time, axi_s_rdata[0], axi_s_rid[0], axi_s_rresp[0], axi_s_rlast[0]);

    // ---- DUT2 MI (256b) ----
    always @(posedge clk) if (resetn && d2_axi_m_awvalid[0] && d2_axi_m_awready[0])
        $display("[%0t] D2_MI AW: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d2_axi_m_awaddr[0], d2_axi_m_awid[0], d2_axi_m_awlen[0], d2_axi_m_awsize[0], d2_axi_m_awburst[0]);
    always @(posedge clk) if (resetn && d2_axi_m_wvalid[0] && d2_axi_m_wready[0])
        $display("[%0t] D2_MI  W: data=%h strb=%h last=%0b",
                 $time, d2_axi_m_wdata[0], d2_axi_m_wstrb[0], d2_axi_m_wlast[0]);
    always @(posedge clk) if (resetn && d2_axi_m_bvalid[0] && d2_axi_m_bready[0])
        $display("[%0t] D2_MI  B: id=%h resp=%0d",
                 $time, d2_axi_m_bid[0], d2_axi_m_bresp[0]);
    always @(posedge clk) if (resetn && d2_axi_m_arvalid[0] && d2_axi_m_arready[0])
        $display("[%0t] D2_MI AR: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d2_axi_m_araddr[0], d2_axi_m_arid[0], d2_axi_m_arlen[0], d2_axi_m_arsize[0], d2_axi_m_arburst[0]);
    always @(posedge clk) if (resetn && d2_axi_m_rvalid[0] && d2_axi_m_rready[0])
        $display("[%0t] D2_MI  R: data=%h id=%h resp=%0d last=%0b",
                 $time, d2_axi_m_rdata[0], d2_axi_m_rid[0], d2_axi_m_rresp[0], d2_axi_m_rlast[0]);

    // ---- DUT2 SI (256b) ----
    always @(posedge clk) if (resetn && d2_axi_s_awvalid[0] && d2_axi_s_awready[0])
        $display("[%0t] D2_SI AW: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d2_axi_s_awaddr[0], d2_axi_s_awid[0], d2_axi_s_awlen[0], d2_axi_s_awsize[0], d2_axi_s_awburst[0]);
    always @(posedge clk) if (resetn && d2_axi_s_wvalid[0] && d2_axi_s_wready[0])
        $display("[%0t] D2_SI  W: data=%h strb=%h last=%0b",
                 $time, d2_axi_s_wdata[0], d2_axi_s_wstrb[0], d2_axi_s_wlast[0]);
    always @(posedge clk) if (resetn && d2_axi_s_bvalid[0] && d2_axi_s_bready[0])
        $display("[%0t] D2_SI  B: id=%h resp=%0d",
                 $time, d2_axi_s_bid[0], d2_axi_s_bresp[0]);
    always @(posedge clk) if (resetn && d2_axi_s_arvalid[0] && d2_axi_s_arready[0])
        $display("[%0t] D2_SI AR: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d2_axi_s_araddr[0], d2_axi_s_arid[0], d2_axi_s_arlen[0], d2_axi_s_arsize[0], d2_axi_s_arburst[0]);
    always @(posedge clk) if (resetn && d2_axi_s_rvalid[0] && d2_axi_s_rready[0])
        $display("[%0t] D2_SI  R: data=%h id=%h resp=%0d last=%0b",
                 $time, d2_axi_s_rdata[0], d2_axi_s_rid[0], d2_axi_s_rresp[0], d2_axi_s_rlast[0]);

    // ---- DUT1 MI (512b) ----
    always @(posedge clk) if (resetn && d1_axi_m_awvalid_b[0] && d1_axi_m_awready_b[0])
        $display("[%0t] D1_MI AW: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d1_axi_m_awaddr_b[0], d1_axi_m_awid_b[0], d1_axi_m_awlen_b[0], d1_axi_m_awsize_b[0], d1_axi_m_awburst_b[0]);
    always @(posedge clk) if (resetn && d1_axi_m_wvalid_b[0] && d1_axi_m_wready_b[0])
        $display("[%0t] D1_MI  W: data=%h strb=%h last=%0b",
                 $time, d1_axi_m_wdata_b[0], d1_axi_m_wstrb_b[0], d1_axi_m_wlast_b[0]);
    always @(posedge clk) if (resetn && d1_axi_m_bvalid_b[0] && d1_axi_m_bready_b[0])
        $display("[%0t] D1_MI  B: id=%h resp=%0d",
                 $time, d1_axi_m_bid_b[0], d1_axi_m_bresp_b[0]);
    always @(posedge clk) if (resetn && d1_axi_m_arvalid_b[0] && d1_axi_m_arready_b[0])
        $display("[%0t] D1_MI AR: addr=%h id=%h len=%0d size=%0d burst=%0d",
                 $time, d1_axi_m_araddr_b[0], d1_axi_m_arid_b[0], d1_axi_m_arlen_b[0], d1_axi_m_arsize_b[0], d1_axi_m_arburst_b[0]);
    always @(posedge clk) if (resetn && d1_axi_m_rvalid_b[0] && d1_axi_m_rready_b[0])
        $display("[%0t] D1_MI  R: data=%h id=%h resp=%0d last=%0b",
                 $time, d1_axi_m_rdata_b[0], d1_axi_m_rid_b[0], d1_axi_m_rresp_b[0], d1_axi_m_rlast_b[0]);

`endif // AXI_LOG

    // ================================================================
    // FDI cross-connect wires (64B)
    // u_dut1 TX LP -> u_dut2 RX PL (request path)
    // u_dut2 TX LP -> u_dut1 RX PL (response path)
    // ================================================================
    wire [511:0] dut1_lp_64b_data;
    wire         dut1_lp_64b_valid;
    wire         dut1_lp_64b_irdy;
    wire         dut1_lp_64b_stallack;

    wire [511:0] dut2_lp_64b_data;
    wire         dut2_lp_64b_valid;
    wire         dut2_lp_64b_irdy;
    wire         dut2_lp_64b_stallack;

    // 32B LP outputs (unused, just observed)
    wire [255:0] dut1_lp_32b_data;
    wire         dut1_lp_32b_valid;
    wire         dut1_lp_32b_irdy;
    wire         dut1_lp_32b_stallack;
    wire [255:0] dut2_lp_32b_data;
    wire         dut2_lp_32b_valid;
    wire         dut2_lp_32b_irdy;
    wire         dut2_lp_32b_stallack;

    // u_dut1 error/status outputs
    wire d1_int_req_linkreset;
    wire d1_int_si0_id_mismatch;
    wire d1_int_mi0_id_mismatch;
    wire d1_int_early_resp_err;
    wire d1_int_activate_start;
    wire d1_int_deactivate_start;
    wire d1_aou_activate_st_disabled;
    wire d1_aou_activate_st_enabled;
    wire d1_aou_req_linkreset;

    // u_dut2 error/status outputs
    wire d2_int_req_linkreset;
    wire d2_int_si0_id_mismatch;
    wire d2_int_mi0_id_mismatch;
    wire d2_int_early_resp_err;
    wire d2_int_activate_start;
    wire d2_int_deactivate_start;
    wire d2_aou_activate_st_disabled;
    wire d2_aou_activate_st_enabled;
    wire d2_aou_req_linkreset;

    // ================================================================
    // u_dut1 -- Requester (AXI master VIP -> SI, TX FDI -> u_dut2)
    // ================================================================
    AOU_CORE_TOP #(
        .RP_COUNT    (RP_COUNT),
        .APB_ADDR_WD (APB_ADDR_WD),
        .APB_DATA_WD (APB_DATA_WD)
    ) u_dut1 (
        .I_CLK                       (clk),
        .I_RESETN                    (resetn),
        .I_PCLK                      (pclk),
        .I_PRESETN                   (presetn),

        // APB
        .I_AOU_APB_SI0_PSEL          (apb1_psel),
        .I_AOU_APB_SI0_PENABLE       (apb1_penable),
        .I_AOU_APB_SI0_PADDR         (apb1_paddr),
        .I_AOU_APB_SI0_PWRITE        (apb1_pwrite),
        .I_AOU_APB_SI0_PWDATA        (apb1_pwdata),
        .O_AOU_APB_SI0_PRDATA        (apb1_prdata),
        .O_AOU_APB_SI0_PREADY        (apb1_pready),
        .O_AOU_APB_SI0_PSLVERR       (apb1_pslverr),

        // AXI MI -- connected to axi_sim_mem_intf (reverse path)
        .O_AOU_RX_AXI_M_ARID         (d1_axi_m_arid_b),
        .O_AOU_RX_AXI_M_ARADDR       (d1_axi_m_araddr_b),
        .O_AOU_RX_AXI_M_ARLEN        (d1_axi_m_arlen_b),
        .O_AOU_RX_AXI_M_ARSIZE       (d1_axi_m_arsize_b),
        .O_AOU_RX_AXI_M_ARBURST      (d1_axi_m_arburst_b),
        .O_AOU_RX_AXI_M_ARLOCK       (d1_axi_m_arlock_b),
        .O_AOU_RX_AXI_M_ARCACHE      (d1_axi_m_arcache_b),
        .O_AOU_RX_AXI_M_ARPROT       (d1_axi_m_arprot_b),
        .O_AOU_RX_AXI_M_ARQOS        (d1_axi_m_arqos_b),
        .O_AOU_RX_AXI_M_ARVALID      (d1_axi_m_arvalid_b),
        .I_AOU_RX_AXI_M_ARREADY      (d1_axi_m_arready_b),
        .I_AOU_TX_AXI_M_RID          (d1_axi_m_rid_b),
        .I_AOU_TX_AXI_M_RDATA        (d1_axi_m_rdata_b),
        .I_AOU_TX_AXI_M_RRESP        (d1_axi_m_rresp_b),
        .I_AOU_TX_AXI_M_RLAST        (d1_axi_m_rlast_b),
        .I_AOU_TX_AXI_M_RVALID       (d1_axi_m_rvalid_b),
        .O_AOU_TX_AXI_M_RREADY       (d1_axi_m_rready_b),
        .O_AOU_RX_AXI_M_AWID         (d1_axi_m_awid_b),
        .O_AOU_RX_AXI_M_AWADDR       (d1_axi_m_awaddr_b),
        .O_AOU_RX_AXI_M_AWLEN        (d1_axi_m_awlen_b),
        .O_AOU_RX_AXI_M_AWSIZE       (d1_axi_m_awsize_b),
        .O_AOU_RX_AXI_M_AWBURST      (d1_axi_m_awburst_b),
        .O_AOU_RX_AXI_M_AWLOCK       (d1_axi_m_awlock_b),
        .O_AOU_RX_AXI_M_AWCACHE      (d1_axi_m_awcache_b),
        .O_AOU_RX_AXI_M_AWPROT       (d1_axi_m_awprot_b),
        .O_AOU_RX_AXI_M_AWQOS        (d1_axi_m_awqos_b),
        .O_AOU_RX_AXI_M_AWVALID      (d1_axi_m_awvalid_b),
        .I_AOU_RX_AXI_M_AWREADY      (d1_axi_m_awready_b),
        .O_AOU_RX_AXI_M_WDATA        (d1_axi_m_wdata_b),
        .O_AOU_RX_AXI_M_WSTRB        (d1_axi_m_wstrb_b),
        .O_AOU_RX_AXI_M_WLAST        (d1_axi_m_wlast_b),
        .O_AOU_RX_AXI_M_WVALID       (d1_axi_m_wvalid_b),
        .I_AOU_RX_AXI_M_WREADY       (d1_axi_m_wready_b),
        .I_AOU_TX_AXI_M_BID          (d1_axi_m_bid_b),
        .I_AOU_TX_AXI_M_BRESP        (d1_axi_m_bresp_b),
        .I_AOU_TX_AXI_M_BVALID       (d1_axi_m_bvalid_b),
        .O_AOU_TX_AXI_M_BREADY       (d1_axi_m_bready_b),

        // AXI SI -- connected to axi_rand_master VIP
        .I_AOU_TX_AXI_S_ARID         (axi_s_arid),
        .I_AOU_TX_AXI_S_ARADDR       (axi_s_araddr),
        .I_AOU_TX_AXI_S_ARLEN        (axi_s_arlen),
        .I_AOU_TX_AXI_S_ARSIZE       (axi_s_arsize),
        .I_AOU_TX_AXI_S_ARBURST      (axi_s_arburst),
        .I_AOU_TX_AXI_S_ARLOCK       (axi_s_arlock),
        .I_AOU_TX_AXI_S_ARCACHE      (axi_s_arcache),
        .I_AOU_TX_AXI_S_ARPROT       (axi_s_arprot),
        .I_AOU_TX_AXI_S_ARQOS        (axi_s_arqos),
        .I_AOU_TX_AXI_S_ARVALID      (axi_s_arvalid),
        .O_AOU_TX_AXI_S_ARREADY      (axi_s_arready),
        .O_AOU_RX_AXI_S_RID          (axi_s_rid),
        .O_AOU_RX_AXI_S_RDATA        (axi_s_rdata),
        .O_AOU_RX_AXI_S_RRESP        (axi_s_rresp),
        .O_AOU_RX_AXI_S_RLAST        (axi_s_rlast),
        .O_AOU_RX_AXI_S_RVALID       (axi_s_rvalid),
        .I_AOU_RX_AXI_S_RREADY       (axi_s_rready),
        .I_AOU_TX_AXI_S_AWID         (axi_s_awid),
        .I_AOU_TX_AXI_S_AWADDR       (axi_s_awaddr),
        .I_AOU_TX_AXI_S_AWLEN        (axi_s_awlen),
        .I_AOU_TX_AXI_S_AWSIZE       (axi_s_awsize),
        .I_AOU_TX_AXI_S_AWBURST      (axi_s_awburst),
        .I_AOU_TX_AXI_S_AWLOCK       (axi_s_awlock),
        .I_AOU_TX_AXI_S_AWCACHE      (axi_s_awcache),
        .I_AOU_TX_AXI_S_AWPROT       (axi_s_awprot),
        .I_AOU_TX_AXI_S_AWQOS        (axi_s_awqos),
        .I_AOU_TX_AXI_S_AWVALID      (axi_s_awvalid),
        .O_AOU_TX_AXI_S_AWREADY      (axi_s_awready),
        .I_AOU_TX_AXI_S_WDATA        (axi_s_wdata),
        .I_AOU_TX_AXI_S_WSTRB        (axi_s_wstrb),
        .I_AOU_TX_AXI_S_WLAST        (axi_s_wlast),
        .I_AOU_TX_AXI_S_WVALID       (axi_s_wvalid),
        .O_AOU_TX_AXI_S_WREADY       (axi_s_wready),
        .O_AOU_RX_AXI_S_BID          (axi_s_bid),
        .O_AOU_RX_AXI_S_BRESP        (axi_s_bresp),
        .O_AOU_RX_AXI_S_BVALID       (axi_s_bvalid),
        .I_AOU_RX_AXI_S_BREADY       (axi_s_bready),

        // PHY
        .I_PHY_TYPE                   (1'b1),

        // FDI 32B (unused)
        .I_FDI_PL_32B_VALID           (1'b0),
        .I_FDI_PL_32B_DATA            (256'b0),
        .I_FDI_PL_32B_FLIT_CANCEL     (1'b0),
        .I_FDI_PL_32B_TRDY            (1'b0),
        .I_FDI_PL_32B_STALLREQ        (1'b0),
        .I_FDI_PL_32B_STATE_STS       (4'h0),
        .O_FDI_LP_32B_DATA            (dut1_lp_32b_data),
        .O_FDI_LP_32B_VALID           (dut1_lp_32b_valid),
        .O_FDI_LP_32B_IRDY            (dut1_lp_32b_irdy),
        .O_FDI_LP_32B_STALLACK        (dut1_lp_32b_stallack),

        // FDI 64B -- TX outputs cross to u_dut2 RX, RX inputs from u_dut2 TX
        .I_FDI_PL_64B_VALID           (dut2_lp_64b_valid),
        .I_FDI_PL_64B_DATA            (dut2_lp_64b_data),
        .I_FDI_PL_64B_FLIT_CANCEL     (1'b0),
        .I_FDI_PL_64B_TRDY            (1'b1),
        .I_FDI_PL_64B_STALLREQ        (1'b0),
        .I_FDI_PL_64B_STATE_STS       (4'h1),
        .O_FDI_LP_64B_DATA            (dut1_lp_64b_data),
        .O_FDI_LP_64B_VALID           (dut1_lp_64b_valid),
        .O_FDI_LP_64B_IRDY            (dut1_lp_64b_irdy),
        .O_FDI_LP_64B_STALLACK        (dut1_lp_64b_stallack),

        // Error / status
        .INT_REQ_LINKRESET            (d1_int_req_linkreset),
        .INT_SI0_ID_MISMATCH          (d1_int_si0_id_mismatch),
        .INT_MI0_ID_MISMATCH          (d1_int_mi0_id_mismatch),
        .INT_EARLY_RESP_ERR           (d1_int_early_resp_err),
        .INT_ACTIVATE_START           (d1_int_activate_start),
        .INT_DEACTIVATE_START         (d1_int_deactivate_start),

        // UCIE
        .I_INT_FSM_IN_ACTIVE          (1'b1),
        .I_MST_BUS_CLEANY_COMPLETE    (1'b1),
        .I_SLV_BUS_CLEANY_COMPLETE    (1'b1),
        .O_AOU_ACTIVATE_ST_DISABLED   (d1_aou_activate_st_disabled),
        .O_AOU_ACTIVATE_ST_ENABLED    (d1_aou_activate_st_enabled),
        .O_AOU_REQ_LINKRESET          (d1_aou_req_linkreset),

        // DFT
        .TIEL_DFT_MODESCAN            (1'b0)
    );

    // ================================================================
    // u_dut2 -- Completer (RX FDI from u_dut1, AXI MI -> slave VIP)
    // ================================================================
    AOU_CORE_TOP #(
        .RP_COUNT        (RP_COUNT),
        .RP0_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP1_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP2_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .RP3_AXI_DATA_WD (D2_AXI_DATA_WIDTH),
        .APB_ADDR_WD     (APB_ADDR_WD),
        .APB_DATA_WD     (APB_DATA_WD)
    ) u_dut2 (
        .I_CLK                       (clk),
        .I_RESETN                    (resetn),
        .I_PCLK                      (pclk),
        .I_PRESETN                   (presetn),

        // APB
        .I_AOU_APB_SI0_PSEL          (apb2_psel),
        .I_AOU_APB_SI0_PENABLE       (apb2_penable),
        .I_AOU_APB_SI0_PADDR         (apb2_paddr),
        .I_AOU_APB_SI0_PWRITE        (apb2_pwrite),
        .I_AOU_APB_SI0_PWDATA        (apb2_pwdata),
        .O_AOU_APB_SI0_PRDATA        (apb2_prdata),
        .O_AOU_APB_SI0_PREADY        (apb2_pready),
        .O_AOU_APB_SI0_PSLVERR       (apb2_pslverr),

        // AXI MI -- connected to axi_sim_mem_intf
        .O_AOU_RX_AXI_M_ARID         (d2_axi_m_arid),
        .O_AOU_RX_AXI_M_ARADDR       (d2_axi_m_araddr),
        .O_AOU_RX_AXI_M_ARLEN        (d2_axi_m_arlen),
        .O_AOU_RX_AXI_M_ARSIZE       (d2_axi_m_arsize),
        .O_AOU_RX_AXI_M_ARBURST      (d2_axi_m_arburst),
        .O_AOU_RX_AXI_M_ARLOCK       (d2_axi_m_arlock),
        .O_AOU_RX_AXI_M_ARCACHE      (d2_axi_m_arcache),
        .O_AOU_RX_AXI_M_ARPROT       (d2_axi_m_arprot),
        .O_AOU_RX_AXI_M_ARQOS        (d2_axi_m_arqos),
        .O_AOU_RX_AXI_M_ARVALID      (d2_axi_m_arvalid),
        .I_AOU_RX_AXI_M_ARREADY      (d2_axi_m_arready),
        .I_AOU_TX_AXI_M_RID          (d2_axi_m_rid),
        .I_AOU_TX_AXI_M_RDATA        (d2_axi_m_rdata),
        .I_AOU_TX_AXI_M_RRESP        (d2_axi_m_rresp),
        .I_AOU_TX_AXI_M_RLAST        (d2_axi_m_rlast),
        .I_AOU_TX_AXI_M_RVALID       (d2_axi_m_rvalid),
        .O_AOU_TX_AXI_M_RREADY       (d2_axi_m_rready),
        .O_AOU_RX_AXI_M_AWID         (d2_axi_m_awid),
        .O_AOU_RX_AXI_M_AWADDR       (d2_axi_m_awaddr),
        .O_AOU_RX_AXI_M_AWLEN        (d2_axi_m_awlen),
        .O_AOU_RX_AXI_M_AWSIZE       (d2_axi_m_awsize),
        .O_AOU_RX_AXI_M_AWBURST      (d2_axi_m_awburst),
        .O_AOU_RX_AXI_M_AWLOCK       (d2_axi_m_awlock),
        .O_AOU_RX_AXI_M_AWCACHE      (d2_axi_m_awcache),
        .O_AOU_RX_AXI_M_AWPROT       (d2_axi_m_awprot),
        .O_AOU_RX_AXI_M_AWQOS        (d2_axi_m_awqos),
        .O_AOU_RX_AXI_M_AWVALID      (d2_axi_m_awvalid),
        .I_AOU_RX_AXI_M_AWREADY      (d2_axi_m_awready),
        .O_AOU_RX_AXI_M_WDATA        (d2_axi_m_wdata),
        .O_AOU_RX_AXI_M_WSTRB        (d2_axi_m_wstrb),
        .O_AOU_RX_AXI_M_WLAST        (d2_axi_m_wlast),
        .O_AOU_RX_AXI_M_WVALID       (d2_axi_m_wvalid),
        .I_AOU_RX_AXI_M_WREADY       (d2_axi_m_wready),
        .I_AOU_TX_AXI_M_BID          (d2_axi_m_bid),
        .I_AOU_TX_AXI_M_BRESP        (d2_axi_m_bresp),
        .I_AOU_TX_AXI_M_BVALID       (d2_axi_m_bvalid),
        .O_AOU_TX_AXI_M_BREADY       (d2_axi_m_bready),

        // AXI SI -- connected to axi_rand_master VIP (reverse path)
        .I_AOU_TX_AXI_S_ARID         (d2_axi_s_arid),
        .I_AOU_TX_AXI_S_ARADDR       (d2_axi_s_araddr),
        .I_AOU_TX_AXI_S_ARLEN        (d2_axi_s_arlen),
        .I_AOU_TX_AXI_S_ARSIZE       (d2_axi_s_arsize),
        .I_AOU_TX_AXI_S_ARBURST      (d2_axi_s_arburst),
        .I_AOU_TX_AXI_S_ARLOCK       (d2_axi_s_arlock),
        .I_AOU_TX_AXI_S_ARCACHE      (d2_axi_s_arcache),
        .I_AOU_TX_AXI_S_ARPROT       (d2_axi_s_arprot),
        .I_AOU_TX_AXI_S_ARQOS        (d2_axi_s_arqos),
        .I_AOU_TX_AXI_S_ARVALID      (d2_axi_s_arvalid),
        .O_AOU_TX_AXI_S_ARREADY      (d2_axi_s_arready),
        .O_AOU_RX_AXI_S_RID          (d2_axi_s_rid),
        .O_AOU_RX_AXI_S_RDATA        (d2_axi_s_rdata),
        .O_AOU_RX_AXI_S_RRESP        (d2_axi_s_rresp),
        .O_AOU_RX_AXI_S_RLAST        (d2_axi_s_rlast),
        .O_AOU_RX_AXI_S_RVALID       (d2_axi_s_rvalid),
        .I_AOU_RX_AXI_S_RREADY       (d2_axi_s_rready),
        .I_AOU_TX_AXI_S_AWID         (d2_axi_s_awid),
        .I_AOU_TX_AXI_S_AWADDR       (d2_axi_s_awaddr),
        .I_AOU_TX_AXI_S_AWLEN        (d2_axi_s_awlen),
        .I_AOU_TX_AXI_S_AWSIZE       (d2_axi_s_awsize),
        .I_AOU_TX_AXI_S_AWBURST      (d2_axi_s_awburst),
        .I_AOU_TX_AXI_S_AWLOCK       (d2_axi_s_awlock),
        .I_AOU_TX_AXI_S_AWCACHE      (d2_axi_s_awcache),
        .I_AOU_TX_AXI_S_AWPROT       (d2_axi_s_awprot),
        .I_AOU_TX_AXI_S_AWQOS        (d2_axi_s_awqos),
        .I_AOU_TX_AXI_S_AWVALID      (d2_axi_s_awvalid),
        .O_AOU_TX_AXI_S_AWREADY      (d2_axi_s_awready),
        .I_AOU_TX_AXI_S_WDATA        (d2_axi_s_wdata),
        .I_AOU_TX_AXI_S_WSTRB        (d2_axi_s_wstrb),
        .I_AOU_TX_AXI_S_WLAST        (d2_axi_s_wlast),
        .I_AOU_TX_AXI_S_WVALID       (d2_axi_s_wvalid),
        .O_AOU_TX_AXI_S_WREADY       (d2_axi_s_wready),
        .O_AOU_RX_AXI_S_BID          (d2_axi_s_bid),
        .O_AOU_RX_AXI_S_BRESP        (d2_axi_s_bresp),
        .O_AOU_RX_AXI_S_BVALID       (d2_axi_s_bvalid),
        .I_AOU_RX_AXI_S_BREADY       (d2_axi_s_bready),

        // PHY
        .I_PHY_TYPE                   (1'b1),

        // FDI 32B (unused)
        .I_FDI_PL_32B_VALID           (1'b0),
        .I_FDI_PL_32B_DATA            (256'b0),
        .I_FDI_PL_32B_FLIT_CANCEL     (1'b0),
        .I_FDI_PL_32B_TRDY            (1'b0),
        .I_FDI_PL_32B_STALLREQ        (1'b0),
        .I_FDI_PL_32B_STATE_STS       (4'h0),
        .O_FDI_LP_32B_DATA            (dut2_lp_32b_data),
        .O_FDI_LP_32B_VALID           (dut2_lp_32b_valid),
        .O_FDI_LP_32B_IRDY            (dut2_lp_32b_irdy),
        .O_FDI_LP_32B_STALLACK        (dut2_lp_32b_stallack),

        // FDI 64B -- RX from u_dut1 TX, TX outputs cross back to u_dut1 RX
        .I_FDI_PL_64B_VALID           (dut1_lp_64b_valid),
        .I_FDI_PL_64B_DATA            (dut1_lp_64b_data),
        .I_FDI_PL_64B_FLIT_CANCEL     (1'b0),
        .I_FDI_PL_64B_TRDY            (1'b1),
        .I_FDI_PL_64B_STALLREQ        (1'b0),
        .I_FDI_PL_64B_STATE_STS       (4'h1),
        .O_FDI_LP_64B_DATA            (dut2_lp_64b_data),
        .O_FDI_LP_64B_VALID           (dut2_lp_64b_valid),
        .O_FDI_LP_64B_IRDY            (dut2_lp_64b_irdy),
        .O_FDI_LP_64B_STALLACK        (dut2_lp_64b_stallack),

        // Error / status
        .INT_REQ_LINKRESET            (d2_int_req_linkreset),
        .INT_SI0_ID_MISMATCH          (d2_int_si0_id_mismatch),
        .INT_MI0_ID_MISMATCH          (d2_int_mi0_id_mismatch),
        .INT_EARLY_RESP_ERR           (d2_int_early_resp_err),
        .INT_ACTIVATE_START           (d2_int_activate_start),
        .INT_DEACTIVATE_START         (d2_int_deactivate_start),

        // UCIE
        .I_INT_FSM_IN_ACTIVE          (1'b1),
        .I_MST_BUS_CLEANY_COMPLETE    (1'b1),
        .I_SLV_BUS_CLEANY_COMPLETE    (1'b1),
        .O_AOU_ACTIVATE_ST_DISABLED   (d2_aou_activate_st_disabled),
        .O_AOU_ACTIVATE_ST_ENABLED    (d2_aou_activate_st_enabled),
        .O_AOU_REQ_LINKRESET          (d2_aou_req_linkreset),

        // DFT
        .TIEL_DFT_MODESCAN            (1'b0)
    );

    // ================================================================
    // VIP typedefs
    // ================================================================
    typedef axi_test::axi_rand_master #(
        .AW                 (AXI_ADDR_WIDTH),
        .DW                 (AXI_DATA_WIDTH),
        .IW                 (AXI_ID_WIDTH),
        .UW                 (AXI_USER_WIDTH),
        .TA                 (TA),
        .TT                 (TT),
        .MAX_READ_TXNS      (1),
        .MAX_WRITE_TXNS     (1),
        .SIZE_ALIGN         (6),
        .AXI_MAX_BURST_LEN  (1),
        .TRAFFIC_SHAPING    (1),
        .AXI_BURST_FIXED    (1'b0),
        .AXI_BURST_INCR     (1'b1),
        .AXI_BURST_WRAP     (1'b0),
        .AXI_EXCLS          (1'b0),
        .AXI_ATOPS          (1'b0)
    ) axi_rand_master_t;

    typedef axi_test::axi_rand_master #(
        .AW                 (AXI_ADDR_WIDTH),
        .DW                 (D2_AXI_DATA_WIDTH),
        .IW                 (AXI_ID_WIDTH),
        .UW                 (AXI_USER_WIDTH),
        .TA                 (TA),
        .TT                 (TT),
        .MAX_READ_TXNS      (1),
        .MAX_WRITE_TXNS     (1),
        .SIZE_ALIGN         (6),
        .AXI_MAX_BURST_LEN  (2),
        .TRAFFIC_SHAPING    (1),
        .AXI_BURST_FIXED    (1'b0),
        .AXI_BURST_INCR     (1'b1),
        .AXI_BURST_WRAP     (1'b0),
        .AXI_EXCLS          (1'b0),
        .AXI_ATOPS          (1'b0)
    ) axi_rand_master_d2_t;

    typedef axi_test::axi_scoreboard #(
        .IW (AXI_ID_WIDTH),
        .AW (AXI_ADDR_WIDTH),
        .DW (AXI_DATA_WIDTH),
        .UW (AXI_USER_WIDTH),
        .TT (TT)
    ) axi_scoreboard_d1_t;

    typedef axi_test::axi_scoreboard #(
        .IW (AXI_ID_WIDTH),
        .AW (AXI_ADDR_WIDTH),
        .DW (D2_AXI_DATA_WIDTH),
        .UW (AXI_USER_WIDTH),
        .TT (TT)
    ) axi_scoreboard_d2_t;

    // ================================================================
    // APB write tasks
    // ================================================================
    task apb_write1(input [APB_ADDR_WD-1:0] addr, input [APB_DATA_WD-1:0] data);
        @(posedge pclk);
        apb1_psel    <= 1'b1;
        apb1_penable <= 1'b0;
        apb1_paddr   <= addr;
        apb1_pwrite  <= 1'b1;
        apb1_pwdata  <= data;
        @(posedge pclk);
        apb1_penable <= 1'b1;
        do @(posedge pclk); while (!apb1_pready);
        apb1_psel    <= 1'b0;
        apb1_penable <= 1'b0;
        apb1_pwrite  <= 1'b0;
    endtask

    task apb_write2(input [APB_ADDR_WD-1:0] addr, input [APB_DATA_WD-1:0] data);
        @(posedge pclk);
        apb2_psel    <= 1'b1;
        apb2_penable <= 1'b0;
        apb2_paddr   <= addr;
        apb2_pwrite  <= 1'b1;
        apb2_pwdata  <= data;
        @(posedge pclk);
        apb2_penable <= 1'b1;
        do @(posedge pclk); while (!apb2_pready);
        apb2_psel    <= 1'b0;
        apb2_penable <= 1'b0;
        apb2_pwrite  <= 1'b0;
    endtask

    // ================================================================
    // Init sequence: resets + APB activate_start on both instances
    // ================================================================
    initial begin
        $display("=== Dual AOU_CORE_TOP FDI Loopback Testbench Start ===");

        resetn       = 1'b0;
        presetn      = 1'b0;
        apb1_psel    = 1'b0;
        apb1_penable = 1'b0;
        apb1_paddr   = '0;
        apb1_pwrite  = 1'b0;
        apb1_pwdata  = '0;
        apb2_psel    = 1'b0;
        apb2_penable = 1'b0;
        apb2_paddr   = '0;
        apb2_pwrite  = 1'b0;
        apb2_pwdata  = '0;

        repeat (20) @(posedge pclk);
        resetn  = 1'b1;
        presetn = 1'b1;
        $display("[%0t] Resets de-asserted", $time);

        repeat (10) @(posedge pclk);

        $display("[%0t] APB WRITE: u_dut1 addr=0x8 data=0x1", $time);
        apb_write1(32'h0000_0008, 32'h0000_0001);
        $display("[%0t] APB WRITE: u_dut2 addr=0x8 data=0x1", $time);
        apb_write2(32'h0000_0008, 32'h0000_0001);
        $display("[%0t] APB init complete for both instances", $time);

        repeat (10) @(posedge pclk);
    end

    // ================================================================
    // AXI scoreboards (monitor SI interfaces for data integrity)
    // ================================================================
    initial begin : proc_scoreboard_d1
        automatic axi_scoreboard_d1_t sb = new(axi_if);
        @(posedge resetn);
        sb.enable_all_checks();
        sb.monitor();
    end

    initial begin : proc_scoreboard_d2
        automatic axi_scoreboard_d2_t sb = new(axi_mst2_if);
        @(posedge resetn);
        sb.enable_all_checks();
        sb.monitor();
    end

    // ================================================================
    // AXI master VIP on u_dut1 SI (forward path requester)
    // ================================================================
    bit fwd_done = 0;
    initial begin : proc_axi_master_d1
        automatic axi_rand_master_t axi_rand_master = new(axi_if);
        axi_rand_master.add_memory_region(64'h0, 64'h3F,
                                          axi_pkg::DEVICE_NONBUFFERABLE);
        axi_rand_master.add_traffic_shaping_with_size(0, 6, 1);
        axi_rand_master.reset();
        @(posedge resetn);

        repeat (50) @(posedge pclk);

        $display("[%0t] FWD AXI master (u_dut1 SI): Starting 1 write", $time);
        axi_rand_master.run(0, 1);
        $display("[%0t] FWD AXI master (u_dut1 SI): Write complete, starting 1 read", $time);
        axi_rand_master.run(1, 0);
        $display("[%0t] FWD AXI master (u_dut1 SI): Read complete", $time);
        fwd_done = 1;
    end

    // ================================================================
    // AXI master VIP on u_dut2 SI (reverse path requester)
    // ================================================================
    bit rev_done = 0;
    initial begin : proc_axi_master_d2
        automatic axi_rand_master_d2_t axi_rand_master = new(axi_mst2_if);
        axi_rand_master.add_memory_region(64'h0, 64'h3F,
                                          axi_pkg::DEVICE_NONBUFFERABLE);
        axi_rand_master.add_traffic_shaping_with_size(1, 5, 1);
        axi_rand_master.reset();
        @(posedge resetn);

        repeat (50) @(posedge pclk);

        $display("[%0t] REV AXI master (u_dut2 SI): Starting 1 write", $time);
        axi_rand_master.run(0, 1);
        $display("[%0t] REV AXI master (u_dut2 SI): Write complete, starting 1 read", $time);
        axi_rand_master.run(1, 0);
        $display("[%0t] REV AXI master (u_dut2 SI): Read complete", $time);
        rev_done = 1;
    end

    // ================================================================
    // Final report: wait for both directions, then finish
    // Scoreboard assertions fire on miscompare; absence of errors = PASS.
    // ================================================================
    initial begin : proc_report
        wait(fwd_done && rev_done);
        repeat (200) @(posedge clk);

        $display("==================================================");
        $display("  Scoreboard checking complete.");
        $display("  If no $warning/$error from axi_scoreboard above, PASS.");
        $display("==================================================");
        $display("=== Dual AOU_CORE_TOP FDI Loopback Testbench Complete ===");
        $finish;
    end

    // Safety timeout
    initial begin
        #1_000_000;
        $display("ERROR: Testbench timeout at %0t", $time);
        $finish;
    end

endmodule
