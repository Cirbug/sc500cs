`ifndef CAMERA_MENU_SUPPORT_V
`define CAMERA_MENU_SUPPORT_V
// Source keeps the complete bundle stable until the destination acknowledges.
module camera_menu_cdc #(parameter WIDTH=48,parameter [WIDTH-1:0] RESET_VALUE=0)(
    input wire src_clk,dst_clk,rst_n,
    input wire [WIDTH-1:0] requested,
    output reg [WIDTH-1:0] active
);
    reg [WIDTH-1:0] held;
    reg req,ack;
    (* async_reg="true" *) reg [2:0] req_sync,ack_sync;
    always @(posedge src_clk or negedge rst_n) begin
        if(!rst_n)begin held<=RESET_VALUE;req<=0;ack_sync<=0;end
        else begin
            ack_sync<={ack_sync[1:0],ack};
            if(ack_sync[2]==req && requested!=held)begin held<=requested;req<=!req;end
        end
    end
    always @(posedge dst_clk or negedge rst_n) begin
        if(!rst_n)begin active<=RESET_VALUE;ack<=0;req_sync<=0;end
        else begin
            req_sync<={req_sync[1:0],req};
            if(req_sync[2]!=ack)begin active<=held;ack<=req_sync[2];end
        end
    end
endmodule

// MIPI counts CSI Frame Start packets, HDMI counts displayed VS rising edges.
// A stopped source clock produces zero FPS after the next full window.
module video_dual_frame_stats #(parameter PIXEL_CLOCK_HZ=75000000)(
    input wire clk,rst_n,vsync,mipi_clk,mipi_fs,
    output reg [31:0] hdmi_frames,mipi_frames,
    output reg [11:0] hdmi_fps,mipi_fps,
    output reg fps_valid
);
    reg fs_d,toggle;
    (* async_reg="true" *) reg [2:0] fs_sync;
    reg seen,vs_d;
    always @(posedge mipi_clk or negedge rst_n)begin
        if(!rst_n)begin fs_d<=0;toggle<=0;end
        else begin fs_d<=mipi_fs;if(mipi_fs && !fs_d)toggle<=!toggle;end
    end
    wire m_event=fs_sync[2]^seen,h_event=vsync&&!vs_d;
    localparam TIMER_BITS=PIXEL_CLOCK_HZ>1?$clog2(PIXEL_CLOCK_HZ):1;
    reg [TIMER_BITS-1:0] ticks;
    reg [11:0] mw,hw;
    function [31:0] inc;
        input [31:0] v;
        integer k;reg carry;
        begin
            inc=v;carry=1;
            for(k=0;k<8;k=k+1)if(carry)begin
                if(v[k*4+:4]==9)inc[k*4+:4]=0;
                else begin inc[k*4+:4]=v[k*4+:4]+1'b1;carry=0;end
            end
        end
    endfunction
    wire [31:0] mi=inc({20'd0,mw}),hi=inc({20'd0,hw});
    wire [11:0] mn=m_event&&mw!=12'h999 ? mi[11:0]:mw;
    wire [11:0] hn=h_event&&hw!=12'h999 ? hi[11:0]:hw;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin fs_sync<=0;seen<=0;vs_d<=0;ticks<=0;mw<=0;hw<=0;
            hdmi_frames<=0;mipi_frames<=0;hdmi_fps<=0;mipi_fps<=0;fps_valid<=0;end
        else begin
            fs_sync<={fs_sync[1:0],toggle};seen<=fs_sync[2];vs_d<=vsync;
            if(m_event&&mipi_frames!=32'h99999999)mipi_frames<=inc(mipi_frames);
            if(h_event&&hdmi_frames!=32'h99999999)hdmi_frames<=inc(hdmi_frames);
            if(ticks==PIXEL_CLOCK_HZ-1)begin ticks<=0;mipi_fps<=mn;hdmi_fps<=hn;fps_valid<=1;mw<=0;hw<=0;end
            else begin ticks<=ticks+1'b1;mw<=mn;hw<=hn;end
        end
    end
endmodule
`endif
