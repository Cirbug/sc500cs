`ifndef CNN_DIGIT_OVERLAY_V
`define CNN_DIGIT_OVERLAY_V
// Double-buffered 320x180 one-bit overlay, expanded 6x. A sequential builder
// clears and draws in <75k clocks. Publish at VSYNC only, including empty groups.
// Two cycles of video latency. No camera/display backpressure.
module cnn_digit_overlay(
    input wire clk,rst_n,enable,result_valid,result_busy,
    input wire [4:0] result_count,input wire [15:0] result_generation,
    input wire [639:0] result_records,
    input wire vs,hs,de,input wire [23:0] rgb,
    output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
    reg bitmap[0:131071];
    reg display_bank,build_bank,display_valid,ready,built_valid;
    reg [2:0] state;
    localparam IDLE=0,CLEAR=1,LOAD=2,SETUP=3,HEDGE=4,VEDGE=5,TEXT=6;
    reg [4:0] held_count;
    reg [15:0] held_generation;
    reg [3:0] record_index;
    reg [39:0] record_data;
    reg [15:0] clear_index;
    reg [8:0] x0,x1,cx,label_x;
    reg [7:0] y0,y1,cy,label_y;
    reg phase;
    reg [2:0] font_x,font_y;
    reg [3:0] digit;
    reg vs_d,de_d;
    reg [8:0] sx;
    reg [7:0] sy;
    reg [2:0] x_repeat,y_repeat;
    reg vs_p,hs_p,de_p,ink;
    reg [23:0] rgb_p;
    wire frame_start=vs&&!vs_d;
    function [34:0] font;
        input [3:0] d;
        begin case(d)
        0:font=35'b01110_10001_10011_10101_11001_10001_01110;
        1:font=35'b00100_01100_00100_00100_00100_00100_01110;
        2:font=35'b01110_10001_00001_00010_00100_01000_11111;
        3:font=35'b11110_00001_00001_01110_00001_00001_11110;
        4:font=35'b00010_00110_01010_10010_11111_00010_00010;
        5:font=35'b11111_10000_10000_11110_00001_00001_11110;
        6:font=35'b01110_10000_10000_11110_10001_10001_01110;
        7:font=35'b11111_00001_00010_00100_01000_01000_01000;
        8:font=35'b01110_10001_10001_01110_10001_10001_01110;
        9:font=35'b01110_10001_10001_01111_00001_00001_01110;
        default:font=0;endcase end
    endfunction
    wire [34:0] glyph=font(digit);
    reg write_en,write_data;
    reg [15:0] write_addr;
    reg [8:0] wx;
    reg [7:0] wy;
    always @*begin
        write_en=0;write_data=1;write_addr=0;wx=0;wy=0;
        case(state)
        CLEAR:begin write_en=1;write_data=0;write_addr=clear_index;end
        HEDGE:begin write_en=1;wx=cx;wy=phase?y1:y0;end
        VEDGE:begin write_en=1;wx=phase?x1:x0;wy=cy;end
        TEXT:begin
            wx=label_x+font_x;wy=label_y+font_y;
            write_en=glyph[34-(font_y*5+font_x)];
        end
        endcase
        if(state!=CLEAR)write_addr=wy*16'd320+wx;
    end
    // Single write port and single synchronous read port infer ERAM.
    wire [15:0] read_addr=sy*16'd320+sx;
    always @(posedge clk)begin
        if(write_en)bitmap[{build_bank,write_addr}]<=write_data;
        ink<=bitmap[{display_bank,read_addr}];
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            display_bank<=0;build_bank<=1;display_valid<=0;ready<=0;built_valid<=0;
            state<=IDLE;held_count<=0;held_generation<=0;record_index<=0;record_data<=0;
            clear_index<=0;x0<=0;x1<=0;y0<=0;y1<=0;cx<=0;cy<=0;label_x<=0;label_y<=0;
            phase<=0;font_x<=0;font_y<=0;digit<=0;
        end else begin
            if(frame_start)begin
                if(ready)begin
                    if(!result_busy&&result_generation==held_generation)begin
                        display_bank<=build_bank;display_valid<=built_valid;
                    end
                    ready<=0;
                end
                if(state==IDLE&&!result_busy)begin
                    build_bank<=(ready&&(result_generation==held_generation))?display_bank:~display_bank;
                    held_generation<=result_generation;
                    held_count<=enable&&result_valid?result_count:0;
                    built_valid<=enable&&result_valid;
                    clear_index<=0;record_index<=0;state<=CLEAR;
                end
            end
            if(state!=IDLE && (result_busy||result_generation!=held_generation))begin
                state<=IDLE;ready<=0;built_valid<=0;
            end else case(state)
            CLEAR:if(clear_index==57599)begin
                if(held_count==0)begin ready<=1;state<=IDLE;end else state<=LOAD;
            end else clear_index<=clear_index+1'b1;
            LOAD:begin record_data<=result_records[record_index*40+:40];state<=SETUP;end
            SETUP:begin
                x0<=record_data[39:31];x1<=record_data[39:31]+record_data[22:14]-9'd1;
                y0<=record_data[30:23];y1<=record_data[30:23]+record_data[13:6]-8'd1;
                cx<=record_data[39:31];cy<=record_data[30:23];digit<=record_data[5:2];
                label_x<=record_data[39:31]>315?9'd315:record_data[39:31];
                label_y<=record_data[30:23]>=7?record_data[30:23]-7'd7:8'd0;
                phase<=0;state<=HEDGE;
            end
            HEDGE:begin
                phase<=~phase;
                if(phase)begin if(cx==x1)state<=VEDGE;else cx<=cx+1'b1;end
            end
            VEDGE:begin
                phase<=~phase;
                if(phase)begin
                    if(cy==y1)begin font_x<=0;font_y<=0;state<=TEXT;end
                    else cy<=cy+1'b1;
                end
            end
            TEXT:if(font_x==4)begin
                font_x<=0;
                if(font_y==6)begin
                    if({1'b0,record_index}+1'b1>=held_count)begin ready<=1;state<=IDLE;end
                    else begin record_index<=record_index+1'b1;state<=LOAD;end
                end else font_y<=font_y+1'b1;
            end else font_x<=font_x+1'b1;
            endcase
        end
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            vs_d<=0;de_d<=0;sx<=0;sy<=0;x_repeat<=0;y_repeat<=0;
            vs_p<=0;hs_p<=0;de_p<=0;rgb_p<=0;
            out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
        end else begin
            vs_d<=vs;de_d<=de;
            if(frame_start)begin sx<=0;sy<=0;x_repeat<=0;y_repeat<=0;end
            else if(de)begin
                if(x_repeat==5)begin x_repeat<=0;sx<=sx+1'b1;end else x_repeat<=x_repeat+1'b1;
            end else begin
                sx<=0;x_repeat<=0;
                if(de_d)begin
                    if(y_repeat==5)begin y_repeat<=0;sy<=sy+1'b1;end else y_repeat<=y_repeat+1'b1;
                end
            end
            vs_p<=vs;hs_p<=hs;de_p<=de;rgb_p<=rgb;
            out_vs<=vs_p;out_hs<=hs_p;out_de<=de_p;
            out_rgb<=(de_p&&ink&&display_valid&&enable&&result_valid)?24'h00ff60:rgb_p;
        end
    end
endmodule
`endif
