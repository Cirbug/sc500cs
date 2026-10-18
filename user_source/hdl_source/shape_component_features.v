`ifndef SHAPE_COMPONENT_FEATURES_V
`define SHAPE_COMPONENT_FEATURES_V
// Per-component row spans. One small synchronous RAM replaces the old global
// 128-pixel-high bins; disconnected clutter never contributes to these spans.
module shape_component_features #(
    parameter XB=7, YB=7, GW=120, GH=68
)(
    input wire clk, rst_n, enable, start, point_valid, evaluate,
    input wire [XB-1:0] point_x, min_x, max_x,
    input wire [YB-1:0] point_y, min_y, max_y,
    input wire [15:0] area,
    output wire ready,
    output reg done,
    output reg [2:0] kind
);
    localparam IDLE=0, CLEAR=1, SEED=2, ADDR=3, WAIT_RD=4, LOAD=5, CLASSIFY=6;
    reg [2:0] state;
    reg [YB-1:0] clear_y, read_y, seed_y;
    reg [XB-1:0] seed_x;
    reg [2:0] slot;
    reg [XB:0] w[0:6];
    reg [XB:0] bw;
    reg [YB:0] bh;
    reg geometry;
    (* ram_style="bram" *) reg [2*XB:0] rows [0:(1<<YB)-1];
    reg [2*XB:0] row_q;
    wire [YB-1:0] row_addr=(state==ADDR || state==WAIT_RD || state==LOAD) ? read_y : point_y;
    wire seen=row_q[2*XB];
    wire [XB-1:0] lo=row_q[XB-1:0], hi=row_q[2*XB-1:XB];
    always @(posedge clk) begin
        row_q<=rows[row_addr];
        if(enable) begin
            if(state==CLEAR) rows[clear_y]<=0;
            else if(state==SEED) rows[seed_y]<={1'b1,seed_x,seed_x};
            else if(state==IDLE && point_valid && !start)
                rows[point_y]<={1'b1,(!seen || point_x>hi)?point_x:hi,
                                      (!seen || point_x<lo)?point_x:lo};
        end
    end
    assign ready=(state==IDLE);
    function [YB-1:0] sample_row;
        input [2:0] n;
        input [YB:0] h;
        input [YB-1:0] y;
        reg [YB+3:0] span;
        begin
            // Constant shifts/adds, not a variable multiplier.
            span=h-1'b1;
            case(n)
                0:span=span;
                1:span=span<<1;
                2:span=(span<<1)+span;
                3:span=span<<2;
                4:span=(span<<2)+span;
                5:span=(span<<2)+(span<<1);
                default:span=(span<<3)-span;
            endcase
            sample_row=y+(span>>3);
        end
    endfunction
    function [XB+2:0] difference;
        input [XB+2:0] a,b;
        begin difference=(a>b)?a-b:b-a; end
    endfunction
    wire [XB+2:0] tol=2+(bw>>4);
    wire [XB+2:0] mid2={w[3],1'b0};
    wire [XB+2:0] sum06={2'b0,w[0]}+{2'b0,w[6]};
    wire [XB+2:0] sum15={2'b0,w[1]}+{2'b0,w[5]};
    wire increasing=(w[0]<=w[1]+1 && w[1]<=w[2]+1 && w[2]<=w[3]+1 &&
                     w[3]<=w[4]+1 && w[4]<=w[5]+1 && w[5]<=w[6]+1);
    wire decreasing=(w[6]<=w[5]+1 && w[5]<=w[4]+1 && w[4]<=w[3]+1 &&
                     w[3]<=w[2]+1 && w[2]<=w[1]+1 && w[1]<=w[0]+1);
    wire rectangle=(difference(w[0],bw)<=tol && difference(w[1],bw)<=tol &&
                    difference(w[2],bw)<=tol && difference(w[3],bw)<=tol &&
                    difference(w[4],bw)<=tol && difference(w[5],bw)<=tol && difference(w[6],bw)<=tol);
    wire circle=(difference(w[0],w[6])<=tol && difference(w[1],w[5])<=tol &&
                 difference(w[2],w[4])<=tol && difference(w[3],bw)<=tol &&
                 (w[0]*8>=w[3]*4) && (w[6]*8>=w[3]*4) &&
                 (w[0]*8<=w[3]*7) && (w[6]*8<=w[3]*7) &&
                 (w[1]*4>=w[3]*3) && (w[5]*4>=w[3]*3) &&
                 w[0]<=w[1] && w[1]<=w[2]+1 && w[2]<=w[3]+1 &&
                 w[6]<=w[5] && w[5]<=w[4]+1 && w[4]<=w[3]+1 &&
                 bw*2<=bh*3 && bh*2<=bw*3);
    // A linear taper alone also fits a trapezoid. Its extrapolated apex must
    // be near zero width: the middle span is approximately half the base.
    wire triangle=(difference(mid2,bw)<=tol &&
                   difference(sum06,mid2)<=tol && difference(sum15,mid2)<=tol &&
                   ((increasing && w[0]*8<=bw*3 && w[6]*4>=bw*3) ||
                    (decreasing && w[6]*8<=bw*3 && w[0]*4>=bw*3)));
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;clear_y<=0;read_y<=0;seed_x<=0;seed_y<=0;slot<=0;
            bw<=0;bh<=0;geometry<=0;done<=0;kind<=0;
            for(i=0;i<7;i=i+1)w[i]<=0;
        end else if(!enable) begin state<=IDLE;done<=0;kind<=0;end
        else begin
            done<=0;
            case(state)
                IDLE: if(start) begin
                    seed_x<=point_x;seed_y<=point_y;clear_y<=0;state<=CLEAR;
                end else if(evaluate) begin
                    bw<={1'b0,max_x}-{1'b0,min_x}+1'b1;
                    bh<={1'b0,max_y}-{1'b0,min_y}+1'b1;
                    geometry<=area>=32 && min_x>0 && min_y>0 && max_x<GW-1 && max_y<GH-1;
                    slot<=0;read_y<=sample_row(0,{1'b0,max_y}-{1'b0,min_y}+1'b1,min_y);state<=ADDR;
                end
                CLEAR: if(clear_y==GH-1)state<=SEED;else clear_y<=clear_y+1'b1;
                SEED:state<=IDLE;
                ADDR:state<=WAIT_RD;
                WAIT_RD:state<=LOAD;
                LOAD:begin
                    w[slot]<=seen ? {1'b0,hi}-{1'b0,lo}+1'b1 : 0;
                    if(!seen)geometry<=0;
                    if(slot==6)state<=CLASSIFY;
                    else begin slot<=slot+1'b1;read_y<=sample_row(slot+1'b1,bh,min_y);state<=ADDR;end
                end
                CLASSIFY:begin
                    kind<=0;
                    if(geometry && bw>=8 && bh>=8 && bw*3>=bh && bh*3>=bw) begin
                        // Only three public IDs. Double-ended taper (diamond)
                        // cannot enter the monotonic triangle branch.
                        if(rectangle)kind<=1;
                        else if(circle)kind<=3;
                        else if(triangle)kind<=4;
                    end
                    done<=1;state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
`endif
