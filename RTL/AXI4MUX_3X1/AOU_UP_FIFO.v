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
//  Module     : AOU_UP_FIFO
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_UP_FIFO
#(
    parameter I_DW = 32,            // input data width
              O_DW = 128,           // output data width
              FD = 32,              // depth
              AW = $clog2(FD),
              CNT_WD = $clog2(FD+1)
)
(
    input                     I_CLK,
    input                     I_RESETN,

    //for write
    input                     I_SVALID,
    input    [I_DW-1:0]       I_SDATA,
    //I_SLAST signal for last write
    input                     I_SLAST,
    output                    O_SREADY,

    //for read
    input                     I_MREADY,
    output   [O_DW-1:0]       O_MDATA,
    output                    O_MVALID,
    output   [CNT_WD-1:0]     O_EMPTY_CNT,
    output   [CNT_WD-1:0]     O_DATA_CNT

);
localparam    LSB_FIRST = 1;

localparam    UP_N      = O_DW/I_DW;         // upsizer beats
localparam    UP_WD     = $clog2(UP_N);


reg     [I_DW-1:0]              r_fifo [0:FD-1];
reg     [AW:0]                  r_rd_ptr, r_wr_ptr;

wire    [CNT_WD:0]                  w_data_cnt;

//buffer for upsizer
reg     [O_DW-1:0]              r_data_buf;

integer i, j;

//for write
always @ (posedge I_CLK or negedge I_RESETN) begin
    if (~I_RESETN) begin
        for (i = 0; i < FD; i = i+1) begin
            r_fifo[i] <= 0;
        end
        r_wr_ptr <= 0;
    end else if (I_SVALID && O_SREADY) begin
        if(I_SLAST) begin

            for (j = 1; j < UP_N; j = j+1) begin
                if (j < UP_N - r_wr_ptr[UP_WD-1:0]) begin
                    r_fifo[r_wr_ptr[AW-1:0] + j] <= 0;
                end
            end

            r_wr_ptr <= r_wr_ptr + (UP_N - r_wr_ptr[UP_WD-1:0]);
        end else begin
            r_wr_ptr <= r_wr_ptr + 1;
        end
        r_fifo[r_wr_ptr[AW-1:0]] <= I_SDATA;
    end
end

//for read
always @ (posedge I_CLK or negedge I_RESETN ) begin
    if (~I_RESETN) begin
        r_rd_ptr <= 0;
    end else if (I_MREADY && O_MVALID) begin
        r_rd_ptr <= r_rd_ptr + UP_N;
    end
end

//output logic
generate
    if (LSB_FIRST) begin
        always @ (*) begin
            for (j=0; j < UP_N; j=j+1) begin
                r_data_buf[(j*I_DW) +: I_DW] = r_fifo[(r_rd_ptr[AW-1:0] + j)];
            end
        end
    end else begin
        always @ (*) begin
            for (j=0; j < UP_N; j=j+1) begin
                r_data_buf[((UP_N -1-j)*I_DW) +: I_DW] = r_fifo[(r_rd_ptr[AW-1:0] + j)];
            end
        end
    end
endgenerate


assign O_EMPTY_CNT = FD - O_DATA_CNT;
assign w_data_cnt  = r_wr_ptr - r_rd_ptr;
assign O_DATA_CNT = w_data_cnt[CNT_WD-1:0];

assign O_SREADY = ~((r_wr_ptr[AW] != r_rd_ptr[AW]) & (r_wr_ptr[AW-1:0] == r_rd_ptr[AW-1:0]));
assign O_MVALID = ~(r_wr_ptr[AW:UP_WD] == r_rd_ptr[AW:UP_WD]);
assign O_MDATA = r_data_buf;

endmodule
