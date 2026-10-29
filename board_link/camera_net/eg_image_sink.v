module eg_image_sink(
 input I_sys_clk,input [3:0] I_a_rgmii_rxd,input I_a_rgmii_rx_ctl,I_a_rgmii_rxc,
 output [3:0] O_a_rgmii_txd,output O_a_rgmii_tx_ctl,O_a_rgmii_txc,O_phy_rst);
 wire clk_125,clk_125_90,clk_25,pll_locked,phy_done;
 pll pll0_inst(.refclk(I_sys_clk),.reset(1'b0),.extlock(pll_locked),
  .clk0_out(clk_125),.clk1_out(clk_125_90),.clk2_out(clk_25));
 uiphyrst #(.CLK_FREQ(25000000)) uiphyrst_inst(.I_CLK(clk_25),.I_rstn(pll_locked),
  .I_phyrst(pll_locked),.O_phyrst(O_phy_rst),.O_phyrst_done(phy_done));
 reg done1,done2;
 always @(posedge clk_125 or negedge pll_locked)
  if(!pll_locked)begin done1<=0;done2<=0;end else begin done1<=phy_done;done2<=done1;end
 wire reset=~done2;
 wire W_udp_busy,W_udp_req,W_udp_valid,R_udp_valid,recover;
 wire [7:0] W_udp_data,R_udp_data,gmii_tdata,gmii_rdata;
 wire [15:0] W_udp_len,R_udp_len,R_udp_src_port;
 wire gmii_tvalid,gmii_rvalid,gmii_rclk;
 wire [31:0] frames,errors,packets;
 reg [7:0] repair;
 always @(posedge clk_125 or posedge reset)
  if(reset)repair<=0;else if(recover)repair<=255;else if(repair!=0)repair<=repair-1'b1;
 wire stack_reset=reset || repair!=0;
 preview_receiver u_receiver(.clk(clk_125),.proc_clk(clk_25),.rst(reset),.rx_valid(R_udp_valid),.rx_data(R_udp_data),
  .rx_len(R_udp_len),.rx_port(R_udp_src_port),.busy(W_udp_busy),.req(W_udp_req),
  .valid(W_udp_valid),.data(W_udp_data),.len(W_udp_len),.frames(frames),.errors(errors),.packets(packets),.recover(recover));
 uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) udp_stack_inst(
  .I_uclk(clk_125),.I_reset(stack_reset),.I_mac_local_addr(48'h020000000002),
  .I_ip_local_addr(32'hc0a83202),.I_udp_local_port(16'd6002),
  .I_ip_dest_addr(32'hc0a83201),.I_udp_dest_port(16'd6001),
  .O_W_udp_busy(W_udp_busy),.I_W_udp_req(W_udp_req && !stack_reset),
  .I_W_udp_valid(W_udp_valid && !stack_reset),.I_W_udp_data(W_udp_data),.I_W_udp_len(W_udp_len),
  .O_R_udp_valid(R_udp_valid),.O_R_udp_data(R_udp_data),.O_R_udp_len(R_udp_len),.O_R_udp_src_port(R_udp_src_port),
  .I_gmii_rclk(gmii_rclk),.I_gmii_rvalid(gmii_rvalid),.I_gmii_rdata(gmii_rdata),
  .I_gmii_tclk(clk_125),.O_gmii_tvalid(gmii_tvalid),.O_gmii_tdata(gmii_tdata),.O_ip_rerror(),.O_mac_rerror());
 rgmii_interface rgmii_interface_inst(.speed_10_100(1'b0),.gmii_tx_clk_d(clk_125),.gmii_tx_reset_d(stack_reset),
  .gmii_tx_reset(stack_reset),.gmii_tx_clk(clk_125),.gmii_txd(gmii_tdata),.gmii_tx_en(gmii_tvalid),.gmii_tx_er(1'b0),
  .gmii_rx_reset(stack_reset),.gmii_rx_clk(gmii_rclk),.gmii_rxd(gmii_rdata),.gmii_rx_dv(gmii_rvalid),.gmii_rx_er(),
  .rgmii_txd(O_a_rgmii_txd),.rgmii_tx_ctl(O_a_rgmii_tx_ctl),.rgmii_txc(O_a_rgmii_txc),
  .rgmii_rxd(I_a_rgmii_rxd),.rgmii_rx_ctl(I_a_rgmii_rx_ctl),.rgmii_rxc(I_a_rgmii_rxc),
  .gmii_crs(),.gmii_col(),.link_status(),.clock_speed(),.duplex_status());
endmodule
