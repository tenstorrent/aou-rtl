// *****************************************************************************
// SPDX-License-Identifier: Apache-2.0
// *****************************************************************************
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
// fdi_flit_decoder -- AOU protocol-aware FDI flit logger and decoder
//
// Accumulates FDI bus transfers into a complete 256-byte UCIe Latency-Optimized
// flit, writes raw hex to a log file in 64-byte chunks with granule boundary
// markers, and after each complete flit appends a protocol decode block.
//
// The decode extracts the 10-byte Protocol Header (FDId, MsgStart, MsgCredit)
// and iterates over active MsgStart bits to identify each message by granule
// position and type. Per-message-type detail is provided:
//
//   Misc/Activation  -- ACTIVATIONOP (ActivateReq, ActivateAck, ...)
//   Misc/CrdtGrant   -- per-RP credit counts for all 5 message classes
//   WriteReq/ReadReq -- AxADDR, AxSIZE, AxLEN
//   WriteData/ReadData/WriteDataFull -- DLENGTH (256b/512b/1024b)
//
// Parameters:
//   LOG_FILE   -- output log file path (default "fdi.log")
//   FDI_BYTES  -- FDI bus width in bytes: 32, 64, or 128 (default 64)
//
// Ports:
//   clk, resetn -- clock and active-low reset
//   valid       -- FDI data valid strobe
//   data        -- FDI data bus (FDI_BYTES * 8 bits wide)
//
// *****************************************************************************

