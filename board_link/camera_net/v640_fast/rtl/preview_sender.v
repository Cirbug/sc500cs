// Stop-and-wait image chunks. Timeout abandons only this thumbnail.
// Header: PHIM, seq32, chunk16, count16, bytes16, format8=1, type8.
module preview_sender #(parameter GAP=0, TIMEOUT=125000000)(
 input clk,rst,ready,chunk_ready,aborted, input [15:0] pixel,
 output reg release_frame,consume_chunk, output [17:0] rd_addr,
 input busy, output req,valid, output reg [7:0] data, output [15:0] len,
 input rx_valid, input [7:0] rx_data, input [15:0] rx_len,rx_port,
 output reg [31:0] sent,acked,frames,timeouts,bad,
 output reg [31:0] remote_frames,remote_errors,
 output reg [191:0] remote_result,
 output reg recover, output [2:0] state_out
);
 localparam IDLE=0,REQUEST=1,SEND=2,WAIT_REPLY=3;
 reg [2:0] state;
 reg [31:0] timer,seq;
 reg [9:0] chunk;
 reg [17:0] base;
 reg image;
 reg [8:0] index;
 reg [1:0] retry;
 reg rx_d,rx_bad;
 reg [5:0] rx_count;
 reg [31:0] rf,re;
 reg [191:0] result_tmp;
 wire [15:0] payload=image?16'd480:16'd0;
 assign len=image?16'd496:16'd16;
 assign req=state==REQUEST && (!image || chunk_ready) && !aborted;
 assign valid=state==SEND;
 assign state_out=state;
 // RAM has one-cycle latency; index 15 prefetches payload byte zero.
 assign rd_addr=(index<15)?base:base+((index-15)>>1);
 function [7:0] header;
 input [4:0] n;input ack;
 begin case(n)
  0:header=8'h50;1:header=ack?8'h41:8'h48;
  2:header=ack?8'h43:8'h49;3:header=ack?8'h4b:8'h4d;
  4:header=seq[31:24];5:header=seq[23:16];6:header=seq[15:8];7:header=seq[7:0];
  8:header={6'd0,chunk[9:8]};9:header=chunk[7:0];10:header=image?8'd3:0;11:header=image?8'd192:0;
  12:header=payload[15:8];13:header=payload[7:0];14:header=3;15:header=ack?0:{7'd0,image};
  default:header=0;
 endcase end endfunction
 always @* data=(index<16)?header(index[4:0],0):(index[0]?pixel[7:0]:pixel[15:8]);
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;timer<=0;seq<=0;chunk<=0;base<=0;image<=0;index<=0;retry<=0;
   release_frame<=0;consume_chunk<=0;recover<=0;sent<=0;acked<=0;frames<=0;timeouts<=0;bad<=0;
   rx_d<=0;rx_bad<=0;rx_count<=0;rf<=0;re<=0;remote_frames<=0;remote_errors<=0;remote_result<=0;result_tmp<=0;
  end else begin
   release_frame<=0;consume_chunk<=0;recover<=0;rx_d<=rx_valid;
   if(!rx_valid && !rx_d) begin rx_count<=0;rx_bad<=0;end
   if(rx_valid) begin
    if(rx_count<48)rx_count<=rx_count+1'b1;else rx_bad<=1;
    if(rx_len!=48 || rx_port!=6002)rx_bad<=1;
    if(rx_count<16 && rx_data!=header(rx_count[4:0],1))rx_bad<=1;
    if(rx_count>=16 && rx_count<20)rf<={rf[23:0],rx_data};
    if(rx_count>=20 && rx_count<24)re<={re[23:0],rx_data};
    if(rx_count>=24 && rx_count<48)result_tmp<={result_tmp[183:0],rx_data};
   end
   case(state)
    IDLE: begin
     index<=0;
     if((ready && timer>=GAP) || timer>=TIMEOUT) begin
      if(!busy && (!ready || chunk_ready)) begin
       image<=ready;chunk<=0;base<=0;retry<=0;timer<=0;state<=REQUEST;
      end else if(timer>=GAP+TIMEOUT) begin
       recover<=1;timer<=0;timeouts<=timeouts+1'b1;
      end else timer<=timer+1'b1;
     end else timer<=timer+1'b1;
    end
    REQUEST: begin
     if(busy)begin index<=0;timer<=0;state<=SEND;end
     else if(timer>=TIMEOUT) begin
      recover<=1;timeouts<=timeouts+1'b1;state<=IDLE;timer<=0;
      seq<=seq+1'b1;if(image)release_frame<=1;
     end else timer<=timer+1'b1;
    end
    SEND: if(index==len-1)begin sent<=sent+1'b1;state<=WAIT_REPLY;timer<=0;end
          else index<=index+1'b1;
    WAIT_REPLY: begin
     if(rx_d && !rx_valid && !rx_bad && rx_count==48) begin
      if(image)consume_chunk<=1;
      acked<=acked+1'b1;remote_frames<=rf;remote_errors<=re;timer<=0;retry<=0;
      if(image && chunk<959)begin chunk<=chunk+1'b1;base<=base+240;state<=4;end
      else begin
       if(image)begin frames<=frames+1'b1;release_frame<=1;remote_result<=result_tmp;end
       seq<=seq+1'b1;state<=IDLE;
      end
     end else if(timer>=TIMEOUT)begin
      timeouts<=timeouts+1'b1;timer<=0;
      if(retry<2 && !busy)begin retry<=retry+1'b1;state<=REQUEST;end
      else begin
       if(busy)recover<=1;
       if(image)release_frame<=1;
       seq<=seq+1'b1;state<=IDLE;
      end
     end else begin
      timer<=timer+1'b1;if(rx_d && !rx_valid)bad<=bad+1'b1;
     end
    end
    4:state<=REQUEST; // Allow capture to commit this ACK before checking the next chunk.
    default:state<=IDLE;
   endcase
   if(aborted && state!=SEND)begin
    release_frame<=1;consume_chunk<=0;state<=IDLE;timer<=0;seq<=seq+1'b1;
    if(!release_frame)timeouts<=timeouts+1'b1;
   end
  end
 end
endmodule
