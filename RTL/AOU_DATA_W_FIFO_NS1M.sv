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
//  Module     : AOU_DATA_W_FIFO_NS1M
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_DATA_W_FIFO_NS1M
#(
    parameter   AXI_PEER_DIE_MAX_DATA_WD = 1024,
    localparam  AXI_STRB_WD     = AXI_PEER_DIE_MAX_DATA_WD/8,
    localparam  DATA_FIFO_WD    = 256,
    localparam  STRB_FIFO_WD    = DATA_FIFO_WD/8,
    parameter   FIFO_DEPTH      = 64,          // depth
    parameter   ICH_CNT         = 8,          // input channel count
    parameter   DEC_MULTI       = 2,
    localparam  REQ_CNT         = (DEC_MULTI == 1) ? 6 : (DEC_MULTI == 2) ? 7 : 11,
    localparam  REQ_CNT_WD      = $clog2(REQ_CNT+1),
    parameter   ALWAYS_READY    = 0,

    localparam  AXI_CON         = AXI_PEER_DIE_MAX_DATA_WD/DATA_FIFO_WD,
    localparam  ICH_CNT_WD = $clog2(ICH_CNT+1),
    localparam  AW              = $clog2(FIFO_DEPTH)

)
(
    input                                   I_CLK,
    input                                   I_RESETN,

    input  [ICH_CNT-1:0]                    I_SVALID,
    input  [ICH_CNT-1:0][AXI_PEER_DIE_MAX_DATA_WD-1:0]  I_SDATA,//0: 1024bit 1: 512bit 2,3: 256bit
    input  [ICH_CNT-1:0][AXI_STRB_WD-1:0]   I_SDATA_STRB,
    input  [ICH_CNT-1:0]                    I_SDATA_WDATAF,
    output                                  O_SREADY,

    input                                   I_MREADY,
    output [AXI_PEER_DIE_MAX_DATA_WD-1:0]   O_MDATA,
    output [AXI_STRB_WD-1:0]                O_MDATA_STRB,
    output [1:0]                            O_MDLEN,
    output                                  O_MDATA_WDATAF,
    output                                  O_MVALID
);

    logic [FIFO_DEPTH-1:0][STRB_FIFO_WD+2:0]            strb_fifo;
    logic [ICH_CNT-1:0][AXI_CON-1:0][STRB_FIFO_WD+2:0]  nxt_strb_data;

    logic                                               r_ex_data_ptr;
    logic                                               w_ex_data_ptr;

    logic [FIFO_DEPTH-1:0][DATA_FIFO_WD-1:0]            data_fifo;
    logic [ICH_CNT-1:0][AXI_CON-1:0][DATA_FIFO_WD-1:0]  nxt_data;

    logic [AW-1:0]                                      r_data_ptr;
    logic [AW-1:0]                                      w_data_ptr;
    logic [REQ_CNT_WD-1:0]                              w_data_req_cnt;
    logic [ICH_CNT-1:0][AXI_CON-1:0]                    w_data_req_valid;
    logic [AW-1:0]                                      nxt_r_data_ptr;
    logic [ICH_CNT-1:0][AXI_CON-1:0][AW-1:0]            nxt_w_data_ptr;

    logic [1:0]                                         mdlen;
    logic [AXI_CON-1:0][DATA_FIFO_WD-1:0]               mdata;
    logic [AXI_CON-1:0][STRB_FIFO_WD-1:0]               mstrb;

    logic                                               fifo_full;