module fdi_flit_decoder #(
    parameter string LOG_FILE  = "fdi.log",
    parameter int    FDI_BYTES = 64
) (
    input  logic                    clk,
    input  logic                    resetn,
    input  logic                    valid,
    input  logic [FDI_BYTES*8-1:0]  data
);

    localparam int BEATS_PER_FLIT = 256 / FDI_BYTES;
    localparam int SEQ_MAX        = BEATS_PER_FLIT - 1;

    integer      fd;
    int unsigned seq     = 0;
    int unsigned seq_64  = 0;
    reg [7:0]    flit [0:255];

    initial begin
        fd = $fopen(LOG_FILE, "w");
    end

    function automatic int unsigned decode_cred_3b(input logic [2:0] enc);
        case (enc)
            3'd0: return 0;   3'd1: return 1;   3'd2: return 4;
            3'd3: return 8;   3'd4: return 16;  3'd5: return 32;
            3'd6: return 64;  3'd7: return 128;
        endcase
    endfunction

    function automatic int unsigned decode_cred_2b(input logic [1:0] enc);
        case (enc)
            2'd0: return 0;  2'd1: return 1;
            2'd2: return 4;  2'd3: return 8;
        endcase
    endfunction

    function automatic string msgtype_str(input logic [3:0] mt);
        case (mt)
            4'h0: return "Misc";          4'h1: return "WriteReq";
            4'h2: return "ReadReq";        4'h3: return "WriteData";
            4'h4: return "ReadData";       4'h5: return "WriteResp";
            4'h6: return "WriteDataFull";  default: return "Reserved";
        endcase
    endfunction

    function automatic string miscop_str(input logic [2:0] op);
        case (op)
            3'd2: return "Activation";  3'd4: return "CrdtGrant";
            default: return "Reserved";
        endcase
    endfunction

    function automatic string activationop_str(input logic [3:0] op);
        case (op)
            4'd0: return "ActivateReq";   4'd1: return "ActivateAck";
            4'd2: return "DeactivateReq"; 4'd3: return "DeactivateAck";
            default: return "Reserved";
        endcase
    endfunction

    function automatic string dlength_str(input logic [1:0] dl);
        case (dl)
            2'd0: return "256b";  2'd1: return "512b";
            2'd2: return "1024b"; default: return "Rsvd";
        endcase
    endfunction

    function automatic int unsigned granule_byte_pos(input int unsigned g);
        automatic int unsigned grp  = g / 12;
        automatic int unsigned idx  = g % 12;
        automatic int unsigned base;
        case (grp)
            0: base = 2;   1: base = 66;
            2: base = 130; 3: base = 194;
            default: base = 0;
        endcase
        return base + idx * 5;
    endfunction

    task automatic decode_flit(input integer log_fd, ref reg [7:0] fl [0:255]);
        automatic logic [7:0]  ph [0:9];
        automatic logic [1:0]  fdid;
        automatic logic [47:0] msg_start;
        automatic logic [15:0] msg_credit;
        automatic logic [2:0]  wreqcred, rreqcred, wdatacred, rdatacred;
        automatic logic [1:0]  wrespcred, cred_rp;

        ph[0] = fl[62];  ph[1] = fl[63];
        ph[2] = fl[64];  ph[3] = fl[65];
        ph[4] = fl[128]; ph[5] = fl[129];
        ph[6] = fl[190]; ph[7] = fl[191];
        ph[8] = fl[192]; ph[9] = fl[193];

        fdid = ph[0][1:0];

        msg_start[3:0]   = ph[0][7:4];
        msg_start[11:4]  = ph[1];
        msg_start[15:12] = ph[2][7:4];
        msg_start[23:16] = ph[3];
        msg_start[27:24] = ph[6][7:4];
        msg_start[35:28] = ph[7];
        msg_start[39:36] = ph[8][7:4];
        msg_start[47:40] = ph[9];

        msg_credit = {ph[5], ph[4]};
        wreqcred  = msg_credit[2:0];
        rreqcred  = msg_credit[5:3];
        wdatacred = msg_credit[8:6];
        rdatacred = msg_credit[11:9];
        wrespcred = msg_credit[13:12];
        cred_rp   = msg_credit[15:14];

        $fwrite(log_fd, "  --- Flit Decode ---\n");
        $fwrite(log_fd, "  FDId=%0d MsgStart=%048b\n", fdid, msg_start);
        $fwrite(log_fd, "  MsgCredit: RP=%0d WReq=%0d RReq=%0d WData=%0d RData=%0d WResp=%0d\n",
                cred_rp,
                decode_cred_3b(wreqcred),  decode_cred_3b(rreqcred),
                decode_cred_3b(wdatacred), decode_cred_3b(rdatacred),
                decode_cred_2b(wrespcred));

        for (int g = 0; g < 48; g++) begin
            if (msg_start[g]) begin
                automatic int unsigned bpos = granule_byte_pos(g);
                automatic logic [3:0] mtype = fl[bpos][7:4];
                automatic string mname = msgtype_str(mtype);

                if (mtype == 4'h0) begin
                    automatic logic [2:0] miscop = fl[bpos][3:1];
                    automatic string moname = miscop_str(miscop);
                    $fwrite(log_fd, "  G%0d: MSGTYPE=0x%01h (%s) MISCOP=%0d (%s)",
                            g, mtype, mname, miscop, moname);

                    if (miscop == 3'd4) begin
                        automatic logic [79:0] cg_bits;
                        for (int b = 0; b < 10; b++) cg_bits[(9-b)*8 +: 8] = fl[bpos + b];
                        $fwrite(log_fd, "\n    WReqCred  RP0=%0d RP1=%0d RP2=%0d RP3=%0d",
                                decode_cred_3b(cg_bits[72:70]), decode_cred_3b(cg_bits[69:67]),
                                decode_cred_3b(cg_bits[66:64]), decode_cred_3b(cg_bits[63:61]));
                        $fwrite(log_fd, "\n    RReqCred  RP0=%0d RP1=%0d RP2=%0d RP3=%0d",
                                decode_cred_3b(cg_bits[60:58]), decode_cred_3b(cg_bits[57:55]),
                                decode_cred_3b(cg_bits[54:52]), decode_cred_3b(cg_bits[51:49]));
                        $fwrite(log_fd, "\n    WDataCred RP0=%0d RP1=%0d RP2=%0d RP3=%0d",
                                decode_cred_3b(cg_bits[48:46]), decode_cred_3b(cg_bits[45:43]),
                                decode_cred_3b(cg_bits[42:40]), decode_cred_3b(cg_bits[39:37]));
                        $fwrite(log_fd, "\n    RDataCred RP0=%0d RP1=%0d RP2=%0d RP3=%0d",
                                decode_cred_3b(cg_bits[36:34]), decode_cred_3b(cg_bits[33:31]),
                                decode_cred_3b(cg_bits[30:28]), decode_cred_3b(cg_bits[27:25]));
                        $fwrite(log_fd, "\n    WRespCred RP0=%0d RP1=%0d RP2=%0d RP3=%0d",
                                decode_cred_2b(cg_bits[24:23]), decode_cred_2b(cg_bits[22:21]),
                                decode_cred_2b(cg_bits[20:19]), decode_cred_2b(cg_bits[18:17]));
                    end
                    else if (miscop == 3'd2) begin
                        automatic logic [3:0] actop = {fl[bpos][0], fl[bpos+1][7:5]};
                        $fwrite(log_fd, " ACTIVATIONOP=%0d (%s)", actop, activationop_str(actop));
                    end

                    $fwrite(log_fd, "\n");
                end
                else if (mtype == 4'h1 || mtype == 4'h2) begin
                    automatic int unsigned bp1 = granule_byte_pos(g + 1);
                    automatic int unsigned bp2 = granule_byte_pos(g + 2);
                    automatic logic [2:0]  axsize = fl[bpos + 4][5:3];
                    automatic logic [7:0]  axlen  = fl[bp1];
                    automatic logic [63:0] axaddr;
                    axaddr = {fl[bp1+2], fl[bp1+3], fl[bp1+4],
                              fl[bp2],   fl[bp2+1], fl[bp2+2], fl[bp2+3], fl[bp2+4]};
                    $fwrite(log_fd, "  G%0d: MSGTYPE=0x%01h (%s) ADDR=0x%016h SIZE=0x%01h LEN=0x%02h\n",
                            g, mtype, mname, axaddr, axsize, axlen);
                end
                else if (mtype == 4'h3 || mtype == 4'h4 || mtype == 4'h6) begin
                    automatic logic [1:0] dlength = fl[bpos][1:0];
                    $fwrite(log_fd, "  G%0d: MSGTYPE=0x%01h (%s) DLENGTH=%0d (%s)\n",
                            g, mtype, mname, dlength, dlength_str(dlength));
                end
                else begin
                    $fwrite(log_fd, "  G%0d: MSGTYPE=0x%01h (%s)\n", g, mtype, mname);
                end
            end
        end
    endtask

    task automatic write_64b_line(input integer log_fd, input int unsigned chunk_seq,
                                  ref reg [7:0] fl [0:255], input int unsigned base_byte);
        $fwrite(log_fd, "[%0t] seq=%0d:", $time, chunk_seq);
        for (int i = 0; i < 64; i++) begin
            if (i == 2 || (i > 2 && (i - 2) % 5 == 0))
                $fwrite(log_fd, " |");
            $fwrite(log_fd, " %02h", fl[base_byte + i]);
        end
        $fwrite(log_fd, "\n");
    endtask

    always @(posedge clk) if (resetn && valid) begin
        for (int i = 0; i < FDI_BYTES; i++)
            flit[seq * FDI_BYTES + i] = data[i*8 +: 8];

        for (int c = 0; c < FDI_BYTES / 64; c++) begin
            automatic int unsigned base = seq * FDI_BYTES + c * 64;
            write_64b_line(fd, seq_64, flit, base);
            seq_64 = seq_64 + 1;
        end

        if (FDI_BYTES < 64) begin
            automatic int unsigned end_byte = (seq + 1) * FDI_BYTES;
            if (end_byte % 64 == 0) begin
                automatic int unsigned base = end_byte - 64;
                write_64b_line(fd, seq_64, flit, base);
                seq_64 = seq_64 + 1;
            end
        end

        if (seq == SEQ_MAX) begin
            decode_flit(fd, flit);
            seq    = 0;
            seq_64 = 0;
        end else begin
            seq = seq + 1;
        end
    end

endmodule
