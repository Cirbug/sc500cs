`ifndef MCU_MENU_TABLE_V
`define MCU_MENU_TABLE_V
// MCU display list: 256 32-bit cells per bank, published only on VSYNC.
// One ERAM (512x32); CPU writes the inactive bank, pixel clock reads active.
// 0x00 ID, 04 status {error,valid,busy}, 08 begin (write 0), 0c stream,
// 10 commit. Exactly 256 sequential full-word writes are required.
module mcu_menu_table #(parameter integer PANEL_STYLE=1)(
    input wire apb_clk, rst_n, sel, enable, write,
    input wire [7:0] addr,
    input wire [3:0] strobe,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    input wire clk, vs, hs, de,
    input wire [11:0] x,y,
    input wire [23:0] pixel,
    input wire [6:0] cn_id,
    input wire [4:0] cn_row,cn_col,
    input wire cn_active,
    input wire [23:0] cn_color,
    output reg out_vs,out_hs,out_de,
    output reg [23:0] out_pixel,
    output reg [6:0] out_id,
    output reg [4:0] out_row,out_col,
    output reg out_active,
    output reg [23:0] out_color
);
    reg [31:0] cells [0:511];
    reg req, ack;
    (* async_reg="true" *) reg ack1,ack2,req1,req2;
    reg req3;
    reg [8:0] count;
    reg writing, error;
    reg active_bank, valid, vs_d;
    (* async_reg="true" *) reg valid1,valid2;
    wire busy=(req!=ack2);
    wire access=sel && enable && write;
    // Bank equals the published request bit. Initial writer therefore uses 1.
    always @(posedge apb_clk) begin
        if(access && addr==8'h0c && strobe==4'hf && !busy && writing && count<256)
            cells[{~req,count[7:0]}]<=wdata;
    end
    always @(posedge apb_clk or negedge rst_n) begin
        if(!rst_n) begin
            req<=0;ack1<=0;ack2<=0;valid1<=0;valid2<=0;
            count<=0;writing<=0;error<=0;
        end else begin
            ack1<=ack;ack2<=ack1;valid1<=valid;valid2<=valid1;
            if(access) begin
                if(strobe!=4'hf) error<=1;
                else case(addr)
                    8'h08: if(!busy && wdata==0) begin count<=0;writing<=1;error<=0;end
                            else error<=1;
                    8'h0c: if(!busy && writing && count<256) count<=count+1'b1;
                            else error<=1;
                    8'h10: if(!busy && writing && count==256 && !error) begin
                                req<=~req;writing<=0;
                            end else error<=1;
                    default: ;
                endcase
            end
        end
    end
    always @* begin
        case(addr)
            0:rdata=32'h4d554931; // MUI1
            4:rdata={29'd0,error,valid2,busy};
            8:rdata={23'd0,count};
            default:rdata=0;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin req1<=0;req2<=0;req3<=0;ack<=0;active_bank<=0;valid<=0;vs_d<=0;end
        else begin
            req1<=req;req2<=req1;req3<=req2;vs_d<=vs;
            if(vs && !vs_d && req3!=ack) begin active_bank<=req3;ack<=req3;valid<=1;end
        end
    end
    // The layout is a small reusable character grid. Page names, values,
    // selection, visibility and bar widths are entirely MCU data.
    reg [3:0] line_id,cell_id;
    reg [11:0] dy,dx;
    reg [1:0] region;
    reg border,text_hit,bar_hit;
    always @* begin
        line_id=0;cell_id=0;dx=0;dy=0;region=0;border=0;text_hit=0;bar_hit=0;
        if(x>=24 && x<492 && y>=644 && y<1004) begin
            region=1;dy=y-656;
            if(y>=944) begin line_id=8;dy=y-944;end
            else if(y>=908) begin line_id=7;dy=y-908;end
            else if(y>=872) begin line_id=6;dy=y-872;end
            else if(y>=836) begin line_id=5;dy=y-836;end
            else if(y>=800) begin line_id=4;dy=y-800;end
            else if(y>=764) begin line_id=3;dy=y-764;end
            else if(y>=728) begin line_id=2;dy=y-728;end
            else if(y>=692) begin line_id=1;dy=y-692;end
            border=PANEL_STYLE ? (x<26 || x>=490 || y<646 || y>=1002) :
                                 (x<28 || x>=488 || y<648 || y>=1000);
            if(x>=44 && x<300) begin dx=x-44;cell_id=dx[7:5];text_hit=(dy>=2 && dy<34);end
            if(x>=330 && x<458) begin
                dx=x-330;cell_id=8+{2'd0,dx[6:5]};
                text_hit=(dy>=2 && dy<34);bar_hit=(dy>=12 && dy<24);
            end
        end else if(x>=24 && x<220 && y>=1016 && y<1076) begin
            region=2;line_id=9;dx=x-90;dy=y-1028;
            border=PANEL_STYLE ? (x<26 || x>=218 || y<1018 || y>=1074) :
                                 (x<28 || x>=216 || y<1020 || y>=1072);
            if(x>=90 && x<154 && dy>=2 && dy<34) begin cell_id={3'd0,dx[5]};text_hit=1;end
        end else if(x>=236 && x<260 && y>=1034 && y<1058) begin region=3;line_id=10;end
    end
    reg [31:0] desc;
    reg [1:0] region_d;
    reg border_d,text_d,bar_d,valid_d,accent_d;
    reg [6:0] dx_d;
    reg [4:0] col_d;
    reg [5:0] dy_d;
    reg [23:0] pixel_d,color_d;
    reg [6:0] id_d;
    reg [4:0] row_d,cncol_d;
    reg active_d;
    /* 2026-10-27：行号也打一拍，与 desc/dy_d 对齐（本模块流水线只有一级），
     * 用来给第一行（标题+"返回"）单独上色。 */
    reg [3:0] line_d;
    always @(posedge clk) desc<=cells[{active_bank,line_id,cell_id}];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_vs<=0;out_hs<=0;out_de<=0;region_d<=0;border_d<=0;text_d<=0;bar_d<=0;valid_d<=0;accent_d<=0;
            dx_d<=0;col_d<=0;dy_d<=0;pixel_d<=0;color_d<=0;id_d<=0;row_d<=0;cncol_d<=0;active_d<=0;
            line_d<=0;
        end else begin
            out_vs<=vs;out_hs<=hs;out_de<=de;
            region_d<=region;border_d<=border;text_d<=text_hit;bar_d<=bar_hit;valid_d<=valid;
            accent_d<=x>=32 && x<36;
            dx_d<=dx[6:0];col_d<=dx[4:0];dy_d<=dy[5:0];pixel_d<=pixel;
            color_d<=cn_color;id_d<=cn_id;row_d<=cn_row;cncol_d<=cn_col;active_d<=cn_active;
            line_d<=line_id;
        end
    end
    // Horizontal exponential softening, alpha=1/4, Q8.2 history.
    // No line RAM/DDR; only the background uses it. Foreground and video
    // outside the panel retain their original pixels and pipeline latency.
    reg [9:0] blur_r,blur_g,blur_b;
    reg blur_valid;
    reg [23:0] blur_pixel_d;
    wire [9:0] next_r=blur_r-{2'b0,blur_r[9:2]}+{2'b0,pixel[23:16]};
    wire [9:0] next_g=blur_g-{2'b0,blur_g[9:2]}+{2'b0,pixel[15:8]};
    wire [9:0] next_b=blur_b-{2'b0,blur_b[9:2]}+{2'b0,pixel[7:0]};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            blur_r<=0;blur_g<=0;blur_b<=0;blur_valid<=0;blur_pixel_d<=0;
        end else begin
            blur_valid<=de && !vs;
            if(!blur_valid || !de || vs || x==0) begin
                blur_r<={pixel[23:16],2'b0};blur_g<={pixel[15:8],2'b0};blur_b<={pixel[7:0],2'b0};
                blur_pixel_d<=pixel;
            end else begin
                blur_r<=next_r;blur_g<=next_g;blur_b<=next_b;
                blur_pixel_d<={next_r[9:2],next_g[9:2],next_b[9:2]};
            end
        end
    end
    function [23:0] palette;
        input [2:0] c;
        begin if(PANEL_STYLE) case(c)
            0:palette=24'he8edf2;1:palette=24'h50d8c0;2:palette=24'h50d8c0;3:palette=24'h50d8c0;
            4:palette=24'hf06464;5:palette=24'hffb454;6:palette=24'h62c78e;default:palette=24'h62c78e;
        endcase else case(c)
            0:palette=24'hffffff;1:palette=24'h80e0c0;2:palette=24'h40d080;3:palette=24'hd0c040;
            4:palette=24'hff3020;5:palette=24'hffb020;6:palette=24'h305040;default:palette=24'hff2020;
        endcase end
    endfunction
    `include "ui_ascii_glyph.vh"
    reg [4:0] bits;
    reg [5:0] glyph_y;
    reg [23:0] tint;
    always @* begin
        out_pixel=pixel_d;out_id=id_d;out_row=row_d;out_col=cncol_d;out_active=active_d;out_color=color_d;
        bits=0;glyph_y=dy_d-4;tint=24'h101820;
        if(valid_d && desc[23] && region_d!=0) begin
            out_active=0;
            out_pixel=region_d==2?(PANEL_STYLE?24'h162832:24'h183050):24'h101820;
            if(region_d==1 && dy_d<36) case(desc[13:12])
                1:out_pixel=PANEL_STYLE?24'h203c50:24'h205080;
                2:out_pixel=PANEL_STYLE?24'h604020:24'hd08020;default:;
            endcase
            // Softened camera background plus translucent theme tint.
            // Per-channel half camera + half theme; sums cannot overflow.
            tint=out_pixel;
            if(PANEL_STYLE && region_d!=3) begin
                out_pixel[23:16]={1'b0,blur_pixel_d[23:17]}+{1'b0,tint[23:17]};
                out_pixel[15:8] ={1'b0,blur_pixel_d[15:9]} +{1'b0,tint[15:9]};
                out_pixel[7:0]  ={1'b0,blur_pixel_d[7:1]}  +{1'b0,tint[7:1]};
            end
            if(PANEL_STYLE && region_d==1 && dy_d==35)out_pixel=24'h263540;
            if(PANEL_STYLE && region_d==1 && accent_d && dy_d<35 && desc[13:12]!=0)
                out_pixel=desc[13:12]==2?24'hffb454:24'h50d8c0;
            if(border_d)out_pixel=PANEL_STYLE?(region_d==2?24'h50d8c0:24'h304652):24'h3090d0;
            if(region_d==3)out_pixel=palette(desc[11:9]);
            if(desc[14] && (desc[24]?(dy_d>=25 && dy_d<31):bar_d))out_pixel=
                (dx_d<desc[22:16] || (desc[24] && desc[22:16]==127))?palette(desc[11:9]):
                PANEL_STYLE?24'h263b48:desc[15]?24'h504820:24'h304050;
            if(text_d && !border_d && desc[24] && desc[8]) begin
                glyph_y=dy_d-3;
                bits=glyph_bits(desc[7:0],glyph_y[3:1]);
                if(dy_d>=3 && dy_d<17 && col_d>=10 && col_d<20 && bits[4-((col_d-10)>>1)])
                    out_pixel=(line_d==0)?24'hfff200:palette(desc[11:9]);   /* 首行黄色 */
            end
            if(text_d && !border_d && !desc[14]) begin
                if(desc[8]) begin
                    bits=glyph_bits(desc[7:0],glyph_y[4:2]);
                    if(dy_d>=4 && dy_d<32 && col_d<20 && bits[4-col_d[4:2]])out_pixel=(line_d==0)?24'hfff200:palette(desc[11:9]);   /* 首行黄色 */
                end else begin
                    out_id=desc[6:0];out_row=dy_d-2;out_col=col_d;
                    out_active=1;out_color=(line_d==0)?24'hfff200:palette(desc[11:9]);   /* 首行黄色 */
                end
            end
        end
    end
endmodule
`endif
