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
//  Module     : AOU_AGGREGATOR_INFO
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_AGGREGATOR_INFO #(
    parameter  AXI_DATA_WD       = 512,
    parameter  AXI_ID_WD         = 4'd4,
    parameter  AXI_LEN_WD        = 4'd4,
    parameter  RD_MO_CNT         = 10'd128,

    localparam AXI_ADDR_WD       = $clog2(AXI_DATA_WD/8),
    localparam RD_MO_IDX_WD      = $clog2(RD_MO_CNT),
    localparam RD_MO_CNT_WD      = $clog2(RD_MO_CNT+1)
)
(
    input  logic                                I_CLK,
    input  logic                                I_RESETN,
                                                
    input  logic  [AXI_ID_WD-1:0]               I_AXI_ArId, 
    input  logic  [AXI_LEN_WD-1:0]              I_AXI_ArLen,

    input  logic  [AXI_ADDR_WD-1:0]             I_AXI_ArAddr_align,
    input  logic  [2:0]                         I_AXI_ArSize,
    input  logic  [AXI_LEN_WD-1:0]              I_ORIGINAL_ArLen,
    input  logic  [2:0]                         I_ORIGINAL_ArSize,  

    input  logic                                I_AXI_ArValid,
    input  logic                                I_AXI_ArReady,
                                                
    input  logic  [AXI_ID_WD-1:0]               I_AXI_RId,
    input  logic                                I_AXI_RLast,
    input  logic                                I_AXI_RValid,
    input  logic                                I_AXI_RReady,
    output logic                                O_AR_Slot_Available_Flag,
                                                
    output logic                                O_ReorderBuf_MValid,
    output logic  [AXI_ID_WD + AXI_ADDR_WD + 3 + AXI_LEN_WD + 3 + AXI_LEN_WD + 1 -1:0]         O_ReorderBuf_MData, 

    output logic                                O_DEST_TABLE_ID_ERR
);

//Signal to preprecessing. With moore type FSM
wire                       w_pre_s_rlast_send  ;
wire [AXI_LEN_WD-1:0]      w_pre_cur_burst_len ;

wire                       w_next_s_rlast_send  ;
wire [AXI_LEN_WD-1:0]      w_next_burst_len ;

typedef struct  packed {
    logic [AXI_ID_WD-1:0]           id;
    logic [AXI_LEN_WD-1:0]          burst_len;

    logic [AXI_ADDR_WD:0]           araddr;
    logic [2:0]                     arsize;
    logic [AXI_LEN_WD-1:0]          original_len;
    logic [2:0]                     original_size;

    //preprocessing for timing enhancement
    logic                           r_s_rlast_send  ;
    logic [AXI_LEN_WD-1:0]          r_burst_len ;

    logic                           pending;
    logic [RD_MO_IDX_WD-1:0]        rid_numbering;
} st_artable;

st_artable [RD_MO_CNT-1:0] artable;    

logic [RD_MO_CNT-1:0]              w_artable_r_onehot;
logic [RD_MO_CNT-1:0]              w_artable_clean_onehot;
logic [RD_MO_IDX_WD-1:0]           w_artable_wptr_cur, w_artable_rptr_cur;

logic [RD_MO_CNT_WD-1:0]           r_arcnt, w_arcnt_next;

logic [RD_MO_CNT-1:0]              w_rid_numbering_onehot;
logic [RD_MO_IDX_WD-1:0]           w_rid_numbering;

assign O_AR_Slot_Available_Flag = (r_arcnt != RD_MO_CNT);

