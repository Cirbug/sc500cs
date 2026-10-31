module camera_network(
 input sys_clk,main_rst_n,pixel_clk,vs,de,input [23:0] rgb,
 input [3:0] rxd,input rx_ctl,rxc,
 output [3:0] txd,output tx_ctl,txc,phy_rst_n,
 output net_clk,output [3:0] leds,output [447:0] diagnostics
);
 parameter integer DEBUG_FLOW = 0;
 wire clk,clk90,clk25,locked,phy_done;
 assign net_clk=clk;
 net_pll u_net_pll(.refclk(sys_clk),.reset(1'b0),.lock(locked),
   .clk0_out(clk),.clk1_out(clk90),.clk2_out(clk25));
 uiphyrst #(.CLK_FREQ(25000000)) u_phy_reset(.I_CLK(clk25),.I_rstn(locked),
   .I_phyrst(locked),.O_phyrst(phy_rst_n),.O_phyrst_done(phy_done));
 (* ASYNC_REG="TRUE" *) reg done1,done2;
 always @(posedge clk or negedge locked)
  if(!locked)begin done1<=0;done2<=0;end else begin done1<=phy_done;done2<=done1;end
 wire rst=!done2;
 wire busy,req,valid,rv,rxclk,grv,gtv,release_frame,consume_chunk,ready,chunk_ready,aborted,recover;
 wire [7:0] data,rd,grd,gtd;
 wire [15:0] len,rlen,rport;
 wire [17:0] addr;wire [15:0] pixel;
 wire [31:0] sent,acked,frames,timeouts,bad,remote_frames,remote_errors;
 wire [191:0] remote_result;
 wire [2:0] state;
 reg [7:0] repair;
 // Human-visible board diagnostics. The network clock is 125 MHz, so a
 // 62,500,000-cycle window is approximately 0.5 s.
 localparam [26:0] LED_WINDOW_CYCLES = 27'd62_499_999;
 reg [26:0] led_window_counter;
 reg [31:0] led_sent_snapshot, led_acked_snapshot;
 reg led_heartbeat, led_sent_activity, led_ack_activity;
 always @(posedge clk or posedge rst)
  if(rst)repair<=0;else if(recover)repair<=255;else if(repair!=0)repair<=repair-1'b1;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   led_window_counter <= 0;
   led_sent_snapshot <= 0;
   led_acked_snapshot <= 0;
   led_heartbeat <= 1'b0;
   led_sent_activity <= 1'b0;
   led_ack_activity <= 1'b0;
  end else if(led_window_counter == LED_WINDOW_CYCLES) begin
   led_window_counter <= 0;
   led_heartbeat <= ~led_heartbeat;
   led_sent_activity <= (sent != led_sent_snapshot);
   led_ack_activity <= (acked != led_acked_snapshot);
   led_sent_snapshot <= sent;
   led_acked_snapshot <= acked;
  end else begin
   led_window_counter <= led_window_counter + 1'b1;
  end
 end
 wire stack_reset=rst || repair!=0;
 // 320x180 8-bit grayscale from 6x6 source-pixel averages.
 preview_capture_bin #(.W(1920),.H(1080),.STEP(4)) u_capture(
  .pclk(pixel_clk),.nclk(clk),.rst_n(main_rst_n && locked),
  .vs(vs),.de(de),.rgb(rgb),.release_frame(release_frame),.consume_chunk(consume_chunk),.rd_addr(addr),.rd_data(pixel),.ready(ready),.chunk_ready(chunk_ready),.aborted(aborted));
 // EG4D20 CNN1: 40 chunks, 1456 payload bytes each, then 816 bytes.
 preview_sender #(.CHUNKS(16'd179),.CHUNK_BYTES(16'd1456),.LAST_BYTES(16'd32)) u_sender(
  .clk(clk),.rst(rst),.ready(ready),.chunk_ready(chunk_ready),.aborted(aborted),.pixel(pixel),
  .release_frame(release_frame),.consume_chunk(consume_chunk),.rd_addr(addr),.busy(busy),.req(req),.valid(valid),.data(data),.len(len),
  .rx_valid(rv),.rx_data(rd),.rx_len(rlen),.rx_port(rport),
  .sent(sent),.acked(acked),.frames(frames),.timeouts(timeouts),.bad(bad),
  .remote_frames(remote_frames),.remote_errors(remote_errors),.remote_result(remote_result),.recover(recover),.state_out(state));
 // Match the EG4D20 receiver's fixed 192.168.50.2:6002 peer.
 uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) u_stack(
  .I_uclk(clk),.I_reset(stack_reset),.I_mac_local_addr(48'h020000000001),
  .I_ip_local_addr(32'hc0a83201),.I_udp_local_port(16'd6001),
  .I_ip_dest_addr(32'hc0a83202),.I_udp_dest_port(16'd6002),
  .O_W_udp_busy(busy),.I_W_udp_req(req && !stack_reset),.I_W_udp_valid(valid && !stack_reset),
  .I_W_udp_data(data),.I_W_udp_len(len),.O_R_udp_valid(rv),.O_R_udp_data(rd),
  .O_R_udp_len(rlen),.O_R_udp_src_port(rport),.I_gmii_rclk(rxclk),
  .I_gmii_rvalid(grv),.I_gmii_rdata(grd),.I_gmii_tclk(clk),.O_gmii_tvalid(gtv),
  .O_gmii_tdata(gtd),.O_ip_rerror(),.O_mac_rerror());
 // The current board pin file leaves RGMII TX pads unassigned. MapIO infers
 // TXD0 as HRIO and TXD[3:1], TX_CTL, and TXC as HDIO; see the matching DDR
 // selection in the shared rgmii_interface source. Recheck after pin mapping.
 rgmii_interface u_rgmii(.speed_10_100(1'b0),.gmii_tx_clk_d(clk),.gmii_tx_reset_d(stack_reset),
  .gmii_tx_reset(stack_reset),.gmii_tx_clk(clk),.gmii_txd(gtd),.gmii_tx_en(gtv),.gmii_tx_er(1'b0),
  .gmii_rx_reset(stack_reset),.gmii_rx_clk(rxclk),.gmii_rxd(grd),.gmii_rx_dv(grv),.gmii_rx_er(),
  .rgmii_txd(txd),.rgmii_tx_ctl(tx_ctl),.rgmii_txc(txc),.rgmii_rxd(rxd),
  .rgmii_rx_ctl(rx_ctl),.rgmii_rxc(rxc),.gmii_crs(),.gmii_col(),.link_status(),.clock_speed(),.duplex_status());
 assign diagnostics={remote_result,sent,acked,frames,timeouts,bad,remote_frames,remote_errors,
  24'd0,ready,busy,done2,locked,1'b0,state};
 // LED[0] (D10): slow heartbeat, proves the downloaded bit is running.
 // LED[1] (E10): PHY reset sequence complete.
 // LED[2] (C6): at least one packet was sent in the last half-second.
 // LED[3] (D6): ACK activity blinks; a timeout/bad ACK latches it on.
 // DEBUG_FLOW=1: D10=heartbeat, E10=ready, C6=busy(stack), D6=req(sender)
reg [24:0] dbg_cnt; always @(posedge clk) dbg_cnt <= dbg_cnt + 25'd1;
assign leds = DEBUG_FLOW ? {req, busy, ready, dbg_cnt[24]}
                    : {((timeouts!=0) || (bad!=0)) ? 1'b1 : (led_ack_activity & led_heartbeat),
                       done2, led_sent_activity & led_heartbeat, led_heartbeat};
endmodule
