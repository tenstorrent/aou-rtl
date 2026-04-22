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
//  Module     : AOU_FIFO_RP
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_FIFO_RP
#(
    parameter   AXI_PEER_DIE_MAX_DATA_WD    = 1024,
    localparam  AXI_MAX_STRB_WD             = AXI_PEER_DIE_MAX_DATA_WD/8,
    parameter   AXI_ID_WD                   = 10,

    parameter   AW_AR_FIFO_WIDTH            = 10 + 64 + 8 + 3 + 1 + 4 + 3 + 4,
    parameter   B_FIFO_WIDTH                = AXI_ID_WD + 2,
    parameter   R_FIFO_EXT_DATA_WIDTH       = AXI_ID_WD + 2 + 1,
                
    parameter   AW_FIFO_DEPTH               = 44,
    parameter   AR_FIFO_DEPTH               = 44,
    parameter   W_FIFO_DEPTH                = 88,
    parameter   R_FIFO_DEPTH                = 88,
    parameter   B_FIFO_DEPTH                = 44,
    
    parameter   DEC_MULTI                   = 2,

    localparam  MAX_REQ_COUNT               = 4,
    localparam  MAX_WR_RESP_COUNT           = 12,
    localparam  DATA_DEC_CNT                = 4,

    parameter   AW_FWD_RS_EN                = 1,
    parameter   W_FWD_RS_EN                 = 1,
    parameter   B_FWD_RS_EN                 = 1,
    parameter   AR_FWD_RS_EN                = 1,
    parameter   R_FWD_RS_EN                 = 1
)
(
    input                                                       I_CLK,
    input                                                       I_RESETN,

    input       [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                             I_WR_REQ_FIFO_SVALID,
    input       [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]       I_WR_REQ_FIFO_SDATA,

    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                               I_WR_DATA_FIFO_SVALID,
    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0] I_WR_DATA_FIFO_SDATA,
    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                               I_WR_DATA_FIFO_WDATAF,
    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_MAX_STRB_WD -1:0]         I_WR_DATA_FIFO_STRB,

    input       [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                             I_RD_REQ_FIFO_SVALID,
    input       [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]       I_RD_REQ_FIFO_SDATA,

    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                               I_RD_DATA_FIFO_SVALID,
    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0] I_RD_DATA_FIFO_SDATA,
    input       [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][R_FIFO_EXT_DATA_WIDTH -1:0]   I_RD_DATA_FIFO_EXT_SDATA,


    input       [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0]                         I_WR_RESP_FIFO_SVALID,
    input       [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0][B_FIFO_WIDTH-1:0]       I_WR_RESP_FIFO_SDATA,

    input                                                       I_WR_REQ_FIFO_MREADY,
    output      [AW_AR_FIFO_WIDTH -1:0]                         O_WR_REQ_FIFO_MDATA,
    output                                                      O_WR_REQ_FIFO_MVALID,

    input                                                       I_WR_DATA_FIFO_MREADY,
    output      [AXI_PEER_DIE_MAX_DATA_WD-1:0]                  O_WR_DATA_FIFO_MDATA,
    output      [AXI_MAX_STRB_WD-1:0]                           O_WR_DATA_FIFO_MSTRB,
    output      [1:0]                                           O_WR_DATA_FIFO_MDLEN,
    output                                                      O_WR_DATA_FIFO_WDATAF,
    output                                                      O_WR_DATA_FIFO_MVALID,

   
    input                                                       I_RD_REQ_FIFO_MREADY,
    output      [AW_AR_FIFO_WIDTH -1:0]                         O_RD_REQ_FIFO_MDATA,
    output                                                      O_RD_REQ_FIFO_MVALID,
    
    input                                                       I_RD_DATA_FIFO_MREADY,
    output      [AXI_PEER_DIE_MAX_DATA_WD-1:0]                  O_RD_DATA_FIFO_MDATA,
    output      [R_FIFO_EXT_DATA_WIDTH -1:0]                    O_RD_DATA_FIFO_EXT_MDATA,
    output      [1:0]                                           O_RD_DATA_FIFO_MDLEN,
    output                                                      O_RD_DATA_FIFO_MVALID,

   
    input                                                       I_WR_RESP_FIFO_MREADY,
    output      [B_FIFO_WIDTH-1:0]                              O_WR_RESP_FIFO_MDATA,
    output                                                      O_WR_RESP_FIFO_MVALID
);

    logic w_aw_fwd_rs_ready;
    logic w_w_fwd_rs_ready;
    logic w_ar_fwd_rs_ready;
    logic w_r_fwd_rs_ready;
    logic w_b_fwd_rs_ready;

    logic [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                               w_wr_req_fifo_svalid;
    logic [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]         w_wr_req_fifo_sdata;

    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_wr_data_fifo_svalid;
    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]   w_wr_data_fifo_sdata;
    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_wr_data_fifo_wdataf;
    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_MAX_STRB_WD -1:0]           w_wr_data_fifo_strb;

    logic [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                               w_rd_req_fifo_svalid;
    logic [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]         w_rd_req_fifo_sdata;

    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_rd_data_fifo_svalid;
    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]   w_rd_data_fifo_sdata;
    logic [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][R_FIFO_EXT_DATA_WIDTH -1:0]     w_rd_data_fifo_ext_sdata;

    logic [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0]                           w_wr_resp_fifo_svalid;
    logic [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0][B_FIFO_WIDTH-1:0]         w_wr_resp_fifo_sdata; 

    generate
    if(AW_FWD_RS_EN) begin
    
    logic   [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                             w_wr_req_fwd_rs_mvalid;
    logic   [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]       w_wr_req_fwd_rs_mdata;              
    logic   w_aw_fwd_rs_valid;

        AOU_FWD_RS #(
            .DATA_WIDTH         (DEC_MULTI*MAX_REQ_COUNT*(AW_AR_FIFO_WIDTH+1))
        ) u_aou_rx_aw_fwd_rs
        (
            .I_CLK              ( I_CLK                     ),                                          
            .I_RESETN           ( I_RESETN                  ),                
        
            .I_SVALID           ( |I_WR_REQ_FIFO_SVALID     ),            
            .I_SDATA            ( {I_WR_REQ_FIFO_SVALID, I_WR_REQ_FIFO_SDATA}),
            .O_SREADY           (),
        
            .I_MREADY           ( w_aw_fwd_rs_ready         ), 
            .O_MDATA            ( {w_wr_req_fwd_rs_mvalid, w_wr_req_fwd_rs_mdata}),        
            .O_MVALID           ( w_aw_fwd_rs_valid         )                                 
        );
        assign w_wr_req_fifo_svalid = w_wr_req_fwd_rs_mvalid & {(DEC_MULTI*MAX_REQ_COUNT){w_aw_fwd_rs_valid}};
        assign w_wr_req_fifo_sdata  = w_wr_req_fwd_rs_mdata;

    end else begin
        assign w_wr_req_fifo_svalid = I_WR_REQ_FIFO_SVALID;
        assign w_wr_req_fifo_sdata  = I_WR_REQ_FIFO_SDATA;

    end
    endgenerate

    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( AW_AR_FIFO_WIDTH                  ),
        .FIFO_DEPTH                 ( AW_FIFO_DEPTH                     ),
        .ICH_CNT                    ( MAX_REQ_COUNT*DEC_MULTI           ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_aw_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( w_wr_req_fifo_svalid              ),
        .I_SDATA                    ( w_wr_req_fifo_sdata               ),
        .O_SREADY                   ( w_aw_fwd_rs_ready                 ),
        // read transaction
        .I_MREADY                   ( I_WR_REQ_FIFO_MREADY              ),
        .O_MDATA                    ( O_WR_REQ_FIFO_MDATA               ), 
        .O_MVALID                   ( O_WR_REQ_FIFO_MVALID              ),
    
        .O_S_EMPTY_CNT              (                                   ),
        .O_M_DATA_CNT               (                                   )

    );

    generate
    if (W_FWD_RS_EN) begin

    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_wr_data_fwd_rs_mvalid;
    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]   w_wr_data_fwd_rs_mdata;
    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_MAX_STRB_WD -1:0]           w_wr_data_fwd_rs_mstrb;
    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_wr_data_fwd_rs_mwdataf;
    
    logic   w_w_fwd_rs_valid;

        AOU_FWD_RS #(
            .DATA_WIDTH         (DEC_MULTI*DATA_DEC_CNT*(AXI_PEER_DIE_MAX_DATA_WD+AXI_MAX_STRB_WD+1+1))
        ) u_aou_rx_w_fwd_rs
        (
            .I_CLK              ( I_CLK                     ),                                          
            .I_RESETN           ( I_RESETN                  ),                
        
            .I_SVALID           ( |I_WR_DATA_FIFO_SVALID     ),            
            .I_SDATA            ( {I_WR_DATA_FIFO_SVALID, I_WR_DATA_FIFO_SDATA, I_WR_DATA_FIFO_STRB, I_WR_DATA_FIFO_WDATAF}),
            .O_SREADY           ( ),
        
            .I_MREADY           ( w_w_fwd_rs_ready         ), 
            .O_MDATA            ( {w_wr_data_fwd_rs_mvalid, w_wr_data_fwd_rs_mdata, w_wr_data_fwd_rs_mstrb, w_wr_data_fwd_rs_mwdataf}),        
            .O_MVALID           ( w_w_fwd_rs_valid         )                                 
    );
        assign w_wr_data_fifo_svalid           = w_wr_data_fwd_rs_mvalid & {(DEC_MULTI*DATA_DEC_CNT){w_w_fwd_rs_valid}};                   
        assign w_wr_data_fifo_sdata            = w_wr_data_fwd_rs_mdata;   
        assign w_wr_data_fifo_strb             = w_wr_data_fwd_rs_mstrb;   
        assign w_wr_data_fifo_wdataf           = w_wr_data_fwd_rs_mwdataf;

    end else begin
        assign w_wr_data_fifo_svalid           = I_WR_DATA_FIFO_SVALID          ;                   
        assign w_wr_data_fifo_sdata            = I_WR_DATA_FIFO_SDATA           ;   
        assign w_wr_data_fifo_strb             = I_WR_DATA_FIFO_STRB            ;   
        assign w_wr_data_fifo_wdataf           = I_WR_DATA_FIFO_WDATAF          ;
    end
    endgenerate
    
    AOU_DATA_W_FIFO_NS1M #(
        .AXI_PEER_DIE_MAX_DATA_WD   ( AXI_PEER_DIE_MAX_DATA_WD          ),
        .FIFO_DEPTH                 ( W_FIFO_DEPTH                      ),
        .ICH_CNT                    ( DATA_DEC_CNT*DEC_MULTI            ),
        .ALWAYS_READY               ( 1                                 ),
        .DEC_MULTI                  ( DEC_MULTI                         )
    ) u_aou_rx_w_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
    
        // write transaction
        .I_SVALID                   ( w_wr_data_fifo_svalid             ),
        .I_SDATA                    ( w_wr_data_fifo_sdata              ),
        .I_SDATA_STRB               ( w_wr_data_fifo_strb               ),
        .I_SDATA_WDATAF             ( w_wr_data_fifo_wdataf             ),
        .O_SREADY                   ( w_w_fwd_rs_ready                  ),
        
        // read transaction
        .I_MREADY                   ( I_WR_DATA_FIFO_MREADY             ),
        .O_MDATA                    ( O_WR_DATA_FIFO_MDATA              ),
        .O_MDATA_STRB               ( O_WR_DATA_FIFO_MSTRB              ),
        .O_MDLEN                    ( O_WR_DATA_FIFO_MDLEN              ),
        .O_MDATA_WDATAF             ( O_WR_DATA_FIFO_WDATAF             ),
        .O_MVALID                   ( O_WR_DATA_FIFO_MVALID             )
    );
    
    generate
    if(AR_FWD_RS_EN) begin
    
    logic   [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0]                           w_rd_req_fwd_rs_mvalid;
    logic   [DEC_MULTI-1:0][MAX_REQ_COUNT -1:0][AW_AR_FIFO_WIDTH-1:0]     w_rd_req_fwd_rs_mdata;              
    logic   w_ar_fwd_rs_valid;

        AOU_FWD_RS #(
            .DATA_WIDTH         (DEC_MULTI*MAX_REQ_COUNT*(AW_AR_FIFO_WIDTH+1))
        ) u_aou_rx_ar_fwd_rs
        (
            .I_CLK              ( I_CLK                     ),                                          
            .I_RESETN           ( I_RESETN                  ),                
        
            .I_SVALID           ( |I_RD_REQ_FIFO_SVALID     ),            
            .I_SDATA            ( {I_RD_REQ_FIFO_SVALID, I_RD_REQ_FIFO_SDATA}),
            .O_SREADY           (),
        
            .I_MREADY           ( w_ar_fwd_rs_ready         ), 
            .O_MDATA            ( {w_rd_req_fwd_rs_mvalid, w_rd_req_fwd_rs_mdata}),        
            .O_MVALID           ( w_ar_fwd_rs_valid         )                                 
        );
        assign w_rd_req_fifo_svalid = w_rd_req_fwd_rs_mvalid & {(DEC_MULTI*MAX_REQ_COUNT){w_ar_fwd_rs_valid}};
        assign w_rd_req_fifo_sdata  = w_rd_req_fwd_rs_mdata;

    end else begin
        assign w_rd_req_fifo_svalid = I_RD_REQ_FIFO_SVALID;
        assign w_rd_req_fifo_sdata  = I_RD_REQ_FIFO_SDATA;

    end
    endgenerate

    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( AW_AR_FIFO_WIDTH                  ),                   
        .FIFO_DEPTH                 ( AR_FIFO_DEPTH                     ),
        .ICH_CNT                    ( MAX_REQ_COUNT*DEC_MULTI           ),
        .ALWAYS_READY               ( 1                                 )
    ) u_aou_rx_ar_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( w_rd_req_fifo_svalid              ),
        .I_SDATA                    ( w_rd_req_fifo_sdata               ),
        .O_SREADY                   ( w_ar_fwd_rs_ready                 ),
        // read transaction
        .I_MREADY                   ( I_RD_REQ_FIFO_MREADY              ),
        .O_MDATA                    ( O_RD_REQ_FIFO_MDATA               ),
        .O_MVALID                   ( O_RD_REQ_FIFO_MVALID              ),

        .O_S_EMPTY_CNT              (                                   ),
        .O_M_DATA_CNT               (                                   )

    );

    generate
    if (R_FWD_RS_EN) begin

    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0]                                 w_rd_data_fwd_rs_mvalid;
    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]   w_rd_data_fwd_rs_mdata;
    logic   [DEC_MULTI-1:0][DATA_DEC_CNT-1:0][R_FIFO_EXT_DATA_WIDTH -1:0]     w_rd_data_fwd_rs_ext_mdata;
    logic   w_r_fwd_rs_valid;

        AOU_FWD_RS #(
            .DATA_WIDTH         (DEC_MULTI*DATA_DEC_CNT*(AXI_PEER_DIE_MAX_DATA_WD+R_FIFO_EXT_DATA_WIDTH+1))
        ) u_aou_rx_r_fwd_rs
        (
            .I_CLK              ( I_CLK                     ),                                          
            .I_RESETN           ( I_RESETN                  ),                
        
            .I_SVALID           ( |I_RD_DATA_FIFO_SVALID     ),            
            .I_SDATA            ( {I_RD_DATA_FIFO_SVALID, I_RD_DATA_FIFO_SDATA, I_RD_DATA_FIFO_EXT_SDATA}),
            .O_SREADY           ( ),
        
            .I_MREADY           ( w_r_fwd_rs_ready         ), 
            .O_MDATA            ( {w_rd_data_fwd_rs_mvalid, w_rd_data_fwd_rs_mdata, w_rd_data_fwd_rs_ext_mdata}),        
            .O_MVALID           ( w_r_fwd_rs_valid         )                                 
    );
        assign w_rd_data_fifo_svalid           = w_rd_data_fwd_rs_mvalid & {(DEC_MULTI*DATA_DEC_CNT){w_r_fwd_rs_valid}};                   
        assign w_rd_data_fifo_sdata            = w_rd_data_fwd_rs_mdata;   
        assign w_rd_data_fifo_ext_sdata        = w_rd_data_fwd_rs_ext_mdata;   

    end else begin
        assign w_rd_data_fifo_svalid           = I_RD_DATA_FIFO_SVALID          ;                   
        assign w_rd_data_fifo_sdata            = I_RD_DATA_FIFO_SDATA           ;   
        assign w_rd_data_fifo_ext_sdata        = I_RD_DATA_FIFO_EXT_SDATA       ;   
    end
    endgenerate

    AOU_DATA_R_FIFO_NS1M #(
        .AXI_PEER_DIE_MAX_DATA_WD   ( AXI_PEER_DIE_MAX_DATA_WD          ),
        .EXT_FIFO_WD                ( AXI_ID_WD + 2 + 1                 ), 
        .FIFO_DEPTH                 ( R_FIFO_DEPTH                      ),
        .ICH_CNT                    ( DATA_DEC_CNT*DEC_MULTI            ),
        .ALWAYS_READY               ( 1                                 ),
        .DEC_MULTI                  ( DEC_MULTI                         )
    ) u_aou_rx_r_fifo_rp0
    (
        .I_CLK                      ( I_CLK                             ),
        .I_RESETN                   ( I_RESETN                          ),
        // write transaction
        .I_SVALID                   ( w_rd_data_fifo_svalid             ),
        .I_SDATA                    ( w_rd_data_fifo_sdata              ),
        .I_EXT_SDATA                ( w_rd_data_fifo_ext_sdata          ),
        .O_SREADY                   ( w_r_fwd_rs_ready                  ),
        // read transaction 
        .I_MREADY                   ( I_RD_DATA_FIFO_MREADY             ),
        .O_MDATA                    ( O_RD_DATA_FIFO_MDATA              ), 
        .O_EXT_MDATA                ( O_RD_DATA_FIFO_EXT_MDATA          ),
        .O_MDLEN                    ( O_RD_DATA_FIFO_MDLEN              ),
        .O_MVALID                   ( O_RD_DATA_FIFO_MVALID             )
    );
 
    generate
    if(B_FWD_RS_EN) begin

        logic [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0] w_wr_resp_fwd_rs_mvalid;
        logic w_b_fwd_rs_valid;
        logic [DEC_MULTI-1:0][MAX_WR_RESP_COUNT -1:0][B_FIFO_WIDTH-1:0] w_wr_resp_fwd_rs_mdata;

    AOU_FWD_RS #(
            .DATA_WIDTH         ( DEC_MULTI*MAX_WR_RESP_COUNT*(B_FIFO_WIDTH+1) )
    ) u_aou_rx_b_fwd_rs
    (
        .I_CLK              ( I_CLK                     ),                                          
        .I_RESETN           ( I_RESETN                  ),                
    
        .I_SVALID           ( |I_WR_RESP_FIFO_SVALID    ),            
        .I_SDATA            ( {I_WR_RESP_FIFO_SVALID, I_WR_RESP_FIFO_SDATA}),
        .O_SREADY           (                           ),
    
        .I_MREADY           ( w_b_fwd_rs_ready          ), 
        .O_MDATA            ( {w_wr_resp_fwd_rs_mvalid, w_wr_resp_fwd_rs_mdata}),        
        .O_MVALID           ( w_b_fwd_rs_valid          )                                
    );
        assign w_wr_resp_fifo_svalid = w_wr_resp_fwd_rs_mvalid & {(DEC_MULTI*MAX_WR_RESP_COUNT){w_b_fwd_rs_valid}};
        assign w_wr_resp_fifo_sdata  = w_wr_resp_fwd_rs_mdata;

    end else begin
        assign w_wr_resp_fifo_svalid  = I_WR_RESP_FIFO_SVALID;
        assign w_wr_resp_fifo_sdata   = I_WR_RESP_FIFO_SDATA;
    end
    endgenerate

    AOU_SYNC_FIFO_NS1M #(
        .FIFO_WIDTH                 ( B_FIFO_WIDTH                  ),
        .FIFO_DEPTH                 ( B_FIFO_DEPTH                  ),
        .ICH_CNT                    ( MAX_WR_RESP_COUNT*DEC_MULTI   ),
        .ALWAYS_READY               ( 1                             )
    ) u_aou_rx_b_fifo_rp0
    (
        .I_CLK                      ( I_CLK                         ),
        .I_RESETN                   ( I_RESETN                      ),
        // write transaction
        .I_SVALID                   ( w_wr_resp_fifo_svalid         ),
        .I_SDATA                    ( w_wr_resp_fifo_sdata          ),
        .O_SREADY                   ( w_b_fwd_rs_ready              ),
        // read transaction
        .I_MREADY                   ( I_WR_RESP_FIFO_MREADY         ),
        .O_MDATA                    ( O_WR_RESP_FIFO_MDATA          ), 
        .O_MVALID                   ( O_WR_RESP_FIFO_MVALID         ),
    
        .O_S_EMPTY_CNT              (                               ),
        .O_M_DATA_CNT               (                               )
    );

endmodule  
