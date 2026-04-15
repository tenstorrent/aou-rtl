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
//  Module     : AOU_SPLIT_RD_PENDING_INFO
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_SPLIT_RD_PENDING_INFO #(
    parameter  AXI_ADDR_WD   = 32,
    parameter  AXI_ID_WD     = 4,
    parameter  AXI_LEN_WD    = 8,

    parameter  RD_MO_CNT     = 32,
    localparam RD_MO_IDX_WD  = $clog2(RD_MO_CNT),
    localparam RD_MO_CNT_WD  = $clog2(RD_MO_CNT+1)
)
(
    input                                 I_CLK,
    input                                 I_RESETN,

    input    [AXI_ID_WD-1:0]              I_AXI_ArId,
    input    [AXI_ADDR_WD-1:0]            I_AXI_ArAddr_align,
    input    [AXI_LEN_WD-1:0]             I_AXI_ArLen,
    input    [2:0]                        I_AXI_ArSize,
    input    [1:0]                        I_AXI_MuxId,
    input                                 I_AXI_ArValid,
    input                                 I_AXI_ArReady,
    output logic                          O_AR_Slot_Available_Flag,

    // Master I/F
    input    [AXI_ID_WD-1:0]              I_AXI_RId,
    input                                 I_AXI_RLast,
    input                                 I_AXI_RValid,
    input                                 I_AXI_RReady,

    output logic  [AXI_ADDR_WD-1:0]       O_CUR_ARADDR,
    output logic                          O_ReorderBuf_MValid,
    output logic  [AXI_ADDR_WD +2 -1:0]   O_ReorderBuf_MData,

    output logic                          O_DEST_TABLE_ID_ERR
);


typedef struct  packed {
    logic [AXI_ID_WD-1:0]           id;
    logic [AXI_LEN_WD-1:0]          burst_len;
    logic                           pending;
    logic [RD_MO_IDX_WD-1:0]        rid_numbering;

    logic [AXI_ADDR_WD:0]           araddr;
    logic [2:0]                     arsize;
    logic [1:0]                     muxid;
} st_ar_table;

st_ar_table  [RD_MO_CNT-1:0]   artable;

logic [RD_MO_CNT-1:0]              w_artable_r_onehot;
logic [RD_MO_CNT-1:0]              w_artable_clean_onehot;
logic [RD_MO_IDX_WD-1:0]           w_artable_wptr_cur, w_artable_rptr_cur;

logic [RD_MO_CNT_WD-1:0]           r_arcnt, w_arcnt_next;

logic [RD_MO_CNT-1:0]              w_rid_numbering_onehot;
logic [RD_MO_IDX_WD-1:0]           w_rid_numbering;

////////////////////////////////////

////////// synchronizer after set up ////////////

