`ifndef PICTURE_CONTROL_V
`define PICTURE_CONTROL_V
// Bundled-data mailbox. Source holds a complete word until the destination
// acknowledges it; destination applies only at a frame boundary. Rapid menu
// changes coalesce to the newest value without tearing multi-bit fields.
module picture_control_cdc #(
    parameter integer WIDTH = 16,
    parameter INIT = 16'h1050
) (
    input wire src_clk, dst_clk, rst_n,
    input wire [WIDTH-1:0] requested,
    input wire frame_start,
    output reg [WIDTH-1:0] active
);
    reg [WIDTH-1:0] held, pending;
    reg req, ack;
    (* async_reg="true" *) reg ack1, ack2;
    (* async_reg="true" *) reg req1, req2;
    reg req3;
    always @(posedge src_clk or negedge rst_n) begin
        if(!rst_n) begin held<=INIT; req<=0; ack1<=0; ack2<=0; end
        else begin
            ack1<=ack; ack2<=ack1;
            if(ack2==req && requested!=held) begin held<=requested; req<=~req; end
        end
    end
    always @(posedge dst_clk or negedge rst_n) begin
        if(!rst_n) begin
            req1<=0; req2<=0; req3<=0; ack<=0;
            pending<=INIT; active<=INIT;
        end else begin
            req1<=req; req2<=req1; req3<=req2;
            if(req3!=ack) begin pending<=held; ack<=req3; end
            if(frame_start) active<=pending;
        end
    end
endmodule

// Denoise is declared below under the same include guard.

// Low-cost display denoise in linear RGB, after scaling and before gamma.
// One previous line, read-before-write RAM, plus a horizontal pair average.
// Each channel is blended only below the selected difference threshold so
// strong edges are retained. Off is bit-exact with the same two-cycle delay.
module picture_denoise #(parameter WORDS=480)(
    input wire clk, rst_n, frame_start, valid, last,
    input wire [95:0] data,
    input wire [1:0] strength,
    output reg out_frame_start, out_valid, out_last,
    output reg [95:0] out_data
);
    reg [95:0] line_mem[0:WORDS-1];
    reg [8:0] col;
    reg first_line;
    reg [95:0] previous, current;
    reg [23:0] left_pixel, left_d;
    reg fs_d, valid_d, last_d, first_d, left_edge_d;
    reg [1:0] strength_d;
    wire [8:0] address = frame_start ? 9'd0 : col;
    // No reset on RAM contents: first-line bypass avoids stale-frame pixels.
    always @(posedge clk) if(valid) begin
        previous <= line_mem[address];
        line_mem[address] <= data;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            col<=0; first_line<=1; current<=0; left_pixel<=0; left_d<=0;
            fs_d<=0; valid_d<=0; last_d<=0; first_d<=1; left_edge_d<=1; strength_d<=0;
        end else begin
            fs_d<=frame_start; valid_d<=valid; last_d<=last;
            current<=data; left_d<=left_pixel; strength_d<=strength;
            first_d<=first_line || frame_start; left_edge_d<=(address==0);
            if(frame_start) begin col<=0; first_line<=1; end
            if(valid) begin
                left_pixel<=data[23:0];
                if(last || address==WORDS-1) begin col<=0; first_line<=0; end
                else col<=address+1'b1;
            end
        end
    end
    function [7:0] avg;
        input [7:0] a,b;
        reg [8:0] sum;
        begin sum={1'b0,a}+{1'b0,b}+9'd1; avg=sum[8:1]; end
    endfunction
    function [7:0] blend;
        input [7:0] c, up, left;
        input first;
        input [1:0] level;
        reg [7:0] candidate, delta, threshold;
        reg [9:0] mixed;
        begin
            candidate=first ? avg(c,left) : avg(avg(c,left),up);
            delta=(c>candidate)?c-candidate:candidate-c;
            threshold=(level==1)?8'd8:(level==2)?8'd16:8'd32;
            mixed=(level==1)?({2'b0,c}+{1'b0,c,1'b0}+{2'b0,candidate}+10'd2):
                  (level==2)?({2'b0,c}+{2'b0,candidate}+10'd1):{2'b0,candidate};
            if(level==0 || delta>threshold) blend=c;
            else if(level==1) blend=mixed[9:2];
            else if(level==2) blend=mixed[8:1];
            else blend=mixed[7:0];
        end
    endfunction
    genvar p,c;
    generate for(p=0;p<4;p=p+1) begin: pixels
        for(c=0;c<3;c=c+1) begin: channels
            wire [7:0] left;
            if(p==3) assign left=left_edge_d?current[p*24+c*8+:8]:left_d[c*8+:8];
            else assign left=current[(p+1)*24+c*8+:8];
            always @(posedge clk or negedge rst_n)
                if(!rst_n) out_data[p*24+c*8+:8]<=0;
                else out_data[p*24+c*8+:8]<=blend(current[p*24+c*8+:8],
                    previous[p*24+c*8+:8],left,first_d,strength_d);
        end
    end endgenerate
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin out_frame_start<=0; out_valid<=0; out_last<=0; end
        else begin out_frame_start<=fs_d; out_valid<=valid_d; out_last<=last_d; end
    end
endmodule
`endif
