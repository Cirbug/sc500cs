`ifndef HISTOGRAM_EQUALIZER_V
`define HISTOGRAM_EQUALIZER_V
// HEQ1: sampled global luma histogram, MCU CDF, frame-atomic double-buffer LUT.
// Histogram port A is one synchronous read/write port (samples >=8 clocks apart).
// Port B is APB read-only, used only after capture completion until next request.
module histogram_equalizer(
    input wire rst_n, apb_clk, sel, enable, write,
    input wire [11:0] addr,
    input wire [3:0] strobe,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    input wire clk, vs, hs, de,
    input wire [23:0] rgb,
    output reg out_vs,out_hs,out_de,
    output reg [23:0] out_rgb
);
    reg [15:0] histogram[0:255];
    reg [7:0] mapping[0:511];
    reg capture_req, capture_ack, map_req, map_ack, enable_req;
    (* async_reg="true" *) reg cap_ack1,cap_ack2,map_ack1,map_ack2;
    (* async_reg="true" *) reg cap_req1,cap_req2,map_req1,map_req2;
    (* async_reg="true" *) reg en1,en2,valid1,valid2,cap_valid1,cap_valid2;
    (* async_reg="true" *) reg active1,active2;
    reg map_req3;
    reg map_valid, capture_valid, active_bank, active_enable;
    reg [8:0] map_count;
    reg writing,error;
    wire cap_busy=capture_req!=cap_ack2;
    wire map_busy=map_req!=map_ack2;
    wire access=sel && enable && write;
    wire stream_ok=access && addr==12'h014 && strobe==4'hf &&
                   !map_busy && writing && map_count<256 && wdata[31:8]==0;
    always @(posedge apb_clk)
        if(stream_ok) mapping[{~map_req,map_count[7:0]}]<=wdata[7:0];
    reg [15:0] hist_apb;
    // APB setup phase supplies the address before the access phase consumes it.
    always @(posedge apb_clk) hist_apb<=histogram[addr[9:2]];
    reg [15:0] captured_total;
    always @* begin
        rdata=0;
        if(addr[11:10]==2'b01) rdata={16'd0,hist_apb};
        else case(addr)
            12'h000:rdata=32'h48455131; // HEQ1
            12'h004:rdata={26'd0,active2,error,valid2,cap_valid2,map_busy,cap_busy};
            12'h008:rdata={16'd0,captured_total}; // stable before synchronized ack
            12'h00c:rdata={23'd0,map_count};
            default: ;
        endcase
    end
    always @(posedge apb_clk or negedge rst_n) begin
        if(!rst_n) begin
            capture_req<=0;map_req<=0;enable_req<=0;map_count<=0;writing<=0;error<=0;
            cap_ack1<=0;cap_ack2<=0;map_ack1<=0;map_ack2<=0;
            valid1<=0;valid2<=0;cap_valid1<=0;cap_valid2<=0;active1<=0;active2<=0;
        end else begin
            cap_ack1<=capture_ack;cap_ack2<=cap_ack1;
            map_ack1<=map_ack;map_ack2<=map_ack1;
            valid1<=map_valid;valid2<=valid1;
            cap_valid1<=capture_valid;cap_valid2<=cap_valid1;
            active1<=active_enable;active2<=active1;
            if(access) begin
                if(strobe!=4'hf) error<=1;
                else case(addr)
                    12'h008: if(!cap_busy && wdata==1) capture_req<=~capture_req;
                              else error<=1;
                    12'h010: if(!map_busy && wdata==0) begin
                                  map_count<=0;writing<=1;error<=0;
                              end else error<=1;
                    12'h014: if(stream_ok) map_count<=map_count+1'b1;
                              else error<=1;
                    12'h018: if(!map_busy && writing && map_count==256 && !error && wdata==1) begin
                                  map_req<=~map_req;writing<=0;
                              end else error<=1;
                    12'h01c: enable_req<=wdata[0];
                    default: ;
                endcase
            end
        end
    end

    reg vs_d,de_d;
    reg [10:0] x,y;
    wire frame_start=vs && !vs_d;
    wire [9:0] y_sum={2'd0,rgb[23:16]}+{1'd0,rgb[15:8],1'b0}+{2'd0,rgb[7:0]};
    wire [7:0] luma=y_sum[9:2]; // Y approximately R/4+G/2+B/4
    localparam IDLE=0,CLEAR=1,WAIT_FRAME=2,CAPTURE=3;
    reg [1:0] state;
    reg [7:0] clear_index,bin_d;
    reg wr_pending;
    reg [15:0] hist_q,total;
    wire sample=(state==CAPTURE && de && !frame_start && x[2:0]==0 && y[2:0]==0);
    wire [7:0] hist_address=(state==CLEAR)?clear_index:wr_pending?bin_d:luma;
    always @(posedge clk) begin
        hist_q<=histogram[hist_address];
        if(state==CLEAR) histogram[hist_address]<=0;
        else if(wr_pending) histogram[hist_address]<=hist_q+16'd1;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cap_req1<=0;cap_req2<=0;capture_ack<=0;capture_valid<=0;
            map_req1<=0;map_req2<=0;map_req3<=0;map_ack<=0;
            en1<=0;en2<=0;active_enable<=0;active_bank<=0;map_valid<=0;
            vs_d<=0;de_d<=0;x<=0;y<=0;state<=IDLE;clear_index<=0;
            bin_d<=0;wr_pending<=0;total<=0;captured_total<=0;
        end else begin
            cap_req1<=capture_req;cap_req2<=cap_req1;
            map_req1<=map_req;map_req2<=map_req1;map_req3<=map_req2;
            en1<=enable_req;en2<=en1;
            vs_d<=vs;de_d<=de;wr_pending<=sample;
            if(sample) begin bin_d<=luma;total<=total+16'd1;end
            if(frame_start) begin
                x<=0;y<=0;active_enable<=en2;
                if(map_req3!=map_ack) begin
                    active_bank<=map_req3;map_ack<=map_req3;map_valid<=1;
                end
            end else if(de) x<=x+1'b1;
            else if(de_d) begin x<=0;y<=y+1'b1;end
            case(state)
                IDLE: if(cap_req2!=capture_ack) begin
                    state<=CLEAR;clear_index<=0;capture_valid<=0;total<=0;
                end
                CLEAR: if(clear_index==255) state<=WAIT_FRAME;
                       else clear_index<=clear_index+1'b1;
                WAIT_FRAME: if(frame_start) state<=CAPTURE;
                CAPTURE: if(frame_start) begin
                    captured_total<=total;capture_valid<=1;
                    capture_ack<=cap_req2;state<=IDLE;
                end
            endcase
        end
    end

    // Three registers of latency in both bypass and enabled paths.
    reg [7:0] y0,y1,mapped_y;
    reg [23:0] rgb0,rgb1;
    reg vs0,hs0,de0,vs1,hs1,de1,use0,use1;
    always @(posedge clk) mapped_y<=mapping[{active_bank,y0}];
    wire signed [9:0] delta=$signed({2'b00,mapped_y})-$signed({2'b00,y1});
    function [7:0] shift_channel;
        input [7:0] value;
        input signed [9:0] change;
        reg signed [10:0] sum;
        begin
            sum=$signed({3'b000,value})+change;
            shift_channel=sum<0?8'd0:sum>255?8'd255:sum[7:0];
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            y0<=0;y1<=0;rgb0<=0;rgb1<=0;vs0<=0;hs0<=0;de0<=0;
            vs1<=0;hs1<=0;de1<=0;use0<=0;use1<=0;
            out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
        end else begin
            y0<=luma;rgb0<=rgb;vs0<=vs;hs0<=hs;de0<=de;use0<=active_enable && map_valid;
            y1<=y0;rgb1<=rgb0;vs1<=vs0;hs1<=hs0;de1<=de0;use1<=use0;
            out_vs<=vs1;out_hs<=hs1;out_de<=de1;
            out_rgb<=use1?{shift_channel(rgb1[23:16],delta),
                          shift_channel(rgb1[15:8],delta),shift_channel(rgb1[7:0],delta)}:rgb1;
        end
    end
endmodule
`endif
