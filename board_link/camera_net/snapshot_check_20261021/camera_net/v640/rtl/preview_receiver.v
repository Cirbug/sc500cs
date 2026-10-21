// EG4D20: assemble a complete image, recognize red targets and shapes,
// return a 48-byte ACK/status/result packet without returning image pixels.
module preview_receiver #(parameter TIMEOUT=125000000, parameter integer PROC_HZ=25000000)(
 input clk,proc_clk,rst,rx_valid,input [7:0] rx_data,input [15:0] rx_len,rx_port,
 input busy,output req,valid,output reg [7:0] data,output [15:0] len,
 output reg [31:0] frames,errors,packets,
 output reg recover
);
 reg [127:0] hdr,reply;
 reg [8:0] count;
 reg rx_d,oversize;
 reg [2:0] state;
 reg [5:0] index;
 reg [31:0] timer,frame_seq,last_seq;
 reg [9:0] expected,last_chunk;
 reg have_frame,have_last;
 reg [15:0] packet_len,packet_port;
 wire [31:0] seq=hdr[95:64];
 wire [15:0] chunk=hdr[63:48];
 wire image=hdr[7:0]==1;
 wire good_header=hdr[127:96]==32'h5048494d && hdr[15:8]==3;
 wire good_image=packet_len==496 && count==496 && hdr[47:32]==960 &&
    hdr[31:16]==480 && chunk<960;
 wire good_heartbeat=packet_len==16 && count==16 && hdr[63:16]==0 && hdr[7:0]==0;
 wire duplicate=have_last && seq==last_seq && chunk==last_chunk;
 wire ordered=(chunk==0 || (have_frame && frame_seq==seq && chunk==expected));
 wire [191:0] result;
 wire analysis_done;
 reg analysis_start;
 wire [17:0] pixel_addr=({chunk[9:0],8'd0}-{4'd0,chunk[9:0],4'd0})+((count-16)>>1);
 reg [7:0] pixel_hi;
 reg [15:0] pixel_word;
 reg [2:0] pixel_lane;
 always @(posedge clk)if(rx_valid)begin
  if(count==16)begin pixel_word<=chunk[9:0]*16'd48;pixel_lane<=0;end
  if(!count[0])pixel_hi<=rx_data;
  else if(count>=17)begin
   if(pixel_lane==4)begin pixel_lane<=0;pixel_word<=pixel_word+1'b1;end
   else pixel_lane<=pixel_lane+1'b1;
  end
 end
 preview_analyzer #(.PROC_HZ(PROC_HZ)) u_analyzer(.clk(clk),.proc_clk(proc_clk),.rst(rst),
  .write_pixel(rx_valid && state==0 && count>=17 && count<496 && count[0] && chunk<960 &&
    packet_port==6001 && packet_len==496 && good_header && image && ordered && !duplicate),
  .write_addr(pixel_addr),.write_data({pixel_hi,rx_data}),.write_word(pixel_word),.write_lane(pixel_lane),.start(analysis_start),.done(analysis_done),.result(result));
 assign req=state==1;assign valid=state==2;assign len=48;
 reg [383:0] tx_shift;
 always @* data=tx_shift[383:376];
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   hdr<=0;reply<=0;tx_shift<=0;count<=0;rx_d<=0;oversize<=0;state<=0;index<=0;timer<=0;
   frames<=0;errors<=0;packets<=0;recover<=0;analysis_start<=0;
   frame_seq<=0;last_seq<=0;expected<=0;last_chunk<=0;have_frame<=0;have_last<=0;packet_len<=0;packet_port<=0;
  end else begin
   recover<=0;analysis_start<=0;rx_d<=rx_valid;
   if(!rx_valid && !rx_d)begin count<=0;oversize<=0;end
   if(rx_valid) begin
    if(count==0)begin packet_len<=rx_len;packet_port<=rx_port;end
    if(count<16)hdr<={hdr[119:0],rx_data};
    if(count<496)count<=count+1'b1;else oversize<=1;
    if(state!=0)oversize<=1;
   end
   if(rx_d && !rx_valid && state==0)begin
    if(!oversize && packet_port==6001 && good_header &&
       ((image && good_image) || good_heartbeat))begin
     reply<={32'h5041434b,hdr[95:8],8'd0};
     if(image && !duplicate && !ordered)begin
      errors<=errors+1'b1;reply[7:0]<=1;
     end else begin
      packets<=packets+1'b1;
      if(image && !duplicate) begin
       frame_seq<=seq;have_frame<=1;expected<=chunk+1'b1;
       last_seq<=seq;last_chunk<=chunk;have_last<=1;
       if(chunk==959)begin frames<=frames+1'b1;have_frame<=0;analysis_start<=1;end
      end
     end
     state<=(image && chunk==959 && !duplicate && ordered)?4:1;timer<=0;index<=0;
    end else errors<=errors+1'b1;
   end
   if(state==1) begin
    if(busy)begin tx_shift<={reply,frames,errors,result};state<=2;index<=0;timer<=0;end
    else if(timer>=TIMEOUT)begin recover<=1;state<=0;timer<=0;end
    else timer<=timer+1'b1;
   end
   if(state==2)begin tx_shift<={tx_shift[375:0],8'd0};if(index==47)begin state<=3;timer<=0;end else index<=index+1'b1;end
   if(state==4 && analysis_done)state<=1;
   if(state==3)begin
    if(!busy)begin state<=0;timer<=0;end
    else if(timer>=TIMEOUT)begin recover<=1;state<=0;timer<=0;end
    else timer<=timer+1'b1;
   end
  end
 end
endmodule
