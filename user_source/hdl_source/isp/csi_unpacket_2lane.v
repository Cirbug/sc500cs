/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2023/03/23
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/
/*********csi_unpacket_2lane MIPI CSI解码***********
--版本号1.0
--MIPI IP数据解码为32bit数据输出给下一级使用，这里需要了解MIPI协议的数据格式
*********************************************************************/

`timescale 1ns / 1ns

// Board lane order: the earlier byte occupies [15:8]. Parse packets by
// word count, not by HS rising edge: several CSI packets may share one HS
// interval. Only VC0 RAW10 payload reaches the ISP. Header ECC is checked
// (detect/reject, not correct); payload CRC is not checked.
// The aligned PHY valid interval can extend into HS trail. After the first
// packet, 00/FF fill terminates parsing until a new HS edge. FS is permitted
// only as the first packet of an HS burst (board SC500 profile); all-zero
// trail is otherwise indistinguishable from a valid zero-number FS header.
module csi_unpacket_2lane (
    input wire I_clk,I_rst_n,I_hs_valid,
    input wire [15:0] I_hs_data,
    output reg O_csi_frame_start,O_csi_frame_end,O_csi_valid,O_csi_hs,
    output reg [31:0] O_csi_data,
    output reg O_csi_line_end,O_csi_packet_error,
    output reg [63:0] O_csi_packet_fault
);
    localparam HEADER0=3'd0,HEADER1=3'd1,PAYLOAD=3'd2,FOOTER=3'd3,DROP=3'd4;
    reg [2:0] state;
    reg [15:0] header0,header1,remaining,first_half;
    reg raw_packet,half,first_header;
    wire [15:0] byte_count={I_hs_data[15:8],header0[7:0]};
    wire vc0=header0[15:14]==0;
    wire is_raw=vc0 && header0[13:8]==6'h2b;
    wire [23:0] header_bits={I_hs_data[15:8],header0[7:0],header0[15:8]};
    wire [5:0] header_ecc;
    assign header_ecc[0]=^(header_bits & 24'hf12cb7);
    assign header_ecc[1]=^(header_bits & 24'hf2555b);
    assign header_ecc[2]=^(header_bits & 24'h749a6d);
    assign header_ecc[3]=^(header_bits & 24'hb8e38e);
    assign header_ecc[4]=^(header_bits & 24'hdf03f0);
    assign header_ecc[5]=^(header_bits & 24'heffc00);
    wire ecc_ok=I_hs_data[7:6]==0 && I_hs_data[5:0]==header_ecc;
    wire tail_fill=(I_hs_data[15:8]==0 || I_hs_data[15:8]==8'hff) &&
                   (I_hs_data[7:0]==0 || I_hs_data[7:0]==8'hff);
    // Diagnostic only: output accompanies packet_error and cannot affect parsing.
    // High word: valid/raw/first/HS, reason[27:24], state[23:20], remaining[15:0].
    // Low word: four header bytes in wire order. HEADER1 failure uses current input.
    task report_packet_error(input [3:0] reason);
        begin
            O_csi_packet_error<=1;
            O_csi_packet_fault<={1'b1,raw_packet,first_header,I_hs_valid,
                reason,1'b0,state,4'd0,remaining,
                header0,(state==HEADER1 ? I_hs_data:header1)};
        end
    endtask
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=HEADER0;header0<=0;header1<=0;O_csi_packet_fault<=0;remaining<=0;first_half<=0;raw_packet<=0;half<=0;first_header<=1;
            O_csi_frame_start<=0;O_csi_frame_end<=0;O_csi_valid<=0;O_csi_hs<=0;
            O_csi_data<=0;O_csi_line_end<=0;O_csi_packet_error<=0;
        end else begin
            O_csi_frame_start<=0;O_csi_frame_end<=0;O_csi_valid<=0;
            O_csi_line_end<=0;O_csi_packet_error<=0;O_csi_hs<=I_hs_valid;
            if(!I_hs_valid) begin
                // An interrupted packet must not generate pixels in LP/blanking.
                if(state==HEADER1 || state==PAYLOAD || state==FOOTER) begin
                    report_packet_error(state==HEADER1 ? 4'd1 : (state==PAYLOAD ? 4'd2 : 4'd3));
                    if(raw_packet && (state==PAYLOAD || state==FOOTER)) O_csi_line_end<=1;
                end
                state<=HEADER0;raw_packet<=0;half<=0;first_header<=1;
            end else case(state)
                HEADER0: begin
                    // Do not scan past trail for a plausible packet header.
                    // Keep the original HS-edge restriction for frame starts.
                    if(!first_header && (tail_fill || I_hs_data[15:8]==0))
                        state<=DROP;
                    else begin header0<=I_hs_data;state<=HEADER1;end
                end
                HEADER1: begin
                    header1<=I_hs_data;
                    raw_packet<=is_raw;half<=0;first_header<=0;
                    if(!ecc_ok) begin
                        report_packet_error(4'd4);raw_packet<=0;state<=DROP;
                    end else if(header0[13:8]<6'h10) begin
                        O_csi_frame_start<=first_header && vc0 && header0[13:8]==0;
                        O_csi_frame_end<=vc0 && header0[13:8]==1;
                        // FE finishes this burst; no tail can start another frame.
                        state<=(vc0 && header0[13:8]==1) ? DROP:HEADER0;
                    end else if(byte_count[0] || (is_raw && (byte_count==0 || byte_count[1:0]!=0))) begin
                        // This two-byte interface only supports even long packets.
                        // RAW10 image lines must also contain whole 32-bit groups.
                        report_packet_error(4'd5);state<=DROP;
                    end else begin
                        remaining<=byte_count>>1;
                        state<=byte_count==0 ? FOOTER:PAYLOAD;
                    end
                end
                PAYLOAD: begin
                    remaining<=remaining-1'b1;
                    if(raw_packet) begin
                        half<=~half;
                        if(!half) first_half<=I_hs_data;
                        else begin O_csi_data<={first_half,I_hs_data};O_csi_valid<=1;end
                    end
                    if(remaining==1) state<=FOOTER;
                end
                FOOTER: begin
                    // Consume two CRC bytes; the next beat may be another header.
                    O_csi_line_end<=raw_packet;raw_packet<=0;state<=HEADER0;
                end
                default: state<=DROP;
            endcase
        end
    end
endmodule
