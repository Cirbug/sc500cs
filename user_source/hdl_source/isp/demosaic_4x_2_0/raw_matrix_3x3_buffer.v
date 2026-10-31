`timescale 1ns/1ps
// Based on Milianke's 2024/10 four-pixel demosaic line-buffer interface.
// Center windows on the output row; reflect same-color Bayer neighbors at
// borders. An internal final row reads the tail from the existing two RAMs.
module raw_matrix_3x3_buffer #(
    parameter IMG_HEIGHT=1080, IMG_WIDTH=1920,
    parameter data_complete_delay=50 // Retained for source compatibility.
)(
    input I_clk, I_rst_n,
    input [39:0] axi4s_video_tdata,
    input [9:0] axi4s_video_tdest,
    input axi4s_video_tlast, axi4s_video_tvalid, axi4s_video_tuser,
    output axi4s_video_tready,
    output reg O_tlast, O_tuser, O_tvalid,
    input O_tready,
    output reg bayer_ypos,
    output reg [95:0] matrix_last_line, matrix_cur_line, matrix_next_line
);
    localparam WORDS=IMG_WIDTH/4;
    wire [31:0] raw_data;
    wire raw_valid, raw_sof;
    // Top level holds O_tready high; the camera cannot be backpressured.
    assign axi4s_video_tready=O_tready;
    mipi_to_raw_converter unpack (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_raw_tdata(axi4s_video_tdata),
        .I_raw_tdest(axi4s_video_tdest),.I_raw_tlast(axi4s_video_tlast),
        .I_raw_tvalid(axi4s_video_tvalid),.I_raw_tuser(axi4s_video_tuser),
        .I_raw_tready(),.O_raw_tdata(raw_data),.O_raw_tlast(),
        .O_raw_tvalid(raw_valid),.O_raw_tuser(raw_sof),.O_raw_tready(1'b1));

    // Valid groups drive the buffers directly: no previous-frame timing guess
    // or zhenghe repacking RAM is needed for this lookahead window builder.
    reg [10:0] src_x,src_y,tail_x;
    reg tail_active,frame_active;
    wire new_frame=raw_valid && raw_sof;
    wire feed_valid=(raw_valid && (frame_active || raw_sof)) || tail_active;
    wire feed_tail=tail_active && !new_frame;
    wire [10:0] feed_x=new_frame ? 11'd0 : feed_tail ? tail_x : src_x;
    wire [10:0] feed_y=new_frame ? 11'd0 : feed_tail ? IMG_HEIGHT : src_y;
    wire [32:0] feed_data={new_frame,feed_tail ? 32'd0 : raw_data};
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            src_x<=0;src_y<=0;tail_x<=0;tail_active<=0;frame_active<=0;
        end else if(new_frame) begin
            src_x<=WORDS==1 ? 0 : 1;src_y<=WORDS==1 ? 1 : 0;
            tail_active<=0;tail_x<=0;frame_active<=1;
        end else if(tail_active) begin
            if(tail_x==WORDS-1) begin tail_active<=0;tail_x<=0;end
            else tail_x<=tail_x+1'b1;
        end else if(raw_valid && frame_active) begin
            if(src_x==WORDS-1) begin
                src_x<=0;
                if(src_y==IMG_HEIGHT-1) begin
                    tail_active<=1;tail_x<=0;frame_active<=0;
                end else src_y<=src_y+1'b1;
            end else src_x<=src_x+1'b1;
        end
    end
    wire [32:0] line1,line2;
    wire valid1,valid2;
    line_buffer_demosaic #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) lb1 (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_tuser(new_frame),
        .I_valid(feed_valid),.I_data(feed_data),.O_valid(valid1),.O_data(line1));
    line_buffer_demosaic #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) lb2 (
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_tuser(line1[32] && valid1),
        .I_valid(valid1),.I_data(line1),.O_valid(valid2),.O_data(line2));
    // Align metadata and current data with both synchronous RAM reads.
    reg [31:0] current_d0,current_d1,previous_d1;
    reg valid_d0,valid_d1;
    reg [10:0] x_d0,x_d1,y_d0,y_d1;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            current_d0<=0;current_d1<=0;previous_d1<=0;
            valid_d0<=0;valid_d1<=0;x_d0<=0;x_d1<=0;y_d0<=0;y_d1<=0;
        end else begin
            current_d0<=feed_data[31:0];current_d1<=current_d0;
            previous_d1<=line1[31:0];
            valid_d0<=feed_valid;valid_d1<=valid_d0;
            x_d0<=feed_x;x_d1<=x_d0;y_d0<=feed_y;y_d1<=y_d0;
        end
    end
    wire row_valid=valid_d1 && y_d1!=0;
    wire [31:0] upper=y_d1==1 ? current_d1 : line2[31:0];
    wire [31:0] center=previous_d1;
    wire [31:0] lower=y_d1==IMG_HEIGHT ? line2[31:0] : current_d1;
    // One group of lookahead supplies x+4. Final groups drain without another
    // input beat and reflect x=W to x=W-2, never into the next row.
    reg pending;
    reg [10:0] pending_x,pending_y;
    reg [31:0] up_word,mid_word,lo_word;
    reg [7:0] up_left,mid_left,lo_left;
    wire emit=pending && ((pending_x==WORDS-1) || row_valid);
    wire [7:0] up_right=pending_x==WORDS-1 ? up_word[15:8] : upper[31:24];
    wire [7:0] mid_right=pending_x==WORDS-1 ? mid_word[15:8] : center[31:24];
    wire [7:0] lo_right=pending_x==WORDS-1 ? lo_word[15:8] : lower[31:24];
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            pending<=0;pending_x<=0;pending_y<=0;
            up_word<=0;mid_word<=0;lo_word<=0;up_left<=0;mid_left<=0;lo_left<=0;
            O_tvalid<=0;O_tuser<=0;O_tlast<=0;bayer_ypos<=0;
            matrix_last_line<=0;matrix_cur_line<=0;matrix_next_line<=0;
        end else begin
            O_tvalid<=emit;O_tuser<=emit && pending_x==0 && pending_y==0;
            O_tlast<=emit && pending_x==WORDS-1;
            if(emit) begin
                matrix_last_line<={24'd0,up_left,up_word,up_right,24'd0};
                matrix_cur_line<={24'd0,mid_left,mid_word,mid_right,24'd0};
                matrix_next_line<={24'd0,lo_left,lo_word,lo_right,24'd0};
                bayer_ypos<=pending_y[0];
            end
            if(row_valid) begin
                pending<=1;pending_x<=x_d1;pending_y<=y_d1-1'b1;
                up_left<=x_d1==0 ? upper[23:16] : up_word[7:0];
                mid_left<=x_d1==0 ? center[23:16] : mid_word[7:0];
                lo_left<=x_d1==0 ? lower[23:16] : lo_word[7:0];
                up_word<=upper;mid_word<=center;lo_word<=lower;
            end else if(emit) pending<=0;
            if(new_frame) begin pending<=0;O_tvalid<=0;O_tuser<=0;O_tlast<=0;end
        end
    end
`ifndef SYNTHESIS
    always @(posedge I_clk) if(I_rst_n && tail_active && raw_valid)
        $error("Demosaic requires one line of vertical blanking for the final row");
`endif
endmodule
