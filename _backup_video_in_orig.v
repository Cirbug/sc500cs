`include "video_params.vh"
// FIFO frames are drained before acknowledgement; write bank never aliases
// the active reader or the latest completed frame.
module video_in #(
    parameter integer FRAME_WORDS=(`PIPE_WIDTH*`PIPE_HEIGHT*3)/16,
    parameter integer STRIDE=`DDR_FRAME_STRIDE_ADDR,
    parameter integer BURST=240,
    parameter REQUIRE_RAW_FRAME=1'b1
)(
    input wire I_rst_n,I_camera_clk,I_camera_frame_start,I_camera_valid,
    input wire [127:0] I_camera_data,
    input wire I_mipi_rx_error,I_camera_frame_done,I_camera_stream_error,
    input wire I_ddr_clk,I_display_pause,I_video_out_rd_busy,
    input wire [1:0] I_reader_bank,
    input wire I_reader_valid,
    output wire O_video_in_wr_busy,
    output reg [1:0] O_video_out_rp,
    output reg O_video_out_valid,
    output reg O_ddr_user_wr_en,
    output reg [24:0] O_ddr_user_addr,
    output wire [127:0] O_ddr_user_wr_data,
    input wire I_ddr_user_ready,
    output wire [31:0] O_frame_counts,
    output wire [31:0] O_capture_diag
);
    reg start_toggle,end_toggle,end_ack;
    (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync,start_sync,end_sync;
    reg start_seen,end_seen,cam_active;
    reg [3:0] warmup;
    reg [19:0] cam_words,cam_received,end_words;
    reg cam_bad,end_bad;
    reg [7:0] cam_flags;
    wire fifo_full,fifo_empty;
    wire [8:0] fifo_words;
    wire accepting=cam_active && !I_camera_frame_start;
    wire fifo_we=accepting && I_camera_valid && cam_words<FRAME_WORDS && !fifo_full;
    wire [19:0] accepted_now=cam_words+fifo_we;
    wire [19:0] received_now=cam_received+(accepting && I_camera_valid);
    wire fifo_re;
    w128_d512_fifo fifo(.rst(!I_rst_n),.clkw(I_camera_clk),.we(fifo_we),.di(I_camera_data),
        .full_flag(fifo_full),.afull(),.wrusedw(),.clkr(I_ddr_clk),.re(fifo_re),
        .dout(O_ddr_user_wr_data),.rdusedw(fifo_words),.empty_flag(fifo_empty),.valid(),.aempty());

    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            start_toggle<=0;end_toggle<=0;ack_sync<=0;cam_active<=0;warmup<=0;
            cam_words<=0;cam_received<=0;end_words<=0;cam_bad<=0;end_bad<=1;cam_flags<=0;
        end else begin
            ack_sync<={ack_sync[0],end_ack};
            if(warmup!=15) warmup<=warmup+1'b1;
            if(I_camera_frame_start) begin
                if(cam_active) begin
                    // Missing EOF: close bad, skip new frame, recover next SOF.
                    end_words<=cam_words;end_bad<=1;end_toggle<=~end_toggle;
                    cam_active<=0;cam_flags[3]<=1;
                end else if(ack_sync[1]==end_toggle && warmup==15) begin
                    start_toggle<=~start_toggle;cam_active<=1;
                    cam_words<=0;cam_received<=0;
                    cam_bad<=I_camera_valid || I_camera_stream_error;
                    if(I_camera_valid) cam_flags[4]<=1;
                end else cam_flags[5]<=1;
            end else if(cam_active) begin
                // Protect the cropped image including its final word. A RAW
                // fault after all visible pixels have arrived remains visible
                // in RX diagnostics but need not discard this complete crop.
                if(I_camera_stream_error && cam_received<FRAME_WORDS) begin
                    cam_bad<=1;cam_flags[2]<=1;
                end
                if(I_camera_valid) begin
                    if(cam_received<FRAME_WORDS+1) cam_received<=cam_received+1'b1;
                    if(fifo_we) cam_words<=cam_words+1'b1;
                    if(fifo_full) begin cam_bad<=1;cam_flags[0]<=1;end
                    if(cam_words>=FRAME_WORDS) begin cam_bad<=1;cam_flags[1]<=1;end
                end
                if(I_camera_frame_done) begin
                    end_words<=accepted_now;
                    end_bad<=cam_bad || (REQUIRE_RAW_FRAME && I_mipi_rx_error) ||
                        (I_camera_stream_error && cam_received<FRAME_WORDS) ||
                        received_now!=FRAME_WORDS || accepted_now!=FRAME_WORDS;
                    if(I_mipi_rx_error) cam_flags[2]<=1;
                    if(received_now!=FRAME_WORDS || accepted_now!=FRAME_WORDS) cam_flags[6]<=1;
                    end_toggle<=~end_toggle;cam_active<=0;
                end
            end
        end
    end

    reg active,ended,burst_active;
    reg [1:0] write_bank;
    reg [8:0] burst_left;
    reg [19:0] popped,final_words;
    reg final_bad;
    reg [15:0] good_count,bad_count;
    (* ASYNC_REG="TRUE" *) reg [7:0] flags_meta,flags_sync;
    reg [1:0] free_bank;
    always @* begin
        if((!I_reader_valid || I_reader_bank!=0) && (!O_video_out_valid || O_video_out_rp!=0)) free_bank=0;
        else if((!I_reader_valid || I_reader_bank!=1) && (!O_video_out_valid || O_video_out_rp!=1)) free_bank=1;
        else free_bank=2;
    end
    function [24:0] bank_base(input [1:0] bank);
        case(bank) 0:bank_base=0;1:bank_base=STRIDE;default:bank_base=2*STRIDE;endcase
    endfunction
    assign O_video_in_wr_busy=burst_active || O_ddr_user_wr_en;
    assign fifo_re=active && burst_active && !fifo_empty && I_ddr_user_ready;
    assign O_frame_counts={bad_count,good_count};
    assign O_capture_diag={16'd0,flags_sync,2'd0,final_bad,ended,active,write_bank,O_video_out_valid};

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            start_sync<=0;end_sync<=0;start_seen<=0;end_seen<=0;end_ack<=0;
            active<=0;ended<=0;burst_active<=0;burst_left<=0;popped<=0;
            final_words<=0;final_bad<=1;write_bank<=0;good_count<=0;bad_count<=0;
            O_video_out_rp<=0;O_video_out_valid<=0;O_ddr_user_wr_en<=0;O_ddr_user_addr<=0;
            flags_meta<=0;flags_sync<=0;
        end else begin
            start_sync<={start_sync[0],start_toggle};end_sync<={end_sync[0],end_toggle};
            flags_meta<=cam_flags;flags_sync<=flags_meta;
            O_ddr_user_wr_en<=fifo_re;
            if(O_ddr_user_wr_en) O_ddr_user_addr<=O_ddr_user_addr+25'd8;
            if(!active && start_sync[1]!=start_seen) begin
                start_seen<=start_sync[1];active<=1;ended<=0;popped<=0;
                write_bank<=free_bank;O_ddr_user_addr<=bank_base(free_bank);
            end
            if(active && end_sync[1]!=end_seen) begin
                // EOF metadata stays stable until end_ack returns to source.
                end_seen<=end_sync[1];ended<=1;final_words<=end_words;final_bad<=end_bad;
            end
            if(active && !burst_active && !O_ddr_user_wr_en && !I_video_out_rd_busy &&
               (fifo_words>=BURST || (ended && popped<final_words && !fifo_empty))) begin
                burst_active<=1;
                if(fifo_words>=BURST) burst_left<=BURST;
                else burst_left<=fifo_words;
            end
            if(fifo_re) begin
                popped<=popped+1'b1;burst_left<=burst_left-1'b1;
                if(burst_left==1) burst_active<=0;
            end
            if(active && ended && popped==final_words && !burst_active && !O_ddr_user_wr_en) begin
                if(!final_bad && popped==FRAME_WORDS && !I_display_pause) begin
                    O_video_out_rp<=write_bank;O_video_out_valid<=1;good_count<=good_count+1'b1;
                end else bad_count<=bad_count+1'b1;
                active<=0;ended<=0;end_ack<=end_seen;
            end
        end
    end
endmodule
