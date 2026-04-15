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
//  Module     : AOU_EARLY_TABLE
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_EARLY_TABLE #(
    parameter  AXI_ID_WD         = 4'd4,

    parameter  WR_MO_CNT         = 128,
    localparam WR_MO_IDX_WD      = $clog2(WR_MO_CNT),
    localparam WR_MO_CNT_WD      = $clog2(WR_MO_CNT+1)
)
(
    input  logic                                I_CLK,
    input  logic                                I_RESETN,
 
    input  logic  [AXI_ID_WD-1:0]               I_AXI_AwId,
    input  logic                                I_AXI_Bufferable, 
    input  logic                                I_AXI_AwValid,
    input  logic                                I_AXI_AwReady,
                                                
    input  logic  [AXI_ID_WD-1:0]               I_AXI_M_BId,
    input  logic                                I_AXI_M_BValid,
    input  logic                                I_AXI_M_BReady,
    output logic                                O_AW_Slot_Available_Flag,
                                                
    input  logic                                I_AXI_S_BReady,
    output logic                                O_EarlyResponse_Consume,
    output logic                                O_EarlyResponse_Valid,
    output logic  [AXI_ID_WD-1:0]               O_EarlyResponse_Id,

    output logic                                O_DEST_TABLE_ID_ERR
);

typedef struct  packed {
    logic [AXI_ID_WD-1:0]           id;
    logic                           bufferable;
    logic                           pending;
    logic [WR_MO_IDX_WD-1:0]        wid_numbering;                          

    logic                           out;
    logic                           early_go;
    logic [WR_MO_IDX_WD-1:0]        same_id_tr_cnt;
} st_awtable;


st_awtable [WR_MO_CNT-1:0]         awtable;


logic [WR_MO_CNT-1:0]               w_awtable_r_onehot;     // not one hot (multi-hot), but work same as one hot
logic [WR_MO_IDX_WD-1:0]            w_awtable_wptr_cur, w_awtable_rptr_cur;

logic [WR_MO_CNT_WD-1:0]            r_awcnt, w_awcnt_next;

logic [WR_MO_CNT-1:0]               w_wid_numbering_onehot;
logic [WR_MO_IDX_WD-1:0]            w_wid_numbering;


logic [WR_MO_IDX_WD  -1 :0]         w_early_resp_idx; 
logic [WR_MO_CNT-1:0]               w_wr_same_id_match_flag;
logic                               w_early_resp_flag;
logic [WR_MO_IDX_WD-1:0]            w_same_id_tr_cnt;

assign O_AW_Slot_Available_Flag = (r_awcnt != WR_MO_CNT);

