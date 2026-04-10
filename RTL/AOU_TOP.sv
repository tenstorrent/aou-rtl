// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
//  Copyright (c) 2026 BOS Semiconductors
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
//  Module     : AOU_TOP
//  Description: Top-level wrapper integrating AOU_FDI_BRINGUP_CTRL (UCIe 3.0
//               FDI state machine) with AOU_CORE_TOP (AXI-over-UCIe protocol
//               engine). The bringup controller manages FDI handshakes
//               (wake, clock, state, rx-active) and drives I_INT_FSM_IN_ACTIVE
//               into the AOU core, replacing the former external UCIE_CORE
//               connection.
//
// *****************************************************************************

`default_nettype none
`timescale 1ns/1ps

module AOU_TOP
import packet_def_pkg::*;
#(
    parameter   RP_COUNT                    = 2,

    parameter   RP0_RX_AW_FIFO_DEPTH        = 44,
    parameter   RP0_RX_AR_FIFO_DEPTH        = 44,
    parameter   RP0_RX_W_FIFO_DEPTH         = 88,
    parameter   RP0_RX_R_FIFO_DEPTH         = 88,
    parameter   RP0_RX_B_FIFO_DEPTH         = 44,

    parameter   RP1_RX_AW_FIFO_DEPTH        = 44,
    parameter   RP1_RX_AR_FIFO_DEPTH        = 44,
    parameter   RP1_RX_W_FIFO_DEPTH         = 88,
    parameter   RP1_RX_R_FIFO_DEPTH         = 88,
    parameter   RP1_RX_B_FIFO_DEPTH         = 44,

    parameter   RP2_RX_AW_FIFO_DEPTH        = 44,
    parameter   RP2_RX_AR_FIFO_DEPTH        = 44,
    parameter   RP2_RX_W_FIFO_DEPTH         = 88,
    parameter   RP2_RX_R_FIFO_DEPTH         = 88,
    parameter   RP2_RX_B_FIFO_DEPTH         = 44,

    parameter   RP3_RX_AW_FIFO_DEPTH        = 44,
    parameter   RP3_RX_AR_FIFO_DEPTH        = 44,
    parameter   RP3_RX_W_FIFO_DEPTH         = 88,
    parameter   RP3_RX_R_FIFO_DEPTH         = 88,
    parameter   RP3_RX_B_FIFO_DEPTH         = 44,

    parameter   RP0_AXI_DATA_WD             = 512,
    parameter   RP1_AXI_DATA_WD             = 512,
    parameter   RP2_AXI_DATA_WD             = 512,
    parameter   RP3_AXI_DATA_WD             = 512,

    parameter   AXI_PEER_DIE_MAX_DATA_WD    = 1024,

    parameter   APB_ADDR_WD                 = 32,
    parameter   APB_DATA_WD                 = 32,

    parameter   S_RD_MO_CNT                 = 32,
    parameter   S_WR_MO_CNT                 = 32,

    parameter   M_RD_MO_CNT                 = 32,
    parameter   M_WR_MO_CNT                 = 32,

    localparam  RP_AXI_DATA_WD_MAX          = max4(RP0_AXI_DATA_WD, RP1_AXI_DATA_WD, RP2_AXI_DATA_WD, RP3_AXI_DATA_WD),
    localparam  RP_AXI_STRB_WD_MAX          = RP_AXI_DATA_WD_MAX / 8,

    localparam  AXI_ADDR_WD                 = 64,
    localparam  AXI_ID_WD                   = 10,
    localparam  AXI_LEN_WD                  = 8
)
(
    input  logic                                        I_CLK,
    input  logic                                        I_RESETN,

    input  logic                                        I_PCLK,
    input  logic                                        I_PRESETN,

    // ================================================================
    // APB slave interface
    // ================================================================
    input  logic                                        I_AOU_APB_SI0_PSEL,
    input  logic                                        I_AOU_APB_SI0_PENABLE,
    input  logic [APB_ADDR_WD-1:0]                      I_AOU_APB_SI0_PADDR,
    input  logic                                        I_AOU_APB_SI0_PWRITE,
    input  logic [APB_DATA_WD-1:0]                      I_AOU_APB_SI0_PWDATA,

    output logic [APB_DATA_WD-1:0]                      O_AOU_APB_SI0_PRDATA,
    output logic                                        O_AOU_APB_SI0_PREADY,
    output logic                                        O_AOU_APB_SI0_PSLVERR,

    // ================================================================
    // AXI master interface (RX → downstream)
    // ================================================================
    output logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          O_AOU_RX_AXI_M_ARID,
    output logic [RP_COUNT-1:0][AXI_ADDR_WD-1:0]        O_AOU_RX_AXI_M_ARADDR,
    output logic [RP_COUNT-1:0][AXI_LEN_WD-1:0]         O_AOU_RX_AXI_M_ARLEN,
    output logic [RP_COUNT-1:0][2:0]                    O_AOU_RX_AXI_M_ARSIZE,
    output logic [RP_COUNT-1:0][1:0]                    O_AOU_RX_AXI_M_ARBURST,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_ARLOCK,
    output logic [RP_COUNT-1:0][3:0]                    O_AOU_RX_AXI_M_ARCACHE,
    output logic [RP_COUNT-1:0][2:0]                    O_AOU_RX_AXI_M_ARPROT,
    output logic [RP_COUNT-1:0][3:0]                    O_AOU_RX_AXI_M_ARQOS,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_ARVALID,
    input  logic [RP_COUNT-1:0]                         I_AOU_RX_AXI_M_ARREADY,

    input  logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          I_AOU_TX_AXI_M_RID,
    input  logic [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] I_AOU_TX_AXI_M_RDATA,
    input  logic [RP_COUNT-1:0][1:0]                    I_AOU_TX_AXI_M_RRESP,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_M_RLAST,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_M_RVALID,
    output logic [RP_COUNT-1:0]                         O_AOU_TX_AXI_M_RREADY,

    output logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          O_AOU_RX_AXI_M_AWID,
    output logic [RP_COUNT-1:0][AXI_ADDR_WD-1:0]        O_AOU_RX_AXI_M_AWADDR,
    output logic [RP_COUNT-1:0][AXI_LEN_WD-1:0]         O_AOU_RX_AXI_M_AWLEN,
    output logic [RP_COUNT-1:0][2:0]                    O_AOU_RX_AXI_M_AWSIZE,
    output logic [RP_COUNT-1:0][1:0]                    O_AOU_RX_AXI_M_AWBURST,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_AWLOCK,
    output logic [RP_COUNT-1:0][3:0]                    O_AOU_RX_AXI_M_AWCACHE,
    output logic [RP_COUNT-1:0][2:0]                    O_AOU_RX_AXI_M_AWPROT,
    output logic [RP_COUNT-1:0][3:0]                    O_AOU_RX_AXI_M_AWQOS,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_AWVALID,
    input  logic [RP_COUNT-1:0]                         I_AOU_RX_AXI_M_AWREADY,

    output logic [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] O_AOU_RX_AXI_M_WDATA,
    output logic [RP_COUNT-1:0][RP_AXI_STRB_WD_MAX-1:0] O_AOU_RX_AXI_M_WSTRB,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_WLAST,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_M_WVALID,
    input  logic [RP_COUNT-1:0]                         I_AOU_RX_AXI_M_WREADY,

    input  logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          I_AOU_TX_AXI_M_BID,
    input  logic [RP_COUNT-1:0][1:0]                    I_AOU_TX_AXI_M_BRESP,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_M_BVALID,
    output logic [RP_COUNT-1:0]                         O_AOU_TX_AXI_M_BREADY,

    // ================================================================
    // AXI slave interface (TX → upstream)
    // ================================================================
    input  logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          I_AOU_TX_AXI_S_ARID,
    input  logic [RP_COUNT-1:0][AXI_ADDR_WD-1:0]        I_AOU_TX_AXI_S_ARADDR,
    input  logic [RP_COUNT-1:0][AXI_LEN_WD-1:0]         I_AOU_TX_AXI_S_ARLEN,
    input  logic [RP_COUNT-1:0][2:0]                    I_AOU_TX_AXI_S_ARSIZE,
    input  logic [RP_COUNT-1:0][1:0]                    I_AOU_TX_AXI_S_ARBURST,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_ARLOCK,
    input  logic [RP_COUNT-1:0][3:0]                    I_AOU_TX_AXI_S_ARCACHE,
    input  logic [RP_COUNT-1:0][2:0]                    I_AOU_TX_AXI_S_ARPROT,
    input  logic [RP_COUNT-1:0][3:0]                    I_AOU_TX_AXI_S_ARQOS,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_ARVALID,
    output logic [RP_COUNT-1:0]                         O_AOU_TX_AXI_S_ARREADY,

    output logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          O_AOU_RX_AXI_S_RID,
    output logic [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] O_AOU_RX_AXI_S_RDATA,
    output logic [RP_COUNT-1:0][1:0]                    O_AOU_RX_AXI_S_RRESP,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_S_RLAST,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_S_RVALID,
    input  logic [RP_COUNT-1:0]                         I_AOU_RX_AXI_S_RREADY,

    input  logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          I_AOU_TX_AXI_S_AWID,
    input  logic [RP_COUNT-1:0][AXI_ADDR_WD-1:0]        I_AOU_TX_AXI_S_AWADDR,
    input  logic [RP_COUNT-1:0][AXI_LEN_WD-1:0]         I_AOU_TX_AXI_S_AWLEN,
    input  logic [RP_COUNT-1:0][2:0]                    I_AOU_TX_AXI_S_AWSIZE,
    input  logic [RP_COUNT-1:0][1:0]                    I_AOU_TX_AXI_S_AWBURST,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_AWLOCK,
    input  logic [RP_COUNT-1:0][3:0]                    I_AOU_TX_AXI_S_AWCACHE,
    input  logic [RP_COUNT-1:0][2:0]                    I_AOU_TX_AXI_S_AWPROT,
    input  logic [RP_COUNT-1:0][3:0]                    I_AOU_TX_AXI_S_AWQOS,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_AWVALID,
    output logic [RP_COUNT-1:0]                         O_AOU_TX_AXI_S_AWREADY,

    input  logic [RP_COUNT-1:0][RP_AXI_DATA_WD_MAX-1:0] I_AOU_TX_AXI_S_WDATA,
    input  logic [RP_COUNT-1:0][RP_AXI_STRB_WD_MAX-1:0] I_AOU_TX_AXI_S_WSTRB,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_WLAST,
    input  logic [RP_COUNT-1:0]                         I_AOU_TX_AXI_S_WVALID,
    output logic [RP_COUNT-1:0]                         O_AOU_TX_AXI_S_WREADY,

    output logic [RP_COUNT-1:0][AXI_ID_WD-1:0]          O_AOU_RX_AXI_S_BID,
    output logic [RP_COUNT-1:0][1:0]                    O_AOU_RX_AXI_S_BRESP,
    output logic [RP_COUNT-1:0]                         O_AOU_RX_AXI_S_BVALID,
    input  logic [RP_COUNT-1:0]                         I_AOU_RX_AXI_S_BREADY,

    // ================================================================
    // PHY type select
    // ================================================================
    input  logic                                        I_PHY_TYPE,

    // ================================================================
    // FDI data-path interface (directly to AOU_CORE_TOP)
    // ================================================================
    input  logic                                        I_FDI_PL_32B_VALID,
    input  logic [32*8-1:0]                             I_FDI_PL_32B_DATA,
    input  logic                                        I_FDI_PL_32B_FLIT_CANCEL,

    input  logic                                        I_FDI_PL_64B_VALID,
    input  logic [64*8-1:0]                             I_FDI_PL_64B_DATA,
    input  logic                                        I_FDI_PL_64B_FLIT_CANCEL,

    input  logic                                        I_FDI_PL_32B_TRDY,
    input  logic                                        I_FDI_PL_32B_STALLREQ,
    input  logic [3:0]                                  I_FDI_PL_32B_STATE_STS,
    output logic [255:0]                                O_FDI_LP_32B_DATA,
    output logic                                        O_FDI_LP_32B_VALID,
    output logic                                        O_FDI_LP_32B_IRDY,
    output logic                                        O_FDI_LP_32B_STALLACK,

    input  logic                                        I_FDI_PL_64B_TRDY,
    input  logic                                        I_FDI_PL_64B_STALLREQ,
    input  logic [3:0]                                  I_FDI_PL_64B_STATE_STS,
    output logic [511:0]                                O_FDI_LP_64B_DATA,
    output logic                                        O_FDI_LP_64B_VALID,
    output logic                                        O_FDI_LP_64B_IRDY,
    output logic                                        O_FDI_LP_64B_STALLACK,

    // ================================================================
    // FDI bringup control interface (to AOU_FDI_BRINGUP_CTRL)
    // ================================================================
    input  logic                                        I_PL_INBAND_PRES,
    input  logic                                        I_PL_CLK_REQ,
    input  logic                                        I_PL_WAKE_ACK,
    input  logic                                        I_PL_RX_ACTIVE_REQ,

    output logic [3:0]                                  O_LP_STATE_REQ,
    output logic                                        O_LP_WAKE_REQ,
    output logic                                        O_LP_CLK_ACK,
    output logic                                        O_LP_RX_ACTIVE_STS,

    // ================================================================
    // FDI bringup software control
    // ================================================================
    input  logic                                        I_SW_ACTIVATE_START,
    input  logic                                        I_SW_DEACTIVATE_START,
    input  logic                                        I_SW_RETRAIN_REQ,
    input  logic                                        I_SW_LINKERROR_INJECT,

    // ================================================================
    // FDI bringup status
    // ================================================================
    output logic [3:0]                                  O_FDI_FSM_STATE,
    output logic                                        O_FDI_LINK_UP,

    // ================================================================
    // Interrupt outputs
    // ================================================================
    output logic                                        INT_REQ_LINKRESET,
    output logic                                        INT_SI0_ID_MISMATCH,
    output logic                                        INT_MI0_ID_MISMATCH,
    output logic                                        INT_EARLY_RESP_ERR,
    output logic                                        INT_ACTIVATE_START,
    output logic                                        INT_DEACTIVATE_START,

    // ================================================================
    // Bus quiescence (from external transaction monitors)
    // ================================================================
    input  logic                                        I_MST_BUS_CLEANY_COMPLETE,
    input  logic                                        I_SLV_BUS_CLEANY_COMPLETE,

    // ================================================================
    // DFT
    // ================================================================
    input  logic                                        TIEL_DFT_MODESCAN
);

    // ================================================================
    // Internal wires between bringup ctrl and core
    // ================================================================
    logic        w_int_fsm_in_active;
    logic        w_aou_activate_st_disabled;
    logic        w_aou_activate_st_enabled;
    logic        w_aou_req_linkreset;
    logic        w_int_activate_start;
    logic        w_int_deactivate_start;

    // Mux pl_state_sts based on active PHY width
    logic [3:0]  w_pl_state_sts_muxed;
    logic        w_pl_stallreq_muxed;

    assign w_pl_state_sts_muxed = I_PHY_TYPE ? I_FDI_PL_64B_STATE_STS
                                             : I_FDI_PL_32B_STATE_STS;

    assign w_pl_stallreq_muxed  = I_PHY_TYPE ? I_FDI_PL_64B_STALLREQ
                                             : I_FDI_PL_32B_STALLREQ;

    // ================================================================
    // FDI Bringup Controller
    // ================================================================
    AOU_FDI_BRINGUP_CTRL u_fdi_bringup_ctrl (
        .I_CLK                      ( I_CLK                         ),
        .I_RESETN                   ( I_RESETN                      ),

        .I_PL_STATE_STS             ( w_pl_state_sts_muxed          ),
        .I_PL_INBAND_PRES           ( I_PL_INBAND_PRES              ),
        .I_PL_CLK_REQ               ( I_PL_CLK_REQ                  ),
        .I_PL_WAKE_ACK              ( I_PL_WAKE_ACK                 ),
        .I_PL_RX_ACTIVE_REQ         ( I_PL_RX_ACTIVE_REQ            ),
        .I_PL_STALLREQ              ( w_pl_stallreq_muxed            ),

        .O_LP_STATE_REQ             ( O_LP_STATE_REQ                ),
        .O_LP_WAKE_REQ              ( O_LP_WAKE_REQ                 ),
        .O_LP_CLK_ACK               ( O_LP_CLK_ACK                  ),
        .O_LP_RX_ACTIVE_STS         ( O_LP_RX_ACTIVE_STS            ),

        .O_INT_FSM_IN_ACTIVE        ( w_int_fsm_in_active           ),
        .I_AOU_ACTIVATE_ST_DISABLED ( w_aou_activate_st_disabled    ),
        .I_AOU_ACTIVATE_ST_ENABLED  ( w_aou_activate_st_enabled     ),
        .I_AOU_REQ_LINKRESET        ( w_aou_req_linkreset           ),
        .I_INT_ACTIVATE_START       ( w_int_activate_start          ),
        .I_INT_DEACTIVATE_START     ( w_int_deactivate_start        ),

        .I_SW_ACTIVATE_START        ( I_SW_ACTIVATE_START           ),
        .I_SW_DEACTIVATE_START      ( I_SW_DEACTIVATE_START         ),
        .I_SW_RETRAIN_REQ           ( I_SW_RETRAIN_REQ              ),
        .I_SW_LINKERROR_INJECT      ( I_SW_LINKERROR_INJECT         ),

        .O_FSM_STATE                ( O_FDI_FSM_STATE               ),
        .O_LINK_UP                  ( O_FDI_LINK_UP                 )
    );

    // ================================================================
    // AOU Core Top (protocol engine + FIFOs + AXI interfaces)
    // ================================================================
    AOU_CORE_TOP #(
        .RP_COUNT                   ( RP_COUNT                      ),

        .RP0_RX_AW_FIFO_DEPTH      ( RP0_RX_AW_FIFO_DEPTH         ),
        .RP0_RX_AR_FIFO_DEPTH      ( RP0_RX_AR_FIFO_DEPTH         ),
        .RP0_RX_W_FIFO_DEPTH       ( RP0_RX_W_FIFO_DEPTH          ),
        .RP0_RX_R_FIFO_DEPTH       ( RP0_RX_R_FIFO_DEPTH          ),
        .RP0_RX_B_FIFO_DEPTH       ( RP0_RX_B_FIFO_DEPTH          ),

        .RP1_RX_AW_FIFO_DEPTH      ( RP1_RX_AW_FIFO_DEPTH         ),
        .RP1_RX_AR_FIFO_DEPTH      ( RP1_RX_AR_FIFO_DEPTH         ),
        .RP1_RX_W_FIFO_DEPTH       ( RP1_RX_W_FIFO_DEPTH          ),
        .RP1_RX_R_FIFO_DEPTH       ( RP1_RX_R_FIFO_DEPTH          ),
        .RP1_RX_B_FIFO_DEPTH       ( RP1_RX_B_FIFO_DEPTH          ),

        .RP2_RX_AW_FIFO_DEPTH      ( RP2_RX_AW_FIFO_DEPTH         ),
        .RP2_RX_AR_FIFO_DEPTH      ( RP2_RX_AR_FIFO_DEPTH         ),
        .RP2_RX_W_FIFO_DEPTH       ( RP2_RX_W_FIFO_DEPTH          ),
        .RP2_RX_R_FIFO_DEPTH       ( RP2_RX_R_FIFO_DEPTH          ),
        .RP2_RX_B_FIFO_DEPTH       ( RP2_RX_B_FIFO_DEPTH          ),

        .RP3_RX_AW_FIFO_DEPTH      ( RP3_RX_AW_FIFO_DEPTH         ),
        .RP3_RX_AR_FIFO_DEPTH      ( RP3_RX_AR_FIFO_DEPTH         ),
        .RP3_RX_W_FIFO_DEPTH       ( RP3_RX_W_FIFO_DEPTH          ),
        .RP3_RX_R_FIFO_DEPTH       ( RP3_RX_R_FIFO_DEPTH          ),
        .RP3_RX_B_FIFO_DEPTH       ( RP3_RX_B_FIFO_DEPTH          ),

        .RP0_AXI_DATA_WD           ( RP0_AXI_DATA_WD              ),
        .RP1_AXI_DATA_WD           ( RP1_AXI_DATA_WD              ),
        .RP2_AXI_DATA_WD           ( RP2_AXI_DATA_WD              ),
        .RP3_AXI_DATA_WD           ( RP3_AXI_DATA_WD              ),

        .AXI_PEER_DIE_MAX_DATA_WD  ( AXI_PEER_DIE_MAX_DATA_WD     ),

        .APB_ADDR_WD               ( APB_ADDR_WD                  ),
        .APB_DATA_WD               ( APB_DATA_WD                  ),

        .S_RD_MO_CNT               ( S_RD_MO_CNT                  ),
        .S_WR_MO_CNT               ( S_WR_MO_CNT                  ),

        .M_RD_MO_CNT               ( M_RD_MO_CNT                  ),
        .M_WR_MO_CNT               ( M_WR_MO_CNT                  )
    ) u_aou_core_top (
        .I_CLK                      ( I_CLK                         ),
        .I_RESETN                   ( I_RESETN                      ),

        .I_PCLK                     ( I_PCLK                        ),
        .I_PRESETN                  ( I_PRESETN                     ),

        .I_AOU_APB_SI0_PSEL         ( I_AOU_APB_SI0_PSEL            ),
        .I_AOU_APB_SI0_PENABLE      ( I_AOU_APB_SI0_PENABLE         ),
        .I_AOU_APB_SI0_PADDR        ( I_AOU_APB_SI0_PADDR           ),
        .I_AOU_APB_SI0_PWRITE       ( I_AOU_APB_SI0_PWRITE          ),
        .I_AOU_APB_SI0_PWDATA       ( I_AOU_APB_SI0_PWDATA          ),

        .O_AOU_APB_SI0_PRDATA       ( O_AOU_APB_SI0_PRDATA          ),
        .O_AOU_APB_SI0_PREADY       ( O_AOU_APB_SI0_PREADY          ),
        .O_AOU_APB_SI0_PSLVERR      ( O_AOU_APB_SI0_PSLVERR         ),

        .O_AOU_RX_AXI_M_ARID        ( O_AOU_RX_AXI_M_ARID           ),
        .O_AOU_RX_AXI_M_ARADDR      ( O_AOU_RX_AXI_M_ARADDR         ),
        .O_AOU_RX_AXI_M_ARLEN       ( O_AOU_RX_AXI_M_ARLEN          ),
        .O_AOU_RX_AXI_M_ARSIZE      ( O_AOU_RX_AXI_M_ARSIZE         ),
        .O_AOU_RX_AXI_M_ARBURST     ( O_AOU_RX_AXI_M_ARBURST        ),
        .O_AOU_RX_AXI_M_ARLOCK      ( O_AOU_RX_AXI_M_ARLOCK         ),
        .O_AOU_RX_AXI_M_ARCACHE     ( O_AOU_RX_AXI_M_ARCACHE        ),
        .O_AOU_RX_AXI_M_ARPROT      ( O_AOU_RX_AXI_M_ARPROT         ),
        .O_AOU_RX_AXI_M_ARQOS       ( O_AOU_RX_AXI_M_ARQOS          ),
        .O_AOU_RX_AXI_M_ARVALID     ( O_AOU_RX_AXI_M_ARVALID        ),
        .I_AOU_RX_AXI_M_ARREADY     ( I_AOU_RX_AXI_M_ARREADY        ),

        .I_AOU_TX_AXI_M_RID         ( I_AOU_TX_AXI_M_RID            ),
        .I_AOU_TX_AXI_M_RDATA       ( I_AOU_TX_AXI_M_RDATA          ),
        .I_AOU_TX_AXI_M_RRESP       ( I_AOU_TX_AXI_M_RRESP          ),
        .I_AOU_TX_AXI_M_RLAST       ( I_AOU_TX_AXI_M_RLAST          ),
        .I_AOU_TX_AXI_M_RVALID      ( I_AOU_TX_AXI_M_RVALID         ),
        .O_AOU_TX_AXI_M_RREADY      ( O_AOU_TX_AXI_M_RREADY         ),

        .O_AOU_RX_AXI_M_AWID        ( O_AOU_RX_AXI_M_AWID           ),
        .O_AOU_RX_AXI_M_AWADDR      ( O_AOU_RX_AXI_M_AWADDR         ),
        .O_AOU_RX_AXI_M_AWLEN       ( O_AOU_RX_AXI_M_AWLEN          ),
        .O_AOU_RX_AXI_M_AWSIZE      ( O_AOU_RX_AXI_M_AWSIZE         ),
        .O_AOU_RX_AXI_M_AWBURST     ( O_AOU_RX_AXI_M_AWBURST        ),
        .O_AOU_RX_AXI_M_AWLOCK      ( O_AOU_RX_AXI_M_AWLOCK         ),
        .O_AOU_RX_AXI_M_AWCACHE     ( O_AOU_RX_AXI_M_AWCACHE        ),
        .O_AOU_RX_AXI_M_AWPROT      ( O_AOU_RX_AXI_M_AWPROT         ),
        .O_AOU_RX_AXI_M_AWQOS       ( O_AOU_RX_AXI_M_AWQOS          ),
        .O_AOU_RX_AXI_M_AWVALID     ( O_AOU_RX_AXI_M_AWVALID        ),
        .I_AOU_RX_AXI_M_AWREADY     ( I_AOU_RX_AXI_M_AWREADY        ),

        .O_AOU_RX_AXI_M_WDATA       ( O_AOU_RX_AXI_M_WDATA          ),
        .O_AOU_RX_AXI_M_WSTRB       ( O_AOU_RX_AXI_M_WSTRB          ),
        .O_AOU_RX_AXI_M_WLAST       ( O_AOU_RX_AXI_M_WLAST          ),
        .O_AOU_RX_AXI_M_WVALID      ( O_AOU_RX_AXI_M_WVALID         ),
        .I_AOU_RX_AXI_M_WREADY      ( I_AOU_RX_AXI_M_WREADY         ),

        .I_AOU_TX_AXI_M_BID         ( I_AOU_TX_AXI_M_BID            ),
        .I_AOU_TX_AXI_M_BRESP       ( I_AOU_TX_AXI_M_BRESP          ),
        .I_AOU_TX_AXI_M_BVALID      ( I_AOU_TX_AXI_M_BVALID         ),
        .O_AOU_TX_AXI_M_BREADY      ( O_AOU_TX_AXI_M_BREADY         ),

        .I_AOU_TX_AXI_S_ARID        ( I_AOU_TX_AXI_S_ARID           ),
        .I_AOU_TX_AXI_S_ARADDR      ( I_AOU_TX_AXI_S_ARADDR         ),
        .I_AOU_TX_AXI_S_ARLEN       ( I_AOU_TX_AXI_S_ARLEN          ),
        .I_AOU_TX_AXI_S_ARSIZE      ( I_AOU_TX_AXI_S_ARSIZE         ),
        .I_AOU_TX_AXI_S_ARBURST     ( I_AOU_TX_AXI_S_ARBURST        ),
        .I_AOU_TX_AXI_S_ARLOCK      ( I_AOU_TX_AXI_S_ARLOCK         ),
        .I_AOU_TX_AXI_S_ARCACHE     ( I_AOU_TX_AXI_S_ARCACHE        ),
        .I_AOU_TX_AXI_S_ARPROT      ( I_AOU_TX_AXI_S_ARPROT         ),
        .I_AOU_TX_AXI_S_ARQOS       ( I_AOU_TX_AXI_S_ARQOS          ),
        .I_AOU_TX_AXI_S_ARVALID     ( I_AOU_TX_AXI_S_ARVALID        ),
        .O_AOU_TX_AXI_S_ARREADY     ( O_AOU_TX_AXI_S_ARREADY        ),

        .O_AOU_RX_AXI_S_RID         ( O_AOU_RX_AXI_S_RID            ),
        .O_AOU_RX_AXI_S_RDATA       ( O_AOU_RX_AXI_S_RDATA          ),
        .O_AOU_RX_AXI_S_RRESP       ( O_AOU_RX_AXI_S_RRESP          ),
        .O_AOU_RX_AXI_S_RLAST       ( O_AOU_RX_AXI_S_RLAST          ),
        .O_AOU_RX_AXI_S_RVALID      ( O_AOU_RX_AXI_S_RVALID         ),
        .I_AOU_RX_AXI_S_RREADY      ( I_AOU_RX_AXI_S_RREADY         ),

        .I_AOU_TX_AXI_S_AWID        ( I_AOU_TX_AXI_S_AWID           ),
        .I_AOU_TX_AXI_S_AWADDR      ( I_AOU_TX_AXI_S_AWADDR         ),
        .I_AOU_TX_AXI_S_AWLEN       ( I_AOU_TX_AXI_S_AWLEN          ),
        .I_AOU_TX_AXI_S_AWSIZE      ( I_AOU_TX_AXI_S_AWSIZE         ),
        .I_AOU_TX_AXI_S_AWBURST     ( I_AOU_TX_AXI_S_AWBURST        ),
        .I_AOU_TX_AXI_S_AWLOCK      ( I_AOU_TX_AXI_S_AWLOCK         ),
        .I_AOU_TX_AXI_S_AWCACHE     ( I_AOU_TX_AXI_S_AWCACHE        ),
        .I_AOU_TX_AXI_S_AWPROT      ( I_AOU_TX_AXI_S_AWPROT         ),
        .I_AOU_TX_AXI_S_AWQOS       ( I_AOU_TX_AXI_S_AWQOS          ),
        .I_AOU_TX_AXI_S_AWVALID     ( I_AOU_TX_AXI_S_AWVALID        ),
        .O_AOU_TX_AXI_S_AWREADY     ( O_AOU_TX_AXI_S_AWREADY        ),

        .I_AOU_TX_AXI_S_WDATA       ( I_AOU_TX_AXI_S_WDATA          ),
        .I_AOU_TX_AXI_S_WSTRB       ( I_AOU_TX_AXI_S_WSTRB          ),
        .I_AOU_TX_AXI_S_WLAST       ( I_AOU_TX_AXI_S_WLAST          ),
        .I_AOU_TX_AXI_S_WVALID      ( I_AOU_TX_AXI_S_WVALID         ),
        .O_AOU_TX_AXI_S_WREADY      ( O_AOU_TX_AXI_S_WREADY         ),

        .O_AOU_RX_AXI_S_BID         ( O_AOU_RX_AXI_S_BID            ),
        .O_AOU_RX_AXI_S_BRESP       ( O_AOU_RX_AXI_S_BRESP          ),
        .O_AOU_RX_AXI_S_BVALID      ( O_AOU_RX_AXI_S_BVALID         ),
        .I_AOU_RX_AXI_S_BREADY      ( I_AOU_RX_AXI_S_BREADY         ),

        .I_PHY_TYPE                  ( I_PHY_TYPE                    ),

        .I_FDI_PL_32B_VALID          ( I_FDI_PL_32B_VALID            ),
        .I_FDI_PL_32B_DATA           ( I_FDI_PL_32B_DATA             ),
        .I_FDI_PL_32B_FLIT_CANCEL    ( I_FDI_PL_32B_FLIT_CANCEL      ),

        .I_FDI_PL_64B_VALID          ( I_FDI_PL_64B_VALID            ),
        .I_FDI_PL_64B_DATA           ( I_FDI_PL_64B_DATA             ),
        .I_FDI_PL_64B_FLIT_CANCEL    ( I_FDI_PL_64B_FLIT_CANCEL      ),

        .I_FDI_PL_32B_TRDY           ( I_FDI_PL_32B_TRDY             ),
        .I_FDI_PL_32B_STALLREQ       ( I_FDI_PL_32B_STALLREQ         ),
        .I_FDI_PL_32B_STATE_STS      ( I_FDI_PL_32B_STATE_STS        ),
        .O_FDI_LP_32B_DATA           ( O_FDI_LP_32B_DATA             ),
        .O_FDI_LP_32B_VALID          ( O_FDI_LP_32B_VALID            ),
        .O_FDI_LP_32B_IRDY           ( O_FDI_LP_32B_IRDY             ),
        .O_FDI_LP_32B_STALLACK       ( O_FDI_LP_32B_STALLACK         ),

        .I_FDI_PL_64B_TRDY           ( I_FDI_PL_64B_TRDY             ),
        .I_FDI_PL_64B_STALLREQ       ( I_FDI_PL_64B_STALLREQ         ),
        .I_FDI_PL_64B_STATE_STS      ( I_FDI_PL_64B_STATE_STS        ),
        .O_FDI_LP_64B_DATA           ( O_FDI_LP_64B_DATA             ),
        .O_FDI_LP_64B_VALID          ( O_FDI_LP_64B_VALID            ),
        .O_FDI_LP_64B_IRDY           ( O_FDI_LP_64B_IRDY             ),
        .O_FDI_LP_64B_STALLACK       ( O_FDI_LP_64B_STALLACK         ),

        .INT_REQ_LINKRESET           ( INT_REQ_LINKRESET             ),
        .INT_SI0_ID_MISMATCH         ( INT_SI0_ID_MISMATCH           ),
        .INT_MI0_ID_MISMATCH         ( INT_MI0_ID_MISMATCH           ),
        .INT_EARLY_RESP_ERR          ( INT_EARLY_RESP_ERR            ),
        .INT_ACTIVATE_START          ( w_int_activate_start          ),
        .INT_DEACTIVATE_START        ( w_int_deactivate_start        ),

        .I_INT_FSM_IN_ACTIVE         ( w_int_fsm_in_active           ),
        .I_MST_BUS_CLEANY_COMPLETE   ( I_MST_BUS_CLEANY_COMPLETE     ),
        .I_SLV_BUS_CLEANY_COMPLETE   ( I_SLV_BUS_CLEANY_COMPLETE     ),
        .O_AOU_ACTIVATE_ST_DISABLED  ( w_aou_activate_st_disabled    ),
        .O_AOU_ACTIVATE_ST_ENABLED   ( w_aou_activate_st_enabled     ),
        .O_AOU_REQ_LINKRESET         ( w_aou_req_linkreset           ),

        .TIEL_DFT_MODESCAN           ( TIEL_DFT_MODESCAN             )
    );

    // ================================================================
    // Interrupt pass-through
    // ================================================================
    assign INT_ACTIVATE_START   = w_int_activate_start;
    assign INT_DEACTIVATE_START = w_int_deactivate_start;

endmodule

`default_nettype wire