//////////////////////////////////////////////////////////////////////////////////////////
assign O_AR_Slot_Available_Flag = (r_arcnt != RD_MO_CNT);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always_ff @ (posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        r_arcnt <= 'd0;
    end else if ((I_AXI_ArValid & I_AXI_ArReady) | (I_AXI_RLast & I_AXI_RValid & I_AXI_RReady & ~(|artable[w_artable_rptr_cur].burst_len))) begin
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

/////////////////////////////////// RID numbering ///////////////////////////////////////////////
always_comb begin
    for (int i=0; i<RD_MO_CNT; i++)
        w_rid_numbering_onehot[i] = artable[i].pending && (artable[i].id == I_AXI_ArId);

    w_rid_numbering = $countones(w_rid_numbering_onehot);
end
//////////////////////////////////// AR ///////////////////////////////////////////////

always_ff @ (posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        for (integer i=0; i<RD_MO_CNT; i=i+1) begin
            artable[i].id                <= 'd0;
            artable[i].burst_len         <= 'd0;
            artable[i].pending           <= 'd0;
            artable[i].rid_numbering     <= 'd0;

            artable[i].araddr            <= 'd0;
            artable[i].arsize            <= 'd0;
            artable[i].muxid             <= 'd0;
        end
    end else begin
        if (I_AXI_ArValid & I_AXI_ArReady) begin
            if (I_AXI_RValid & I_AXI_RReady & I_AXI_RLast & (I_AXI_ArId == I_AXI_RId) & (artable[w_artable_rptr_cur].burst_len == 'd0)) begin
                artable[w_artable_wptr_cur].id            <= I_AXI_ArId;
                artable[w_artable_wptr_cur].burst_len     <= I_AXI_ArLen;
                artable[w_artable_wptr_cur].pending       <= 1'd1;
                artable[w_artable_wptr_cur].rid_numbering <= w_rid_numbering - 1;

                artable[w_artable_wptr_cur].araddr        <= {1'b0, I_AXI_ArAddr_align};
                artable[w_artable_wptr_cur].arsize        <= I_AXI_ArSize;
                artable[w_artable_wptr_cur].muxid         <= I_AXI_MuxId;

            end else begin
                artable[w_artable_wptr_cur].id            <= I_AXI_ArId;
                artable[w_artable_wptr_cur].burst_len     <= I_AXI_ArLen;
                artable[w_artable_wptr_cur].pending       <= 1'd1;
                artable[w_artable_wptr_cur].rid_numbering <= w_rid_numbering;

                artable[w_artable_wptr_cur].araddr        <= {1'b0, I_AXI_ArAddr_align};
                artable[w_artable_wptr_cur].arsize        <= I_AXI_ArSize;
                artable[w_artable_wptr_cur].muxid         <= I_AXI_MuxId;

            end
        end

        if (I_AXI_RValid & I_AXI_RReady) begin
            if (I_AXI_RLast) begin
                if(|artable[w_artable_rptr_cur].burst_len)
                    artable[w_artable_rptr_cur].burst_len <= artable[w_artable_rptr_cur].burst_len - 'd1;
                else
                    artable[w_artable_rptr_cur].pending <= 1'd0;
            end
            artable[w_artable_rptr_cur].araddr <= artable[w_artable_rptr_cur].araddr + ({1'b0,{(AXI_ADDR_WD-1){1'b0}}, 1'b1} << (artable[w_artable_rptr_cur].arsize));
        end

        for (integer i=0; i<RD_MO_CNT; i=i+1) begin
            if (I_AXI_RValid & I_AXI_RReady & I_AXI_RLast & (artable[w_artable_rptr_cur].burst_len == 'd0) & artable[i].pending & (artable[i].id == I_AXI_RId) & (artable[i].rid_numbering != 'd0)) begin
                artable[i].rid_numbering <= artable[i].rid_numbering -'d1;
            end
        end
    end
end

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

///////////////////////////////////////////////////////////////////////////////////
assign O_CUR_ARADDR         = artable[w_artable_rptr_cur].araddr[AXI_ADDR_WD-1:0];
assign O_ReorderBuf_MValid  = I_AXI_RValid & I_AXI_RReady & I_AXI_RLast & (artable[w_artable_rptr_cur].burst_len == 'd0);
assign O_ReorderBuf_MData   = {artable[w_artable_rptr_cur].araddr[AXI_ADDR_WD-1:0], artable[w_artable_rptr_cur].muxid};

assign O_DEST_TABLE_ID_ERR  = I_AXI_RValid & I_AXI_RReady & ~(|w_artable_r_onehot);
///////////////////////////////////////////////////////////////////////////////////
`ifdef ASSERTION_ON
// synopsys translate_off

aou_split_rd_pending_info_table_id_err_assertion:
    assert
        property (
            @(posedge I_CLK) disable iff (!I_RESETN)
            !O_DEST_TABLE_ID_ERR 
        )
        else begin
            $error("\n[%t] AOU_SPLIT_RD_PENDING_INFO: O_DEST_TABLE_ID_ERR asserted!", $time);
            $finish;
        end

// synopsys translate_on
`endif

endmodule
