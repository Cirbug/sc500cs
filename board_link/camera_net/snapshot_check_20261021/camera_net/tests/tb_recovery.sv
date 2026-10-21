`timescale 1ns/1ps
module tb_recovery;
 reg clk=0,rst=1,busy=1,ready=1;always #4 clk=~clk;
 wire req,valid,release_frame,recover;wire [7:0] data;wire [15:0] len;wire [13:0] addr;
 wire [31:0] sent,acked,frames,timeouts,bad,rf,re;wire [2:0] state;
 integer repairs=0;
 preview_sender #(.GAP(10),.TIMEOUT(20)) dut(.clk(clk),.rst(rst),.ready(ready),.pixel(8'h5a),
  .release_frame(release_frame),.rd_addr(addr),.busy(busy),.req(req),.valid(valid),.data(data),.len(len),
  .rx_valid(1'b0),.rx_data(8'd0),.rx_len(16'd0),.rx_port(16'd0),.sent(sent),.acked(acked),
  .frames(frames),.timeouts(timeouts),.bad(bad),.remote_frames(rf),.remote_errors(re),.recover(recover),.state_out(state));
 always @(posedge clk)if(recover)repairs=repairs+1;
 initial begin
  repeat(3)@(negedge clk);rst=0;
  wait(repairs==1);@(negedge clk);busy=0; // persistent busy recovered
  wait(req); // no handshake: request timeout releases owned image
  wait(release_frame);if(timeouts<2)$fatal(1,"request did not timeout");
  ready=0;wait(req);@(negedge clk);busy=1;wait(valid);wait(!valid);
  // no reply plus stuck busy must recover instead of freezing video.
  wait(repairs==3);@(negedge clk);busy=0;
  wait(req);@(negedge clk);busy=1;wait(valid);
  $display("RECOVERY_PASS: busy watchdog, request timeout, image release, missing ACK recovery");$finish;
 end
 initial begin #100000;$fatal(1,"recovery watchdog repairs=%d",repairs);end
endmodule
