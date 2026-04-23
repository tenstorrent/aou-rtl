// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
//  Copyright (c) 2026 BOS Semiconductors
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
//  Module     : AOU_SYNC_FIFO_REG
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns / 1ps

module AOU_SYNC_FIFO_REG #(
    parameter   FIFO_WIDTH  = 16,
    parameter   FIFO_DEPTH  = 8,
    parameter   AW          = $clog2(FIFO_DEPTH),
    parameter   CNT_WD      = $clog2(FIFO_DEPTH+1),
    parameter   CONSTRAINT_SREADY_ALWAYS_1 = 0
)
(
    input                       I_CLK           ,
    input                       I_RESETN        ,
    // write transaction
    input                       I_SVALID        ,
    input   [FIFO_WIDTH-1 : 0]  I_SDATA         ,
    output                      O_SREADY        ,
    // read transaction
    input                       I_MREADY        ,
    output  [FIFO_WIDTH-1 : 0]  O_MDATA         , // DATA + VALID signals are same INPUT or OUTPUT
    output                      O_MVALID        ,

    output  [CNT_WD-1: 0]       O_EMPTY_CNT     ,
    output  [CNT_WD-1: 0]       O_FULL_CNT
);
//-------------------------------------------------------------------
    reg  [CNT_WD-1: 0]          r_empty_cnt     ;
    reg  [CNT_WD-1: 0]          r_full_cnt      ;

    reg  [AW-1 : 0]             r_cnt           ;
    reg  [AW-1 : 0]             w_cnt           ;
    wire [AW-1 : 0]             nxt_r_cnt       ;
    wire [AW-1 : 0]             nxt_w_cnt       ;

    reg                         r_ex_cnt        ;
    reg                         w_ex_cnt        ;
    wire                        nxt_r_ex_cnt    ;
    wire                        nxt_w_ex_cnt    ;

    reg  [FIFO_WIDTH-1 : 0]     mem [FIFO_DEPTH-1 : 0]  ;
//-------------------------------------------------------------------
    assign nxt_r_cnt = (r_cnt == FIFO_DEPTH-1) ? ({AW{1'b0}}) : (r_cnt + 1'b1);
    assign nxt_w_cnt = (w_cnt == FIFO_DEPTH-1) ? ({AW{1'b0}}) : (w_cnt + 1'b1);

    assign nxt_r_ex_cnt = (r_cnt == FIFO_DEPTH-1) ? ~r_ex_cnt : r_ex_cnt;
    assign nxt_w_ex_cnt = (w_cnt == FIFO_DEPTH-1) ? ~w_ex_cnt : w_ex_cnt;
//-------------------------------------------------------------------
    // The mem write port is expressed as a per-entry decode (for-loop with
    // explicit address compare per entry) so the indexed select mem[w_cnt]
    // never appears with an out-of-range address when FIFO_DEPTH is not a
    // power of two. This avoids the X don't-care lanes that would otherwise
    // expand into a large set of LEC "E" key points (with the associated
    // runtime / abort cost). Synthesis result is unchanged: the same one-hot
    // decode + per-entry enable network is produced either way.
    integer i;
    integer wr_k;
    always @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            w_cnt <= {AW{1'b0}};
            w_ex_cnt <= 1'b0;

            r_cnt <= {AW{1'b0}};
            r_ex_cnt <= 1'b0;

            for(i = 0; i < FIFO_DEPTH; i = i + 1)
                mem[i] <= 0;

        end else begin
            // write transaction here
            if ( I_SVALID && O_SREADY) begin
                w_cnt       <= nxt_w_cnt;
                w_ex_cnt    <= nxt_w_ex_cnt;
                for (wr_k = 0; wr_k < FIFO_DEPTH; wr_k = wr_k + 1) begin
                    if (w_cnt == wr_k[AW-1:0]) mem[wr_k] <= I_SDATA;
                end
            end

            // read transaction here
            if (I_MREADY && O_MVALID) begin
                r_cnt       <= nxt_r_cnt;
                r_ex_cnt    <= nxt_r_ex_cnt;
            end
        end
    end

//-------------------------------------------------------------------
    always @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            r_empty_cnt <= (CNT_WD)'(FIFO_DEPTH);
        end else begin
            if(( I_SVALID && O_SREADY) & (I_MREADY && O_MVALID)) begin
                r_empty_cnt <= r_empty_cnt;
            end else if(I_SVALID && O_SREADY) begin
                r_empty_cnt <= r_empty_cnt - 1;
            end else if(I_MREADY && O_MVALID) begin
                r_empty_cnt <= r_empty_cnt + 1;
            end
        end
    end

    assign O_EMPTY_CNT = r_empty_cnt;

    always @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            r_full_cnt <= {CNT_WD{1'b0}};
        end else begin
            if(( I_SVALID && O_SREADY) & (I_MREADY && O_MVALID)) begin
                r_full_cnt <= r_full_cnt;
            end else if(I_SVALID && O_SREADY) begin
                r_full_cnt <= r_full_cnt + 1;
            end else if(I_MREADY && O_MVALID) begin
                r_full_cnt <= r_full_cnt - 1;
            end
        end
    end

    assign O_FULL_CNT = r_full_cnt;
//-------------------------------------------------------------------
    assign O_SREADY  =   ~((w_cnt == r_cnt) & (r_ex_cnt != w_ex_cnt)) ;
    assign O_MVALID  =   ~((w_cnt == r_cnt) & (r_ex_cnt == w_ex_cnt));

    // Read mux for mem. Built as an explicit one-hot select over the
    // reachable index range [0, FIFO_DEPTH-1] so r_cnt values in the
    // unreachable range [FIFO_DEPTH, 2**AW-1] -- which the wrap arithmetic
    // above guarantees never occur -- do not introduce out-of-range X
    // don't-cares. Same motivation as the write port above: keeps LEC clean
    // of redundant "E" key points.
    reg  [FIFO_WIDTH-1 : 0] r_mdata;
    integer rd_k;
    always @* begin
        r_mdata = {FIFO_WIDTH{1'b0}};
        for (rd_k = 0; rd_k < FIFO_DEPTH; rd_k = rd_k + 1) begin
            if (r_cnt == rd_k[AW-1:0]) r_mdata = mem[rd_k];
        end
    end
    assign O_MDATA   =   r_mdata;

//-------------------------------------------------------------------
`ifdef ASSERTION_ON
// synopsys translate_off

ready_valid_assertion:
    assert
        property (
            @(posedge I_CLK) (I_SVALID) |->
                (CONSTRAINT_SREADY_ALWAYS_1 ?  O_SREADY : 1'b1)
        )
        else begin
            $error("\n[%t] Error!. This FIFO should always be able to accept all valid input data ", $time);
            $finish;
        end

// synopsys translate_on
`endif
//-------------------------------------------------------------------


endmodule
