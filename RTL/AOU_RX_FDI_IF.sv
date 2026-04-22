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
//  Module     : AOU_RX_FDI_IF
//  Version    : 1.00
//  Date       : 26-02-26
//  Author     : Soyoung Min, Jaeyun Lee, Hojun Lee, Kwanho Kim
//
// *****************************************************************************

`timescale 1ns/1ps

module AOU_RX_FDI_IF #(
  parameter FDI_IF_WD = 1024
)
(
    input I_CLK,
    input I_RESETN,

    //------------------------------------------------------------
    //AOU_RX_CORE Interface
    //------------------------------------------------------------
    output                          O_AOU_RX_CHUNK_DATA_VALID,
    output      [FDI_IF_WD-1:0]     O_AOU_RX_CHUNK_DATA,

    //------------------------------------------------------------
    //FDI Interface
    //------------------------------------------------------------
    input                           I_FDI_PL_VALID,
    input logic [FDI_IF_WD-1:0]     I_FDI_PL_DATA,
    input                           I_FDI_PL_FLIT_CANCEL

);
    localparam PHASE_CNT    = 256*8 / FDI_IF_WD;
    localparam HF_PHASE_CNT = (PHASE_CNT == 1) ? 1 : PHASE_CNT/2;
    localparam PHASE_WD     = (PHASE_CNT == 1) ? 1 : $clog2(PHASE_CNT);
    
    logic   [PHASE_WD-1:0]  r_phase;
    logic                   r_half_flit_phase;
    logic   [HF_PHASE_CNT-1:0][FDI_IF_WD-1:0]   r_data;
    logic   [FDI_IF_WD-1:0]                     zero_data;
    logic   [HF_PHASE_CNT-1:0]                  r_data_valid;

    generate
        if(PHASE_CNT == 4) begin :gen_64B_phase
    always_ff @(posedge I_CLK or negedge I_RESETN) begin
        if (!I_RESETN) begin
            r_phase <= 'd0;
            r_half_flit_phase <= 1'b1;
        end else begin
            if(I_FDI_PL_VALID) begin
                if(!I_FDI_PL_FLIT_CANCEL)
                    r_phase <= r_phase + 1;
                else
                    r_phase <= r_phase - 1;
            end else if(I_FDI_PL_FLIT_CANCEL)
                r_phase <= r_phase -2;

            if(((r_phase == 2'b00) | (r_phase == 2'b10)) && I_FDI_PL_VALID)
                r_half_flit_phase <= 1'b0;
            else if(((r_phase == 2'b01) | (r_phase == 2'b11)) && I_FDI_PL_VALID)
                r_half_flit_phase <= 1'b1;
        end
    end 
        end
    endgenerate 

    assign zero_data = 'd0;
    generate
        if(PHASE_CNT == 4) begin :gen_64B
    always_ff @(posedge I_CLK or negedge I_RESETN) begin
        if(!I_RESETN) begin
            r_data <= 'd0;
            r_data_valid <= 'd0;
        end else begin
            if(I_FDI_PL_VALID) begin
                if(I_FDI_PL_FLIT_CANCEL) begin
                    r_data <= {zero_data, I_FDI_PL_DATA};
                    r_data_valid <= {1'b0, 1'b1};
                end else begin
                    r_data <= {r_data[0], I_FDI_PL_DATA};
                    r_data_valid <= {r_data_valid[0], 1'b1};
                end
            end else begin
                if(I_FDI_PL_FLIT_CANCEL) begin
                    r_data <= 'd0;
                    r_data_valid <= 'd0;
                end else begin
                    if(!r_half_flit_phase)
                        r_data_valid <= {1'b0, r_data_valid[0]};
                    else begin
                        r_data <= {r_data[0], zero_data};
                        r_data_valid <= {r_data_valid[0], 1'b0};
                    end
                end
            end
        end
    end
        end else if(PHASE_CNT <= 2) begin
            always_ff @(posedge I_CLK or negedge I_RESETN) begin
                if(!I_RESETN) begin
                    r_data <= 'd0;
                    r_data_valid <= 'd0;
                end else begin
                    if(I_FDI_PL_VALID) begin
                        r_data <= I_FDI_PL_DATA;
                        r_data_valid <= 1'b1;
                    end else begin
                        r_data <= 'd0;
                        r_data_valid <= 'd0;
                    end
                end
            end
        end
    endgenerate
    
    generate
        if(PHASE_CNT == 4) begin
    assign O_AOU_RX_CHUNK_DATA_VALID = (r_data_valid[1] && !I_FDI_PL_FLIT_CANCEL);
    assign O_AOU_RX_CHUNK_DATA = r_data[1];
        end else if(PHASE_CNT <= 2) begin
            assign O_AOU_RX_CHUNK_DATA_VALID = (r_data_valid && !I_FDI_PL_FLIT_CANCEL);
            assign O_AOU_RX_CHUNK_DATA = r_data ;
        end
    endgenerate
endmodule
    
