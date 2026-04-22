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
//  Module     : AOU_FWD_RS
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_FWD_RS #(
    parameter  DATA_WIDTH = 16
)
(
    input                           I_RESETN ,
    input                           I_CLK    ,
    
    input                           I_SVALID ,
    output                          O_SREADY ,
    input [DATA_WIDTH - 1:0]        I_SDATA  ,
    
    output                          O_MVALID ,
    input                           I_MREADY ,
    output [DATA_WIDTH - 1:0]       O_MDATA  
);

logic                 w_store_data;
logic [DATA_WIDTH-1:0]r_mdata;
logic                 w_update_valid;
logic                 r_buf_valid;

assign O_SREADY = I_MREADY || ~r_buf_valid;

always_ff @(posedge I_CLK or negedge I_RESETN) begin
  if(~I_RESETN)
    r_mdata <= 'd0;
  else if (w_store_data)
    r_mdata <= I_SDATA;
end

assign w_store_data = ((I_SVALID && ~r_buf_valid) | (I_SVALID && r_buf_valid && I_MREADY));

assign w_update_valid = I_SVALID || I_MREADY;

always_ff @(posedge I_CLK or negedge I_RESETN) begin
  if (~I_RESETN)
    r_buf_valid <= 1'b0;
  else if (w_update_valid)
    r_buf_valid <= I_SVALID;
end

assign O_MVALID = r_buf_valid;
assign O_MDATA  = r_mdata;
endmodule

