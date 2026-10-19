`timescale 1ns/1ps
// Dedicated diagnostic image; independent of camera/MCU/DDR/display project.
module ph1_udp_selftest #(
    parameter integer START_CYCLES=250000000,
    parameter integer GAP_CYCLES=125000000,
    parameter integer TIMEOUT_CYCLES=125000000
)(input wire I_sys_clk,
  input wire [3:0] I_a_rgmii_rxd,
  input wire I_a_rgmii_rx_ctl, I_a_rgmii_rxc,
  output wire O_phy_rst,
  output wire [3:0] O_a_rgmii_txd,
  output wire O_a_rgmii_tx_ctl, O_a_rgmii_txc,
  output wire [3:0] O_LED4,
  output wire O_uart_tx);
    wire clk_125,clk_125_90,clk_25,pll_locked,phy_done;
    wire reset=~phy_done;
    pll pll_pll_inst(.refclk(I_sys_clk),.reset(1'b0),.lock(pll_locked),
                    .clk0_out(clk_125),.clk1_out(clk_125_90),.clk2_out(clk_25));
    uiphyrst #(.CLK_FREQ(25000000)) rst_inst(.I_CLK(clk_25),.I_rstn(pll_locked),
        .I_phyrst(pll_locked),.O_phyrst(O_phy_rst),.O_phyrst_done(phy_done));
    wire gmii_rclk,gmii_rvalid,gmii_tvalid;
    wire [7:0] gmii_rdata,gmii_tdata;
    wire tx_busy,tx_req,tx_valid,rx_valid;
    wire [7:0] tx_data,rx_data;
    wire [15:0] tx_len,rx_len,rx_port;
    wire [31:0] sent_count,pass_count,timeout_count,bad_count,event_seq;
    wire event_valid,pass_toggle,error_sticky;
    wire [1:0] event_kind;
    wire mac_error,ip_error;
    reg [26:0] heartbeat;
    always @(posedge clk_125 or posedge reset)
        if(reset) heartbeat<=0; else heartbeat<=heartbeat+1'b1;
    assign O_LED4={error_sticky,pass_toggle,heartbeat[26],phy_done};
    udp_probe #(.START_CYCLES(START_CYCLES),.GAP_CYCLES(GAP_CYCLES),
                .TIMEOUT_CYCLES(TIMEOUT_CYCLES)) probe(
        .clk(clk_125),.reset(reset),.tx_busy(tx_busy),.tx_req(tx_req),.tx_valid(tx_valid),
        .tx_data(tx_data),.tx_len(tx_len),.rx_valid(rx_valid),.rx_data(rx_data),
        .rx_len(rx_len),.rx_src_port(rx_port),.sent_count(sent_count),
        .pass_count(pass_count),.timeout_count(timeout_count),.bad_count(bad_count),
        .event_valid(event_valid),.event_kind(event_kind),.event_seq(event_seq),
        .pass_toggle(pass_toggle),.error_sticky(error_sticky));
    probe_uart logger(.clk(clk_125),.reset(reset),.event_valid(event_valid),
        .event_kind(event_kind),.event_seq(event_seq),.tx(O_uart_tx));
    uiudp_stack #(.CRC_GEN_EN(1'b1),.INTER_FRAME_GAP(4'd12)) stack(
        .I_uclk(clk_125),.I_reset(reset),.I_mac_local_addr(48'h020000000001),
        .I_udp_local_port(16'd6001),.I_ip_local_addr(32'hc0a83201),
        .I_udp_dest_port(16'd6002),.I_ip_dest_addr(32'hc0a83202),
        .O_W_udp_busy(tx_busy),.I_W_udp_req(tx_req),.I_W_udp_valid(tx_valid),
        .I_W_udp_data(tx_data),.I_W_udp_len(tx_len),.O_R_udp_valid(rx_valid),
        .O_R_udp_data(rx_data),.O_R_udp_len(rx_len),.O_R_udp_src_port(rx_port),
        .I_gmii_rclk(gmii_rclk),.I_gmii_rvalid(gmii_rvalid),.I_gmii_rdata(gmii_rdata),
        .I_gmii_tclk(clk_125),.O_gmii_tvalid(gmii_tvalid),.O_gmii_tdata(gmii_tdata),
        .O_ip_rerror(ip_error),.O_mac_rerror(mac_error));
    rgmii_interface rgmii_interface_inst(
        .speed_10_100(1'b0),.gmii_tx_clk_d(clk_125),.gmii_tx_reset_d(reset),
        .gmii_tx_clk(clk_125),.gmii_tx_reset(reset),.gmii_txd(gmii_tdata),
        .gmii_tx_en(gmii_tvalid),.gmii_tx_er(1'b0),.gmii_rx_reset(reset),
        .gmii_rx_clk(gmii_rclk),.gmii_rxd(gmii_rdata),.gmii_rx_dv(gmii_rvalid),
        .gmii_rx_er(),.rgmii_txd(O_a_rgmii_txd),.rgmii_tx_ctl(O_a_rgmii_tx_ctl),
        .rgmii_txc(O_a_rgmii_txc),.rgmii_rxd(I_a_rgmii_rxd),
        .rgmii_rx_ctl(I_a_rgmii_rx_ctl),.rgmii_rxc(I_a_rgmii_rxc),
        .gmii_crs(),.gmii_col(),.link_status(),.clock_speed(),.duplex_status());
endmodule