always_ff @ (posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        r_arcnt <= 'd0;
    end else if ((I_AXI_ArValid & I_AXI_ArReady) | (I_AXI_RLast & I_AXI_RValid & I_AXI_RReady & ~(|artable[w_artable_rptr_cur].burst_len)))begin
        r_arcnt <= w_arcnt_next;
    end
end

always_comb begin
    w_arcnt_next = r_arcnt;
    if (I_AXI_ArValid & I_AXI_ArReady) begin
        w_arcnt_next = w_arcnt_next + 'd1;
    end 

    if (I_AXI_RLast & I_AXI_RValid & I_AXI_RReady & ~(|artable[w_artable_rptr_cur].burst_len)) begin
        w_arcnt_next = w_arcnt_next - 'd1;
    end
end

always_comb begin
    for (int i=0; i<RD_MO_CNT; i++)
        w_rid_numbering_onehot[i] = artable[i].pending && (artable[i].id == I_AXI_ArId);

    w_rid_numbering = $countones(w_rid_numbering_onehot);
end
//------------------------------------------------------------------
// Update artable
//------------------------------------------------------------------
always_ff @(posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        for (integer i = 0; i < RD_MO_CNT  ; i = i + 1 ) begin
            artable[i].id              <= {AXI_ID_WD{1'b0}};
            artable[i].burst_len       <= '0;

            artable[i].araddr          <= '0;
            artable[i].arsize          <= '0;
            artable[i].original_len    <= '0;
            artable[i].original_size   <= '0;

            artable[i].r_s_rlast_send  <= '0;
            artable[i].r_burst_len     <= '0;

            artable[i].pending         <= '0;
            artable[i].rid_numbering   <= '0;

        end
    end
    else begin
        if (I_AXI_ArReady & I_AXI_ArValid) begin
            artable[w_artable_wptr_cur].id            <= I_AXI_ArId;
            artable[w_artable_wptr_cur].burst_len     <= I_AXI_ArLen;

            artable[w_artable_wptr_cur].araddr        <= {1'b0, I_AXI_ArAddr_align};
            artable[w_artable_wptr_cur].arsize        <= I_AXI_ArSize;
            artable[w_artable_wptr_cur].original_len  <= I_ORIGINAL_ArLen;
            artable[w_artable_wptr_cur].original_size <= I_ORIGINAL_ArSize;

            artable[w_artable_wptr_cur].r_s_rlast_send<= w_pre_s_rlast_send ;
            artable[w_artable_wptr_cur].r_burst_len   <= w_pre_cur_burst_len;

            artable[w_artable_wptr_cur].pending         <= 1'b1;

            if(I_AXI_RValid & I_AXI_RReady & (I_AXI_ArId == I_AXI_RId) & ~(|artable[w_artable_rptr_cur].burst_len)) begin
                artable[w_artable_wptr_cur].rid_numbering         <= w_rid_numbering - 1;
            end else begin
                artable[w_artable_wptr_cur].rid_numbering         <= w_rid_numbering;
            end
        end

        if (I_AXI_RValid & I_AXI_RReady) begin
            if (~(|artable[w_artable_rptr_cur].burst_len)) begin
                artable[w_artable_rptr_cur].pending      <= 1'b0;
            end
            artable[w_artable_rptr_cur].burst_len        <= artable[w_artable_rptr_cur].burst_len - 'b1;
            artable[w_artable_rptr_cur].r_s_rlast_send   <= w_next_s_rlast_send ;
            artable[w_artable_rptr_cur].r_burst_len      <= w_next_burst_len;
        end

        for (integer i=0; i<RD_MO_CNT; i=i+1) begin
            if (I_AXI_RValid & I_AXI_RReady & ~(|artable[w_artable_rptr_cur].burst_len) & artable[i].pending & (artable[i].id == I_AXI_RId) & (artable[i].rid_numbering != 'd0)) begin
                artable[i].rid_numbering <= artable[i].rid_numbering -'d1;
            end
        end
    end
end

assign O_DEST_TABLE_ID_ERR = I_AXI_RValid & I_AXI_RReady & ~(|w_artable_r_onehot);

//------------------------------------------------------------------
//Pre processing
//------------------------------------------------------------------
reg  [AXI_ADDR_WD + 7 : 0] w_pre_arlen_bytes   ; 

wire [AXI_ADDR_WD + 7 : 0] w_pre_begin_addr_off;
wire [AXI_ADDR_WD + 7 : 0] w_pre_end_addr_off  ;
wire [AXI_ADDR_WD + 7 : 0] w_pre_end_begin_addr_diff;

reg  [AXI_LEN_WD:0]        w_pre_arlen_p_1     ;

assign w_pre_end_begin_addr_diff = (w_pre_end_addr_off[AXI_ADDR_WD -1 : 0] == 'd0) ? ({1'b1,{AXI_ADDR_WD{1'b0}}} - w_pre_begin_addr_off) :
                                                                              (w_pre_end_addr_off - w_pre_begin_addr_off) ;
generate
if(AXI_DATA_WD == 1024) begin
    always @(*) begin
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_bytes =  (I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            3'd5:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 5'd0}; 
            3'd6:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 6'd0}; 
            default: w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 7'd0}; 
        endcase
    
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_p_1 = w_pre_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_pre_arlen_p_1 = {1'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_pre_arlen_p_1 = {2'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_pre_arlen_p_1 = {3'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_pre_arlen_p_1 = {4'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            3'd5:    w_pre_arlen_p_1 = {5'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
            3'd6:    w_pre_arlen_p_1 = {6'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:6]}; 
            default: w_pre_arlen_p_1 = {7'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:7]}; 
        endcase
    
    end

end else if (AXI_DATA_WD == 512) begin
    always @(*) begin
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_bytes =  (I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            3'd5:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 5'd0}; 
            default: w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 6'd0}; 
        endcase
    
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_p_1 = w_pre_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_pre_arlen_p_1 = {1'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_pre_arlen_p_1 = {2'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_pre_arlen_p_1 = {3'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_pre_arlen_p_1 = {4'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            3'd5:    w_pre_arlen_p_1 = {5'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
            default: w_pre_arlen_p_1 = {6'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:6]}; 
        endcase
    
    end

end else if (AXI_DATA_WD == 256) begin
    always @(*) begin
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_bytes =  (I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            default: w_pre_arlen_bytes = {(I_ORIGINAL_ArLen[AXI_LEN_WD-1:0] + 1), 5'd0}; 
        endcase
    
        case (I_ORIGINAL_ArSize)
            3'd0:    w_pre_arlen_p_1 = w_pre_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_pre_arlen_p_1 = {1'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_pre_arlen_p_1 = {2'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_pre_arlen_p_1 = {3'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_pre_arlen_p_1 = {4'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            default: w_pre_arlen_p_1 = {5'b0, w_pre_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
        endcase
    
    end

end
endgenerate

assign w_pre_s_rlast_send   = (I_AXI_ArLen == 0);
assign w_pre_begin_addr_off = {1'b0, I_AXI_ArAddr_align[AXI_ADDR_WD-1:0]};
assign w_pre_end_addr_off   = (I_AXI_ArLen == 0) ?
                                (I_AXI_ArAddr_align[AXI_ADDR_WD-1:0] + w_pre_arlen_bytes):
                                {1'b1,{AXI_ADDR_WD{1'b0}}};


assign w_pre_cur_burst_len  = w_pre_arlen_p_1 - 1;



//------------------------------------------------------------------
//Main processing
//------------------------------------------------------------------
reg  [AXI_ADDR_WD + 7 : 0] w_arlen_bytes   ; 

wire [AXI_ADDR_WD + 7 : 0] w_begin_addr_off;
wire [AXI_ADDR_WD + 7 : 0] w_end_addr_off  ;
wire [AXI_ADDR_WD + 7 : 0] w_end_begin_addr_diff;

reg  [AXI_LEN_WD:0]        w_arlen_p_1     ;

assign w_end_begin_addr_diff = (w_end_addr_off[AXI_ADDR_WD -1 : 0] == 'd0) ? ({1'b1,{AXI_ADDR_WD{1'b0}}} - w_begin_addr_off) :
                                                                              (w_end_addr_off[AXI_ADDR_WD -1 : 0]- w_begin_addr_off) ;
generate
if(AXI_DATA_WD == 1024) begin
    always @(*) begin
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_bytes =  (artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            3'd5:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 5'd0}; 
            3'd6:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 6'd0}; 
            default: w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 7'd0}; 
        endcase
    
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_p_1 = w_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_arlen_p_1 = {1'b0, w_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_arlen_p_1 = {2'b0, w_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_arlen_p_1 = {3'b0, w_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_arlen_p_1 = {4'b0, w_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            3'd5:    w_arlen_p_1 = {5'b0, w_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
            3'd6:    w_arlen_p_1 = {6'b0, w_end_begin_addr_diff[AXI_ADDR_WD:6]}; 
            default: w_arlen_p_1 = {7'b0, w_end_begin_addr_diff[AXI_ADDR_WD:7]}; 
        endcase
    
    end

end else if (AXI_DATA_WD == 512) begin
    always @(*) begin
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_bytes =  (artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            3'd5:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 5'd0}; 
            default: w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 6'd0}; 
        endcase
    
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_p_1 = w_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_arlen_p_1 = {1'b0, w_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_arlen_p_1 = {2'b0, w_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_arlen_p_1 = {3'b0, w_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_arlen_p_1 = {4'b0, w_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            3'd5:    w_arlen_p_1 = {5'b0, w_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
            default: w_arlen_p_1 = {6'b0, w_end_begin_addr_diff[AXI_ADDR_WD:6]}; 
        endcase
    
    end

end else if (AXI_DATA_WD == 256) begin
    always @(*) begin
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_bytes =  (artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1); 
            3'd1:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 1'd0}; 
            3'd2:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 2'd0}; 
            3'd3:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 3'd0}; 
            3'd4:    w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 4'd0}; 
            default: w_arlen_bytes = {(artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0] + 1), 5'd0}; 
        endcase
    
        case (artable[w_artable_rptr_cur].original_size)
            3'd0:    w_arlen_p_1 = w_end_begin_addr_diff[AXI_ADDR_WD:0]; 
            3'd1:    w_arlen_p_1 = {1'b0, w_end_begin_addr_diff[AXI_ADDR_WD:1]}; 
            3'd2:    w_arlen_p_1 = {2'b0, w_end_begin_addr_diff[AXI_ADDR_WD:2]}; 
            3'd3:    w_arlen_p_1 = {3'b0, w_end_begin_addr_diff[AXI_ADDR_WD:3]}; 
            3'd4:    w_arlen_p_1 = {4'b0, w_end_begin_addr_diff[AXI_ADDR_WD:4]}; 
            default: w_arlen_p_1 = {5'b0, w_end_begin_addr_diff[AXI_ADDR_WD:5]}; 
        endcase
    
    end

end
endgenerate

assign w_next_s_rlast_send = (artable[w_artable_rptr_cur].burst_len == {{(AXI_LEN_WD-1){1'b0}}, 1'b1});
assign w_begin_addr_off = 'd0;
assign w_end_addr_off   = (artable[w_artable_rptr_cur].burst_len == {{(AXI_LEN_WD-1){1'b0}}, 1'b1}) ? 
                            (artable[w_artable_rptr_cur].araddr[AXI_ADDR_WD-1:0] + w_arlen_bytes) : 
                            {1'b1,{AXI_ADDR_WD{1'b0}}};

assign w_next_burst_len  = w_arlen_p_1 - 1;

always_comb begin
    w_artable_wptr_cur = 'd0;
    for (integer i=0; i<RD_MO_CNT; i=i+1) begin
        if (!artable[RD_MO_CNT-1 - i].pending) begin  // search from back
            w_artable_wptr_cur = RD_MO_CNT-1 - i;
        end
    end
end

always_comb begin
    w_artable_rptr_cur = 'd0;
    for (integer i=0; i<RD_MO_CNT; i=i+1) begin
        w_artable_r_onehot[i] = artable[i].pending & (artable[i].id == I_AXI_RId) & (artable[i].rid_numbering == 'd0);
    end

    for (integer i=0; i<RD_MO_CNT; i=i+1) begin
        if (w_artable_r_onehot[i]) begin
            w_artable_rptr_cur = i;
        end
    end
end
//------------------------------------------------------------------
assign O_ReorderBuf_MData  = {artable[w_artable_rptr_cur].id[AXI_ID_WD-1:0], 
                              artable[w_artable_rptr_cur].araddr[AXI_ADDR_WD-1:0], 
                              artable[w_artable_rptr_cur].arsize[2:0], 
                              artable[w_artable_rptr_cur].original_len[AXI_LEN_WD-1:0], 
                              artable[w_artable_rptr_cur].original_size[2:0],
                              artable[w_artable_rptr_cur].r_burst_len,
                              artable[w_artable_rptr_cur].r_s_rlast_send};
assign O_ReorderBuf_MValid   = I_AXI_RValid & I_AXI_RReady & I_AXI_RLast & (artable[w_artable_rptr_cur].burst_len == {{(AXI_LEN_WD-1){1'b0}}, 1'b1});

`ifdef ASSERTION_ON
// synopsys translate_off

aou_aggregator_table_id_err_assertion:
    assert
        property (
            @(posedge I_CLK) disable iff (!I_RESETN)
            !O_DEST_TABLE_ID_ERR 
        )
        else begin
            $error("\n[%t] AOU_AGGREGATOR_INFO: O_DEST_TABLE_ID_ERR asserted!", $time);
            $finish;
        end

// synopsys translate_on
`endif
endmodule
