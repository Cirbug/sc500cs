// Stop-and-wait sender for the EG4D20 CNN1 receiver.
// Each image datagram is CNN1 header + grayscale bytes + reflected CRC-32/IEEE.
module preview_sender #(parameter GAP=0, TIMEOUT=125000000,
                        parameter [15:0] CHUNKS=16'd40,
                        parameter [15:0] CHUNK_BYTES=16'd1456,
                        parameter [15:0] LAST_BYTES=16'd816,
                        parameter [7:0] FORMAT=8'd4)(
 input clk,rst,ready,chunk_ready,aborted, input [15:0] pixel,
 output reg release_frame,consume_chunk, output [17:0] rd_addr,
 input busy, output req,valid, output reg [7:0] data, output [15:0] len,
 input rx_valid, input [7:0] rx_data, input [15:0] rx_len,rx_port,
 output reg [31:0] sent,acked,frames,timeouts,bad,
 output wire [31:0] remote_frames,remote_errors,
 output wire [191:0] remote_result,
 output reg recover, output [2:0] state_out
);
 localparam IDLE=0,REQUEST=1,SEND=2,WAIT_REPLY=3,ADVANCE=4,WAIT_RELEASE=5;
 localparam [10:0] HEADER_BYTES=11'd12;
 reg [2:0] state;
 reg [31:0] timer,seq,crc_state;
 reg [9:0] chunk;
 reg [17:0] base;
 reg [10:0] index;
 reg [1:0] retry;
 reg rx_d,rx_bad;
 reg [4:0] rx_count;
 reg [15:0] rx_packet_len,rx_packet_port;
 reg [7:0] rx_status;
 wire [15:0] payload=(chunk==CHUNKS-1)?LAST_BYTES:CHUNK_BYTES;
 wire [10:0] payload_end=HEADER_BYTES+payload;
 wire [15:0] packet_bytes=16'd16+payload;
 wire [15:0] chunk_words=(payload+16'd1)>>1;
 wire [10:0] payload_offset=index-HEADER_BYTES;
 wire [31:0] final_crc=~crc_state;
 wire rx_reply_complete=(rx_packet_len==16'd10 && rx_count==5'd10);

 assign len=packet_bytes;
 assign req=(state==REQUEST) && chunk_ready && !aborted;
 assign valid=(state==SEND);
 assign state_out=state;
 assign remote_frames=32'd0;
 assign remote_errors=32'd0;
 assign remote_result=192'd0;

 // The capture RAM is synchronous. Header byte 11 prefetches the first word.
 assign rd_addr=(index<=11) ? base :
                (index<11+payload) ? base+((index-11)>>1) :
                base+chunk_words-1'b1;

 function [31:0] crc32_byte;
  input [31:0] crc_in;
  input [7:0] data_in;
  integer i;
  reg [31:0] crc;
  begin
   crc=crc_in^data_in;
   for(i=0;i<8;i=i+1)crc=crc[0]?((crc>>1)^32'hedb88320):(crc>>1);
   crc32_byte=crc;
  end
 endfunction

 function [7:0] header_byte;
  input [3:0] n;
  begin case(n)
   0:header_byte=8'h43;1:header_byte=8'h4e;2:header_byte=8'h4e;3:header_byte=8'h31;
   4:header_byte=8'd1;5:header_byte=8'd0;
   6:header_byte=seq[15:8];7:header_byte=seq[7:0];
   8:header_byte={6'd0,chunk[9:8]};9:header_byte=chunk[7:0];
   10:header_byte=payload[15:8];11:header_byte=payload[7:0];
   default:header_byte=8'd0;
  endcase end
 endfunction

 function [7:0] ack_prefix_byte;
  input [2:0] n;
  begin case(n)
   0:ack_prefix_byte=8'h41;1:ack_prefix_byte=8'h43;2:ack_prefix_byte=8'h4b;3:ack_prefix_byte=8'h31;
   4:ack_prefix_byte=seq[15:8];5:ack_prefix_byte=seq[7:0];
   6:ack_prefix_byte={6'd0,chunk[9:8]};7:ack_prefix_byte=chunk[7:0];
   default:ack_prefix_byte=8'd0;
  endcase end
 endfunction

 always @* begin
  if(index<HEADER_BYTES) data=header_byte(index[3:0]);
  else if(index<payload_end) data=payload_offset[0]?pixel[7:0]:pixel[15:8];
  else begin
   case(index-payload_end)
    0:data=final_crc[31:24];1:data=final_crc[23:16];
    2:data=final_crc[15:8];3:data=final_crc[7:0];
    default:data=8'd0;
   endcase
  end
 end

 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;timer<=0;seq<=0;crc_state<=32'hffffffff;chunk<=0;base<=0;index<=0;retry<=0;
   release_frame<=0;consume_chunk<=0;recover<=0;sent<=0;acked<=0;frames<=0;timeouts<=0;bad<=0;
   rx_d<=0;rx_bad<=0;rx_count<=0;rx_packet_len<=0;rx_packet_port<=0;rx_status<=0;
  end else begin
   release_frame<=0;consume_chunk<=0;recover<=0;rx_d<=rx_valid;
   if(!rx_valid && !rx_d) begin
    rx_count<=0;rx_bad<=0;rx_packet_len<=0;rx_packet_port<=0;rx_status<=0;
   end
   if(rx_valid) begin
    if(rx_count==0) begin
     rx_packet_len<=rx_len;rx_packet_port<=rx_port;
     if(rx_len!=16'd10 || rx_port!=16'd6002)rx_bad<=1;
    end
    if(rx_count<rx_len && rx_count<5'd10)rx_count<=rx_count+1'b1;else rx_bad<=1;
    if(rx_count<5'd8 && rx_data!=ack_prefix_byte(rx_count[2:0]))rx_bad<=1;
    if(rx_count==5'd8)rx_status<=rx_data;
    if(rx_count==5'd9 && rx_data!=8'd0)rx_bad<=1;
   end

   if(state==SEND && index<payload_end)
    crc_state<=crc32_byte(crc_state,data);

   case(state)
    IDLE: begin
     index<=0;timer<=0;
     if(ready && chunk_ready && !busy)begin
      chunk<=0;base<=0;retry<=0;state<=REQUEST;
     end
    end
    REQUEST: begin
     if(busy)begin index<=0;crc_state<=32'hffffffff;timer<=0;state<=SEND;end
     else if(timer>=TIMEOUT)begin
      recover<=1;timeouts<=timeouts+1'b1;release_frame<=1;seq<=seq+1'b1;timer<=0;state<=WAIT_RELEASE;
     end else timer<=timer+1'b1;
    end
    SEND: if(index==packet_bytes-1'b1)begin
     sent<=sent+1'b1;state<=WAIT_REPLY;timer<=0;
    end else index<=index+1'b1;
    WAIT_REPLY: begin
     if(rx_d && !rx_valid && !rx_bad && rx_packet_port==16'd6002 && rx_reply_complete)begin
      if(rx_status==((chunk==CHUNKS-1)?8'd1:8'd0))begin
       consume_chunk<=1;acked<=acked+1'b1;timer<=0;retry<=0;
       if(chunk<CHUNKS-1)begin
        chunk<=chunk+1'b1;base<=base+CHUNK_BYTES/2;state<=ADVANCE;
       end else begin
        frames<=frames+1'b1;release_frame<=1;seq<=seq+1'b1;state<=WAIT_RELEASE;
       end
      end else if(rx_status==8'd2)begin
       acked<=acked+1'b1;bad<=bad+1'b1;release_frame<=1;seq<=seq+1'b1;timer<=0;state<=WAIT_RELEASE;
      end else begin
       bad<=bad+1'b1;
      end
     end else if(timer>=TIMEOUT)begin
      timeouts<=timeouts+1'b1;timer<=0;
      if(retry<2 && !busy)begin retry<=retry+1'b1;state<=REQUEST;index<=0;end
      else begin
       if(busy)recover<=1;
       release_frame<=1;seq<=seq+1'b1;state<=WAIT_RELEASE;
      end
     end else begin
      timer<=timer+1'b1;if(rx_d && !rx_valid)bad<=bad+1'b1;
     end
    end
    ADVANCE:state<=REQUEST;
    WAIT_RELEASE:if(!ready)begin state<=IDLE;timer<=0;end
    default:state<=IDLE;
   endcase

   if(aborted && state!=SEND && state!=WAIT_RELEASE)begin
    release_frame<=1;consume_chunk<=0;seq<=seq+1'b1;state<=WAIT_RELEASE;timer<=0;
   end
  end
 end
endmodule