//--------------------------------------------------------------------------
    integer idx_write_req;
    always_comb begin
        w_data_req_cnt  = 'd0;
        nxt_data        = 'd0;
        nxt_w_data_ptr  = 'd0;
        w_data_req_valid = 'd0;
        nxt_strb_data    = 'd0;
        for(int dec_multi = 0; dec_multi < DEC_MULTI; dec_multi = dec_multi + 1) begin
            if(I_SVALID[dec_multi*4+0]) begin
            for(idx_write_req = 0; idx_write_req < 4; idx_write_req = idx_write_req + 1) begin
                    nxt_data[dec_multi*4+0][idx_write_req] = I_SDATA[dec_multi*4+0][(DATA_FIFO_WD*idx_write_req) +: DATA_FIFO_WD];
                    nxt_w_data_ptr[dec_multi*4+0][idx_write_req] = (w_data_ptr + w_data_req_cnt >= FIFO_DEPTH) ? (w_data_ptr + w_data_req_cnt - FIFO_DEPTH) : (w_data_ptr + w_data_req_cnt);
                    nxt_strb_data[dec_multi*4+0][idx_write_req] = {I_SDATA_STRB[dec_multi*4+0][(STRB_FIFO_WD*idx_write_req) +: STRB_FIFO_WD], I_SDATA_WDATAF[dec_multi*4+0], 2'b10};
                    w_data_req_valid[dec_multi*4+0][idx_write_req] = 1;
                w_data_req_cnt = w_data_req_cnt + 1;
            end
            end else if(I_SVALID[dec_multi*4+1]) begin
            for(idx_write_req = 0; idx_write_req < 2; idx_write_req = idx_write_req + 1) begin
                    nxt_data[dec_multi*4+1][idx_write_req] = I_SDATA[dec_multi*4+1][(DATA_FIFO_WD*idx_write_req) +: DATA_FIFO_WD];
                    nxt_w_data_ptr[dec_multi*4+1][idx_write_req] = (w_data_ptr + w_data_req_cnt >= FIFO_DEPTH) ? (w_data_ptr + w_data_req_cnt - FIFO_DEPTH) : (w_data_ptr + w_data_req_cnt);
                    nxt_strb_data[dec_multi*4+1][idx_write_req] = {I_SDATA_STRB[dec_multi*4+1][(STRB_FIFO_WD*idx_write_req) +: STRB_FIFO_WD], I_SDATA_WDATAF[dec_multi*4+1], 2'b01};
                    w_data_req_valid[dec_multi*4+1][idx_write_req] = 1;
                w_data_req_cnt = w_data_req_cnt + 1;
            end
        end
            if(I_SVALID[dec_multi*4+2]) begin
            for(idx_write_req = 0; idx_write_req < 1; idx_write_req = idx_write_req + 1) begin
                    nxt_data[dec_multi*4+2][idx_write_req] = I_SDATA[dec_multi*4+2][(DATA_FIFO_WD*idx_write_req) +: DATA_FIFO_WD];
                    nxt_w_data_ptr[dec_multi*4+2][idx_write_req] = (w_data_ptr + w_data_req_cnt >= FIFO_DEPTH) ? (w_data_ptr + w_data_req_cnt - FIFO_DEPTH) : (w_data_ptr + w_data_req_cnt);
                    nxt_strb_data[dec_multi*4+2][idx_write_req] = {I_SDATA_STRB[dec_multi*4+2][(STRB_FIFO_WD*idx_write_req) +: STRB_FIFO_WD], I_SDATA_WDATAF[dec_multi*4+2], 2'b00};
                    w_data_req_valid[dec_multi*4+2][idx_write_req] = 1;
                w_data_req_cnt = w_data_req_cnt + 1;
            end
        end
            if(I_SVALID[dec_multi*4+3]) begin
            for(idx_write_req = 0; idx_write_req < 1; idx_write_req = idx_write_req + 1) begin
                    nxt_data[dec_multi*4+3][idx_write_req] = I_SDATA[dec_multi*4+3][(DATA_FIFO_WD*idx_write_req) +: DATA_FIFO_WD];
                    nxt_w_data_ptr[dec_multi*4+3][idx_write_req] = (w_data_ptr + w_data_req_cnt >= FIFO_DEPTH) ? (w_data_ptr + w_data_req_cnt - FIFO_DEPTH) : (w_data_ptr + w_data_req_cnt);
                    nxt_strb_data[dec_multi*4+3][idx_write_req] = {I_SDATA_STRB[dec_multi*4+3][(STRB_FIFO_WD*idx_write_req) +: STRB_FIFO_WD], I_SDATA_WDATAF[dec_multi*4+3], 2'b00};
                    w_data_req_valid[dec_multi*4+3][idx_write_req] = 1;
                w_data_req_cnt = w_data_req_cnt + 1;
            end
        end
    end
    end

    //for write
    //
    // Writes to data_fifo and strb_fifo are expressed as per-entry mux/enable
    // networks (outer loop sweeps the storage entry, inner loops scan the
    // input channels) so the indexed selects never appear with an out-of-range
    // address when FIFO_DEPTH is not a power of two. This avoids the X
    // don't-care lanes that would otherwise expand into a large set of LEC
    // "E" key points (with the associated runtime / abort cost).
    integer i, j;
    always_ff @ (posedge I_CLK or negedge I_RESETN) begin
    if (~I_RESETN) begin
            for (i = 0; i < FIFO_DEPTH; i = i+1) begin
                data_fifo[i] <= 0;
                strb_fifo[i] <= 0;
        end
            w_data_ptr <= 0;
            w_ex_data_ptr <= 0;
    end else begin
            for (int k = 0; k < FIFO_DEPTH; k = k+1) begin
                for (int wi = 0; wi < ICH_CNT; wi = wi+1) begin
                    if (I_SVALID[wi] && O_SREADY) begin
                        for (int wj = 0; wj < AXI_CON; wj = wj+1) begin
                            if (w_data_req_valid[wi][wj] &&
                                (nxt_w_data_ptr[wi][wj][AW-1:0] == k[AW-1:0])) begin
                                data_fifo[k] <= nxt_data[wi][wj];
                                strb_fifo[k] <= nxt_strb_data[wi][wj];
                            end
                        end
                    end
                end
            end
            if((|I_SVALID) && O_SREADY) begin
                w_data_ptr <= (w_data_ptr + w_data_req_cnt >= FIFO_DEPTH) ? (w_data_ptr + w_data_req_cnt - FIFO_DEPTH) : (w_data_ptr + w_data_req_cnt);
                w_ex_data_ptr <= (w_data_ptr + w_data_req_cnt  >= FIFO_DEPTH) ? ~w_ex_data_ptr : w_ex_data_ptr;
            end
        end
    end

    // Read mux for strb_fifo. Built as a single explicit one-hot select over
    // the reachable index range [0, FIFO_DEPTH-1] -- both O_MDLEN and
    // O_MDATA_WDATAF tap the same r_data_ptr, so we materialise the entry
    // once and slice it for the two consumers below. This avoids out-of-range
    // X don't-cares on r_data_ptr (same motivation as the write port).
    logic [STRB_FIFO_WD+2:0] w_strb_rd_data;
    always_comb begin
        w_strb_rd_data = '0;
        for (int k = 0; k < FIFO_DEPTH; k = k+1) begin
            if (r_data_ptr == k[AW-1:0]) w_strb_rd_data = strb_fifo[k];
        end
    end

    assign O_MDLEN          = w_strb_rd_data[1:0];
    assign O_MDATA_WDATAF   = w_strb_rd_data[2];
    //for read
    always_ff @ (posedge I_CLK or negedge I_RESETN) begin
        if (~I_RESETN) begin
            r_data_ptr <= 0;
            r_ex_data_ptr <= 0;
        end else begin
            if (I_MREADY && O_MVALID) begin
                if(O_MDLEN == 2'b10) begin
                    r_data_ptr <= (r_data_ptr + 4 >= FIFO_DEPTH) ? (r_data_ptr + 4 - FIFO_DEPTH) : (r_data_ptr + 4);
                    r_ex_data_ptr <= (r_data_ptr + 4 >= FIFO_DEPTH) ? ~r_ex_data_ptr : r_ex_data_ptr;
                end else if(O_MDLEN == 2'b01) begin
                    r_data_ptr <= (r_data_ptr + 2 >= FIFO_DEPTH) ? (r_data_ptr + 2 - FIFO_DEPTH) : (r_data_ptr + 2);
                    r_ex_data_ptr <= (r_data_ptr + 2 >= FIFO_DEPTH) ? ~r_ex_data_ptr : r_ex_data_ptr;
                end else begin
                    r_data_ptr <= (r_data_ptr + 1 == FIFO_DEPTH) ? (r_data_ptr + 1 - FIFO_DEPTH) : (r_data_ptr + 1);
                    r_ex_data_ptr <= (r_data_ptr + 1 >= FIFO_DEPTH) ? ~r_ex_data_ptr : r_ex_data_ptr;
                end
            end
        end
    end

    assign fifo_full = ((r_data_ptr == w_data_ptr) && (r_ex_data_ptr != w_ex_data_ptr));

    integer l;
    logic [ICH_CNT_WD-1:0] r_data_req_cnt;
    logic [AW-1:0] r_data_ptr_tmp;
    always_comb begin
        mdata = 'd0;
        mstrb = 'd0;
        r_data_req_cnt = 'd0;
        r_data_ptr_tmp = 'd0;

        for(l = 0; l < AXI_CON; l = l + 1) begin
           if(l < (1 << O_MDLEN)) begin
                r_data_ptr_tmp = (r_data_ptr + r_data_req_cnt >= FIFO_DEPTH) ? (r_data_ptr + r_data_req_cnt - FIFO_DEPTH) : (r_data_ptr + r_data_req_cnt);
                // Explicit one-hot mux over the reachable index range so
                // r_data_ptr_tmp values in the unreachable range do not
                // introduce out-of-range X don't-cares. data_fifo and
                // strb_fifo share the same address, so they reuse the same
                // one-hot decode.
                for (int k = 0; k < FIFO_DEPTH; k = k+1) begin
                    if (r_data_ptr_tmp == k[AW-1:0]) begin
                        mdata[l] = data_fifo[k];
                        mstrb[l] = strb_fifo[k][3 +: STRB_FIFO_WD];
                    end
                end
                r_data_req_cnt = r_data_req_cnt + 1;
    end
        end
    end

    assign O_MDATA = (O_MDLEN == 2'b00) ? {{(AXI_PEER_DIE_MAX_DATA_WD - 256){1'b0}}, mdata[0]} : (O_MDLEN == 2'b01) ? {{(AXI_PEER_DIE_MAX_DATA_WD - 512){1'b0}}, mdata[1:0]} : mdata;
    assign O_MDATA_STRB = (O_MDLEN == 2'b00) ? {{(AXI_STRB_WD - 32){1'b0}}, mstrb[0]} : (O_MDLEN == 2'b01) ? {{(AXI_STRB_WD - 64){1'b0}}, mstrb[1:0]} : mstrb;
    assign O_MVALID = ~((r_ex_data_ptr == w_ex_data_ptr) && (r_data_ptr == w_data_ptr));
    assign O_SREADY = (ALWAYS_READY) ? 1 : (~fifo_full);

endmodule
