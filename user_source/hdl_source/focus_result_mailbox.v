`ifndef FOCUS_RESULT_MAILBOX_V
`define FOCUS_RESULT_MAILBOX_V
// Metric and sequence cross as one held packet. Sequence denotes HDMI metric
// frames, NOT unique sensor exposures (DDR can repeat a camera frame).
module focus_result_mailbox (
    input wire pixel_clk,apb_clk,rst_n,frame_toggle,
    input wire [31:0] metric,
    output wire [31:0] apb_metric,apb_sequence
);
    reg toggle_d,req,ack;
    reg [15:0] seq;
    reg [47:0] held,active;
    (* async_reg="true" *) reg [2:0] req_sync,ack_sync;
    always @(posedge pixel_clk or negedge rst_n) begin
        if(!rst_n) begin toggle_d<=0;req<=0;seq<=0;held<=0;ack_sync<=0;end
        else begin
            ack_sync<={ack_sync[1:0],ack};
            toggle_d<=frame_toggle;
            if(toggle_d!=frame_toggle && ack_sync[2]==req) begin
                seq<=seq+1'b1; held<={seq+16'd1,metric}; req<=!req;
            end
        end
    end
    always @(posedge apb_clk or negedge rst_n) begin
        if(!rst_n) begin active<=0;ack<=0;req_sync<=0;end
        else begin
            req_sync<={req_sync[1:0],req};
            if(req_sync[2]!=ack) begin active<=held;ack<=req_sync[2];end
        end
    end
    assign apb_metric=active[31:0];
    assign apb_sequence={16'd0,active[47:32]};
endmodule
`endif
