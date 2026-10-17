`ifndef VIDEO_INTEGRITY_V
`define VIDEO_INTEGRITY_V
// RAW10 geometry and D-PHY errors. This does NOT implement CSI CRC/ECC.
module video_rx_integrity #(
    parameter integer LINE_WORDS=810, HEIGHT=1944
)(input wire clk,rst_n,line_end,frame_start,frame_end,word_valid,
  input wire lane_error,match_error,packet_error,
  input wire [63:0] packet_fault,
  output reg frame_done,frame_bad,
  output wire capture_error,
  output wire [63:0] diagnostics,
  output wire [95:0] fault_details);
    reg [63:0] first_packet_fault;
    reg [31:0] first_bad_line;
    assign fault_details={first_bad_line,first_packet_fault};
    reg active;
    reg [11:0] words,lines,last_words,last_lines;
    reg [7:0] errors,last_errors;
    reg [15:0] good_frames,bad_frames;
    wire [12:0] words_now={1'b0,words}+word_valid;
    wire [12:0] lines_now={1'b0,lines}+line_end;
    wire bad_line=line_end && words_now!=LINE_WORDS;
    wire [7:0] current_errors=errors | {6'd0,match_error,lane_error} |
        (bad_line ? 8'h04:8'h00) | (packet_error ? 8'h20:8'h00);
    // Sticky within this RAW frame, including faults before the cropped ISP
    // SOF. Capture samples this until its last visible word, not at RAW EOF.
    assign capture_error=active && |(current_errors & 8'h2d);
    // Match is the raw PHY master/slave sampling comparator, not a CSI
    // integrity verdict. Missing FE may use the next FS as a boundary ONLY
    // when the complete geometry and subsequent ISP word count both agree.
    wire verdict_bad=|(current_errors & 8'h2d) || lines_now!=HEIGHT ||
        (!line_end && words_now!=0);
    assign diagnostics={bad_frames,good_frames,last_errors,last_lines,last_words};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            active<=0;words<=0;lines<=0;errors<=0;
            first_packet_fault<=0;first_bad_line<=0;
            last_words<=0;last_lines<=0;last_errors<=0;good_frames<=0;bad_frames<=0;
            frame_done<=0;frame_bad<=1;
        end else begin
            frame_done<=0;
            if(active) begin
                // Independent first-error records, sticky until FPGA reset.
                if(packet_error && !first_packet_fault[63]) first_packet_fault<=packet_fault;
                if(bad_line && !first_bad_line[31])
                    first_bad_line<={1'b1,6'd0,lines_now[11:0],words_now};
                errors<=current_errors;
                if(word_valid && words!=4095) words<=words+1'b1;
                if(line_end) begin
                    words<=0;
                    last_words<=words_now[11:0];
                    if(lines!=4095) lines<=lines+1'b1;
                end
            end
            if((frame_end || frame_start) && active) begin
                frame_done<=1;active<=0;last_lines<=lines_now[11:0];
                frame_bad<=verdict_bad;
                last_errors<=current_errors | (lines_now!=HEIGHT ? 8'h08:8'h00) |
                    (!frame_end ? 8'h10:8'h00);
                if(verdict_bad) bad_frames<=bad_frames+1'b1;
                else good_frames<=good_frames+1'b1;
            end
            if(frame_start) begin
                active<=1;words<=0;lines<=0;errors<=0;
            end
        end
    end
endmodule

// Source holds a complete snapshot until the next synchronized request.
module video_diag_cdc #(parameter WIDTH=64)(
    input wire src_clk,dst_clk,rst_n,input wire [WIDTH-1:0] data,
    output reg [WIDTH-1:0] snapshot);
    reg request,ack;
    (* ASYNC_REG="TRUE" *) reg [1:0] req_sync,ack_sync;
    reg [WIDTH-1:0] held;
    always @(posedge src_clk or negedge rst_n)
        if(!rst_n) begin req_sync<=0;ack<=0;held<=0;end
        else begin
            req_sync<={req_sync[0],request};
            if(req_sync[1]!=ack) begin held<=data;ack<=req_sync[1];end
        end
    always @(posedge dst_clk or negedge rst_n)
        if(!rst_n) begin request<=1;ack_sync<=0;snapshot<=0;end
        else begin
            ack_sync<={ack_sync[0],ack};
            if(ack_sync[1]==request) begin snapshot<=held;request<=~request;end
        end
endmodule
`endif
