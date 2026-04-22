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
//  Module     : AOU_RX_CORE_IN_MUX
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_RX_CORE_IN_MUX #(
    parameter       FDI_IF_WD = 512
)
( 
    input                                   I_CLK,
    input                                   I_RESETN,

    input                                   I_PHY_TYPE,

    input                                   I_FDI_PL_1_VALID,
    input    [FDI_IF_WD - 1: 0]             I_FDI_PL_1_DATA,
    input                                   I_FDI_PL_1_FLIT_CANCEL,

    input                                   I_FDI_PL_0_VALID,
    input    [FDI_IF_WD/2 - 1: 0]           I_FDI_PL_0_DATA,
    input                                   I_FDI_PL_0_FLIT_CANCEL,

    output                                  O_FDI_PL_VALID,
    output   [FDI_IF_WD - 1: 0]             O_FDI_PL_DATA,
    output                                  O_FDI_PL_FLIT_CANCEL

);

logic    [FDI_IF_WD/2 - 1: 0]           r_fdi_pl_0_data ;
logic                                   r_phase;

assign O_FDI_PL_VALID       = I_PHY_TYPE ? I_FDI_PL_1_VALID       : (r_phase & I_FDI_PL_0_VALID)       ;
assign O_FDI_PL_DATA        = I_PHY_TYPE ? I_FDI_PL_1_DATA        : {I_FDI_PL_0_DATA, r_fdi_pl_0_data} ; 
assign O_FDI_PL_FLIT_CANCEL = I_PHY_TYPE ? I_FDI_PL_1_FLIT_CANCEL : I_FDI_PL_0_FLIT_CANCEL;
 
always_ff @(posedge I_CLK or negedge I_RESETN) begin
    if (!I_RESETN) begin
        r_fdi_pl_0_data  <= 'd0;

        r_phase <= 1'b0;
    end else begin
        if(~I_PHY_TYPE) begin
            if(I_FDI_PL_0_VALID)
                r_phase <= ~r_phase;
            if(I_FDI_PL_0_VALID & ~r_phase) begin
                r_fdi_pl_0_data <= I_FDI_PL_0_DATA;
            end
        end

    end
end

endmodule
