`ifndef CNN_RESULT_APB_V
`define CNN_RESULT_APB_V
// Page 0x4000, ID SPDG. Menu enable resets off. Diagnostics read atomically
// through the established held-bundle CDC; no live multi-bit sampling.
module cnn_result_apb(
    input wire apb_clk,pixel_clk,rst_n,sel,enable,write,
    input wire [7:0] addr,input wire [3:0] strobe,input wire [31:0] wdata,
    output reg [31:0] rdata,output wire overlay_enable,
    input wire result_valid,result_overflow,input wire [4:0] result_count,
    input wire [15:0] result_sequence,
    input wire [31:0] weight_crc,good_packets,bad_packets
);
    reg enabled;
    (* async_reg="true" *)reg [1:0] enable_sync;
    wire [159:0] diag;
    wire [31:0] status={result_sequence,8'd0,result_overflow,result_count,1'b0,result_valid};
    assign overlay_enable=enable_sync[1];
    video_diag_cdc #(.WIDTH(160)) u_diag (
        .src_clk(pixel_clk),.dst_clk(apb_clk),.rst_n(rst_n),
        .data({32'd0,bad_packets,good_packets,weight_crc,status}),.snapshot(diag));
    always @(posedge apb_clk or negedge rst_n)
        if(!rst_n)enabled<=0;
        else if(sel && enable && write && addr==4 && strobe[0])enabled<=wdata[0];
    always @(posedge pixel_clk or negedge rst_n)
        if(!rst_n)enable_sync<=0;else enable_sync<={enable_sync[0],enabled};
    always @*begin
        rdata=0;
        case(addr)
        0:rdata=32'h53504447;
        4:rdata={31'd0,enabled};
        8:rdata=diag[31:0];
        12:rdata=diag[63:32];
        16:rdata=diag[95:64];
        20:rdata=diag[127:96];
        24:rdata=32'h000101f4; // protocol 1, nominal 500 kHz SPI
        endcase
    end
endmodule
`endif
