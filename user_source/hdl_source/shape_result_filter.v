`ifndef SHAPE_RESULT_FILTER_V
`define SHAPE_RESULT_FILTER_V
// Raw results are consumed once; public label/box update together at frame start.
module shape_result_filter #(
    parameter ACQUIRE=5, SWITCH=8, HOLD=3
)(
    input wire clk,rst_n,enable,frame_start,new_result,raw_valid,
    input wire [2:0] raw_type,
    input wire [11:0] x0,y0,x1,y1,
    output reg valid,
    output reg [2:0] kind,
    output reg [11:0] ox0,oy0,ox1,oy1
);
    reg pending,pvalid,locked;
    reg [2:0] pkind,candidate;
    reg [3:0] count,misses,age;
    reg [11:0] ax0,ay0,ax1,ay1;
    reg [11:0] bx0,by0,bx1,by1;
    reg [12:0] prev_cx,prev_cy;
    wire [12:0] cx={1'b0,x0}+{1'b0,x1},cy={1'b0,y0}+{1'b0,y1};
    wire [12:0] dx=(cx>prev_cx)?cx-prev_cx:prev_cx-cx;
    wire [12:0] dy=(cy>prev_cy)?cy-prev_cy:prev_cy-cy;
    wire [12:0] bw={1'b0,x1}-{1'b0,x0}+1,bh={1'b0,y1}-{1'b0,y0}+1;
    wire [12:0] oldw={1'b0,ax1}-{1'b0,ax0}+1,oldh={1'b0,ay1}-{1'b0,ay0}+1;
    wire associated=(count!=0 || locked) && dx<=(oldw>>1)+32 && dy<=(oldh>>1)+32 &&
                    bw*2>=oldw && bw<=oldw*2 && bh*2>=oldh && bh<=oldh*2;
    wire allowed=raw_valid && (raw_type==1 || raw_type==3 || raw_type==4);
    function [11:0] smooth;
        input [11:0] old_value,new_value;
        reg [12:0] sum;
        begin sum={1'b0,old_value}+{1'b0,new_value};smooth=sum[12:1]+((new_value>old_value)&&sum[0]);end
    endfunction
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pending<=0;pvalid<=0;locked<=0;pkind<=0;candidate<=0;count<=0;misses<=0;age<=0;
            valid<=0;kind<=0;ox0<=0;oy0<=0;ox1<=0;oy1<=0;
            ax0<=0;ay0<=0;ax1<=0;ay1<=0;bx0<=0;by0<=0;bx1<=0;by1<=0;prev_cx<=0;prev_cy<=0;
        end else if(!enable)begin
            pending<=0;pvalid<=0;locked<=0;candidate<=0;count<=0;misses<=0;age<=0;valid<=0;kind<=0;
        end else begin
            if(frame_start)begin
                if(age<15)age<=age+1'b1;
                if(pending)begin
                    valid<=pvalid;kind<=pvalid?pkind:0;ox0<=bx0;oy0<=by0;ox1<=bx1;oy1<=by1;pending<=0;
                end
                if(age>=HOLD+2)begin valid<=0;kind<=0;locked<=0;count<=0;pvalid<=0;end
            end
            if(new_result)begin
                age<=0;pending<=1;
                if(allowed)begin
                    prev_cx<=cx;prev_cy<=cy;ax0<=x0;ay0<=y0;ax1<=x1;ay1<=y1;
                    if(!associated)begin
                        locked<=0;pvalid<=0;candidate<=raw_type;count<=1;misses<=0;
                        bx0<=x0;by0<=y0;bx1<=x1;by1<=y1;
                    end else if(locked && raw_type==pkind)begin
                        pvalid<=1;misses<=0;candidate<=raw_type;count<=0;
                        bx0<=smooth(bx0,x0);by0<=smooth(by0,y0);bx1<=smooth(bx1,x1);by1<=smooth(by1,y1);
                    end else begin
                        if(raw_type!=candidate)begin candidate<=raw_type;count<=1;end
                        else if(count<15)count<=count+1'b1;
                        if(raw_type==candidate && count>=(locked?SWITCH:ACQUIRE)-1)begin
                            locked<=1;pvalid<=1;pkind<=raw_type;count<=0;misses<=0;
                            bx0<=x0;by0<=y0;bx1<=x1;by1<=y1;
                        end else if(locked)begin
                            if(misses<HOLD)misses<=misses+1'b1;
                            else pvalid<=0;
                        end
                    end
                end else begin
                    count<=0;candidate<=0;
                    if(misses<HOLD)misses<=misses+1'b1;
                    else begin pvalid<=0;locked<=0;end
                end
            end
        end
    end
endmodule
`endif
