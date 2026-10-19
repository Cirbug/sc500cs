`timescale 1ns/1ps
module tb_pair320;
 reg aclk=0,bclk=0,proc_clk=0,rst=1,ready=1;
 always #4 aclk=~aclk;
 always #4.003 bclk=~bclk;
 always #20.015 proc_clk=~proc_clk;
 wire ab,ar,av,br,bv,bb,arv,brv;
 wire [7:0] ad,bd,ard,brd,agtd,bgtd;
 wire [15:0] al,bl,arl,brl,arp,brp;
 wire agtv,bgtv;
 wire [15:0] addr;
 reg [7:0] pixel;
 wire release_frame,repair_a,repair_b;
 wire [31:0] sent,acked,frames,timeouts,bad,rf,re,bframes,berrors,bpackets;
 wire [2:0] state;
 always @(posedge aclk) pixel<=addr[7:0]^8'h5a;
 always @(posedge aclk)if(release_frame)ready<=0;
 preview_sender #(.GAP(1000),.TIMEOUT(50000000)) a(.clk(aclk),.rst(rst),.ready(ready),.chunk_ready(1'b1),.aborted(1'b0),.pixel(pixel),
  .release_frame(release_frame),.rd_addr(addr),.busy(ab),.req(ar),.valid(av),.data(ad),.len(al),
  .rx_valid(arv),.rx_data(ard),.rx_len(arl),.rx_port(arp),.sent(sent),.acked(acked),
  .frames(frames),.timeouts(timeouts),.bad(bad),.remote_frames(rf),.remote_errors(re),.recover(repair_a),.state_out(state));
 preview_receiver #(.TIMEOUT(20000)) b(.clk(bclk),.proc_clk(proc_clk),.rst(rst),.rx_valid(brv),.rx_data(brd),
  .rx_len(brl),.rx_port(brp),.busy(bb),.req(br),.valid(bv),.data(bd),.len(bl),
  .frames(bframes),.errors(berrors),.packets(bpackets),.recover(repair_b));
 wire drop=(sent==1 && timeouts==0);
 uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) sa(
  .I_uclk(aclk),.I_reset(rst),.I_mac_local_addr(48'h020000000001),
  .I_ip_local_addr(32'hc0a83201),.I_udp_local_port(16'd6001),
  .I_ip_dest_addr(32'hc0a83202),.I_udp_dest_port(16'd6002),
  .O_W_udp_busy(ab),.I_W_udp_req(ar),.I_W_udp_valid(av),.I_W_udp_data(ad),.I_W_udp_len(al),
  .O_R_udp_valid(arv),.O_R_udp_data(ard),.O_R_udp_len(arl),.O_R_udp_src_port(arp),
  .I_gmii_rclk(bclk),.I_gmii_rvalid(bgtv && !drop),.I_gmii_rdata(bgtd),
  .I_gmii_tclk(aclk),.O_gmii_tvalid(agtv),.O_gmii_tdata(agtd),.O_ip_rerror(),.O_mac_rerror());
 uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) sb(
  .I_uclk(bclk),.I_reset(rst),.I_mac_local_addr(48'h020000000002),
  .I_ip_local_addr(32'hc0a83202),.I_udp_local_port(16'd6002),
  .I_ip_dest_addr(32'hc0a83201),.I_udp_dest_port(16'd6001),
  .O_W_udp_busy(bb),.I_W_udp_req(br),.I_W_udp_valid(bv),.I_W_udp_data(bd),.I_W_udp_len(bl),
  .O_R_udp_valid(brv),.O_R_udp_data(brd),.O_R_udp_len(brl),.O_R_udp_src_port(brp),
  .I_gmii_rclk(aclk),.I_gmii_rvalid(agtv),.I_gmii_rdata(agtd),
  .I_gmii_tclk(bclk),.O_gmii_tvalid(bgtv),.O_gmii_tdata(bgtd),.O_ip_rerror(),.O_mac_rerror());
 integer fa,fb;reg aprev=0,bprev=0;
 always @(posedge bclk)if(b.rx_d && !brv && bpackets<3)
  $display("RX count=%d len=%d port=%d hdr=%h over=%b good=%b/%b state=%d",b.count,brl,brp,b.hdr,b.oversize,b.good_header,b.good_image,b.state);
 always @(posedge aclk)begin
  #1;if(agtv)$fwrite(fa,"%02x ",agtd);if(!agtv && aprev)$fwrite(fa,"\n");aprev=agtv;
 end
 always @(posedge bclk)begin
  #1;if(bgtv)$fwrite(fb,"%02x ",bgtd);if(!bgtv && bprev)$fwrite(fb,"\n");bprev=bgtv;
 end
 initial begin
  fa=$fopen("ph1_frames.hex","w");fb=$fopen("eg_frames.hex","w");
  repeat(40)@(negedge aclk);rst=0;
  wait(frames==1);repeat(30)@(negedge aclk);
  if(sent!=241 || acked!=240 || timeouts!=1 || bad!=0 || bframes!=1 || berrors!=0 || rf!=1)
   $fatal(1,"image counters sent=%0d ack=%0d timeout=%0d bad=%0d remote=%0d/%0d",sent,acked,timeouts,bad,bframes,berrors);
  wait(acked==241); // no image ready: small heartbeat still works
  if(sent!=242 || bframes!=1 || frames!=1)$fatal(1,"heartbeat failed");
  if(a.remote_result!==b.result)$fatal(1,"recognition result did not return");
  repeat(150)@(negedge aclk);
  $fclose(fa);$fclose(fb);$display("PAIR_IMAGE_PASS: 57600 pixels, lost ACK retried, one frame, heartbeat");$finish;
 end
 initial begin #1200000000;$fatal(1,"pair watchdog state=%d sent=%d ack=%d time=%d recv=%d err=%d",state,sent,acked,timeouts,bpackets,berrors);end
endmodule