always_ff @ (posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        r_awcnt <= 'd0;
    end else if ((I_AXI_AwValid & I_AXI_AwReady) | (I_AXI_M_BValid & I_AXI_M_BReady))begin
        r_awcnt <= w_awcnt_next;
    end
end


always_comb begin
    w_awcnt_next = r_awcnt;

    if (I_AXI_AwValid & I_AXI_AwReady) begin
        w_awcnt_next = w_awcnt_next + 'd1;
    end

    if (I_AXI_M_BValid & I_AXI_M_BReady) begin
        w_awcnt_next = w_awcnt_next - 'd1;
    end
end

/////////////////////////////////// WID numbering ///////////////////////////////////////////////
always_comb begin
    for (int i=0; i<WR_MO_CNT; i++)
        w_wid_numbering_onehot[i] = awtable[i].pending && (awtable[i].id == I_AXI_AwId);

    w_wid_numbering = $countones(w_wid_numbering_onehot);
end
//------------------------------------------------------------------
// Update awtable
//------------------------------------------------------------------
always_ff @(posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        for (integer i = 0; i < WR_MO_CNT  ; i = i + 1 ) begin
            awtable[i].id               <= {AXI_ID_WD{1'b0}};
            awtable[i].bufferable       <= 1'b0;
            awtable[i].out              <= 1'b0;
            awtable[i].early_go         <= 1'b0;
            awtable[i].same_id_tr_cnt   <= {WR_MO_IDX_WD{1'b0}};
            awtable[i].pending          <= 1'b0;
            awtable[i].wid_numbering    <= {WR_MO_IDX_WD{1'b0}};
        end
    end
    else begin
        if (I_AXI_AwReady & I_AXI_AwValid) begin
            awtable[w_awtable_wptr_cur].id            <= I_AXI_AwId;
            awtable[w_awtable_wptr_cur].bufferable    <= I_AXI_Bufferable;
            awtable[w_awtable_wptr_cur].out           <= 1'b0;
            awtable[w_awtable_wptr_cur].pending       <= 1'b1;
            if (O_EarlyResponse_Valid & I_AXI_S_BReady & (O_EarlyResponse_Id == I_AXI_AwId)) begin
                awtable[w_awtable_wptr_cur].same_id_tr_cnt<= w_same_id_tr_cnt - 1;
                if(w_same_id_tr_cnt == 1) begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b1;
                end else begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b0;
                end
            end else if (I_AXI_M_BValid & I_AXI_M_BReady & ~O_EarlyResponse_Consume & (I_AXI_AwId == I_AXI_M_BId)) begin
                awtable[w_awtable_wptr_cur].same_id_tr_cnt<= w_same_id_tr_cnt - 1;
                if(w_same_id_tr_cnt == 1) begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b1;
                end else begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b0;
                end
            end else begin
                awtable[w_awtable_wptr_cur].same_id_tr_cnt<= w_same_id_tr_cnt;
                if(w_same_id_tr_cnt == 0) begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b1;
                end else begin
                    awtable[w_awtable_wptr_cur].early_go <= 1'b0;
                end
            end

            if (I_AXI_M_BValid & I_AXI_M_BReady & (I_AXI_AwId == I_AXI_M_BId)) begin
                awtable[w_awtable_wptr_cur].wid_numbering       <= w_wid_numbering - 1;
            end else begin
                awtable[w_awtable_wptr_cur].wid_numbering       <= w_wid_numbering;
            end
        end
        
        for(integer i = 0; i < WR_MO_CNT ; i = i + 1) begin
            if((awtable[i].pending) & (awtable[i].bufferable) & (~awtable[i].out)) begin
                if(I_AXI_M_BValid & I_AXI_M_BReady & ~O_EarlyResponse_Consume & (awtable[i].id == I_AXI_M_BId)) begin
                    awtable[i].same_id_tr_cnt <= awtable[i].same_id_tr_cnt - 1;
                    if(awtable[i].same_id_tr_cnt == 1) begin
                        awtable[i].early_go <= 1'b1;
                    end
                end else if (O_EarlyResponse_Valid & I_AXI_S_BReady & (awtable[i].id == awtable[w_early_resp_idx].id)) begin
                    awtable[i].same_id_tr_cnt <= awtable[i].same_id_tr_cnt - 1;   
                    if(awtable[i].same_id_tr_cnt == 1) begin
                        awtable[i].early_go <= 1'b1;        
                    end     
                end
            end
        end

        if (O_EarlyResponse_Valid & I_AXI_S_BReady) begin
            awtable[w_early_resp_idx].out <= 1'b1;
        end

        if (I_AXI_M_BValid & I_AXI_M_BReady) begin
            awtable[w_awtable_rptr_cur].pending <= 1'b0;
        end

        for (integer i=0; i<WR_MO_CNT; i=i+1) begin
            if (I_AXI_M_BValid & I_AXI_M_BReady & awtable[i].pending & (awtable[i].id == I_AXI_M_BId) & (awtable[i].wid_numbering != 'd0)) begin
                awtable[i].wid_numbering <= awtable[i].wid_numbering -'d1;
            end
        end         
    end
end

//------------------------------------------------------------------
always_comb begin
    w_awtable_wptr_cur = 'd0;
    for (integer i=0; i<WR_MO_CNT; i=i+1) begin
        if (!awtable[WR_MO_CNT-1 - i].pending) begin // search from back
            w_awtable_wptr_cur = WR_MO_CNT-1 - i;
        end
    end
end

always_comb begin
    w_awtable_rptr_cur = 'd0;
    for (integer i=0; i<WR_MO_CNT; i=i+1) begin
        w_awtable_r_onehot[i] = awtable[i].pending & (awtable[i].id == I_AXI_M_BId) & (awtable[i].wid_numbering == 'd0);
    end

    for (integer i=0; i<WR_MO_CNT; i=i+1) begin
        if (w_awtable_r_onehot[i]) begin
            w_awtable_rptr_cur = i;
        end
    end
end

always_comb begin
    for(integer i = 0; i < WR_MO_CNT ; i = i + 1) begin
        w_wr_same_id_match_flag[i] = (awtable[i].pending) & (awtable[i].id == I_AXI_AwId) & (~awtable[i].out);
    end
end

always_comb begin
    w_same_id_tr_cnt = $countones(w_wr_same_id_match_flag);
end

always_comb begin
    w_early_resp_idx = 'd0;
    w_early_resp_flag = 'd0;
    for(integer i = 0; i < WR_MO_CNT ; i = i + 1) begin
        if((awtable[i].pending) & (awtable[i].bufferable) & (~awtable[i].out) & (awtable[i].early_go)) begin
            w_early_resp_flag= 1'b1;
            w_early_resp_idx = i;
        end
    end
end

//------------------------------------------------------------------
assign O_EarlyResponse_Consume = awtable[w_awtable_rptr_cur].bufferable;
assign O_EarlyResponse_Id  = awtable[w_early_resp_idx].id;
assign O_EarlyResponse_Valid = w_early_resp_flag;
//------------------------------------------------------------------
assign O_DEST_TABLE_ID_ERR = (~(|w_awtable_r_onehot) & I_AXI_M_BValid & I_AXI_M_BReady);
//------------------------------------------------------------------
`ifdef ASSERTION_ON
// synopsys translate_off

aou_early_table_id_err_assertion:
    assert
        property (
            @(posedge I_CLK) disable iff (!I_RESETN)
            !O_DEST_TABLE_ID_ERR 
        )
        else begin
            $error("\n[%t] AOU_EARLY_TABLE: O_DEST_TABLE_ID_ERR asserted!", $time);
            $finish;
        end

// synopsys translate_on
`endif

endmodule
