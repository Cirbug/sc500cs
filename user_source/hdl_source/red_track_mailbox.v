`ifndef RED_TRACK_MAILBOX_V
`define RED_TRACK_MAILBOX_V
// Included by design_top_wrapper.v; no separate TD source-list entry needed.
// Coherent per-result mailbox, HDMI pixel clock -> MCU APB clock.
// The 58-bit bundle stays stable until a three-stage acknowledgement returns.
// No pixel storage, multiplier, divider or extra video pipeline is needed.
module red_track_mailbox (
    input wire pixel_clk, apb_clk, rst_n,
    input wire enable, reacquire, new_result, valid,
    input wire [1:0] state, dir_x, dir_y, level_x, level_y,
    input wire signed [12:0] error_x, error_y,
    output wire [31:0] status,
    output wire [31:0] errors
);
    reg [57:0] held, active;
    reg req, ack, enabled_d;
    reg [15:0] result_seq;
    (* async_reg="true" *) reg [2:0] req_sync, ack_sync;
    // Invalidations must survive a busy mailbox (e.g. a rapid mode change).
    reg invalidate;
    always @(posedge pixel_clk or negedge rst_n) begin
        if(!rst_n) begin
            held<=0; req<=0; ack_sync<=0; enabled_d<=0;
            result_seq<=0; invalidate<=1;
        end else begin
            ack_sync<={ack_sync[1:0],ack};
            enabled_d<=enable;
            if(ack_sync[2]==req && (invalidate || new_result)) begin
                result_seq<=result_seq+1'b1;
                held<={result_seq+16'd1, enable, (valid && !invalidate),
                    (invalidate ? 2'd0 : state),
                    (invalidate ? 8'd0 : {dir_x,dir_y,level_x,level_y}), 4'd0,
                    (invalidate ? 26'd0 : {error_y,error_x})};
                req<=!req;
                invalidate<=0;
            end
            if(enable!=enabled_d || reacquire) invalidate<=1;
        end
    end
    always @(posedge apb_clk or negedge rst_n) begin
        if(!rst_n) begin active<=0; req_sync<=0; ack<=0; end
        else begin
            req_sync<={req_sync[1:0],req};
            if(req_sync[2]!=ack) begin active<=held; ack<=req_sync[2]; end
        end
    end
    // Read status/errors/status and retry if the sequence changed.
    assign status=active[57:26];
    assign errors={3'd0,active[25:13],3'd0,active[12:0]};
endmodule
`endif
