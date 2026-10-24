`timescale 1ns/1ps

module eth_udp_main (
    input  wire        I_sys_clk,
    input  wire        I_pixel_clk,
    input  wire        I_pixel_reset_n,
    input  wire        I_shape_dst_clk,
    input  wire        I_diag_dst_clk,
    input  wire        I_pixel_frame_start,
    input  wire        I_pixel_frame_end,
    input  wire        I_pixel_valid,
    input  wire [63:0] I_pixel_rgb565,

    input  wire [3:0]  I_a_rgmii_rxd,
    input  wire        I_a_rgmii_rx_ctl,
    input  wire        I_a_rgmii_rxc,
    output wire [3:0]  O_a_rgmii_txd,
    output wire        O_a_rgmii_tx_ctl,
    output wire        O_a_rgmii_txc,
    output wire        O_phy_rst,
    output wire [3:0]  O_led,
    output wire        O_shape_valid,
    output wire [2:0]  O_shape_type,
    output wire [11:0] O_shape_x0,
    output wire [11:0] O_shape_y0,
    output wire [11:0] O_shape_x1,
    output wire [11:0] O_shape_y1,
    output wire [31:0] O_tx_packets,
    output wire [31:0] O_tx_frames,
    output wire [31:0] O_reply_packets,
    output wire [31:0] O_bad_packets,
    output wire [31:0] O_remote_frames,
    output wire [31:0] O_remote_errors,
    output wire [31:0] O_remote_frame_id,
    output wire [4:0]  O_net_status,
    output wire [15:0] O_stack_debug
);
    wire clk125;
    wire clk125_90;
    wire clk25;
    wire pll_locked;
    wire phy_reset_n;
    wire stack_reset = ~phy_reset_n;

    wire [7:0] gmii_tdata;
    wire gmii_tvalid;
    wire [7:0] gmii_rdata;
    wire gmii_rvalid;
    wire gmii_rclk;
    wire rgmii_link_status;
    wire [1:0] rgmii_clock_speed;
    wire rgmii_duplex_status;
    (* async_reg = "true" *) reg [3:0] rgmii_status_meta, rgmii_status_sync;
    // At 125 MHz, keep traffic visible for 500 ms and blink at 2 Hz.
    localparam [25:0] LED_ACTIVITY_HOLD_CYCLES = 26'd62_500_000;
    localparam [24:0] LED_BLINK_HALF_CYCLES = 25'd31_250_000;
    reg [25:0] tx_activity_timer, rx_activity_timer;
    reg [24:0] tx_led_blink_counter, rx_led_blink_counter;
    reg tx_led_blink, rx_led_blink;
    reg gmii_tvalid_d, gmii_rvalid_d;
    reg network_error_latched;

    assign O_led = {network_error_latched,
                    (rx_activity_timer != 0) && rx_led_blink,
                    (tx_activity_timer != 0) && tx_led_blink,
                    rgmii_status_sync[0]};

    wire udp_busy;
    wire udp_req;
    wire udp_valid;
    wire [7:0] udp_data;
    wire [15:0] udp_len;
    wire rx_udp_valid;
    wire [7:0] rx_udp_data;
    wire [15:0] rx_udp_len;
    wire [15:0] rx_udp_src_port;
    wire [31:0] tx_packets, tx_frames;
    wire [31:0] reply_packets, bad_packets, remote_frames, remote_errors, remote_frame_id;
    wire [15:0] stack_debug;
    wire [15:0] stack_debug_diag = {
        1'b0, rgmii_status_sync[3], rgmii_status_sync[2:1],
        rgmii_status_sync[0], stack_debug[10:0]
    };
    wire [1:0] tx_state;
    wire fifo_overflow;
    (* async_reg = "true" *) reg fifo_overflow_meta, fifo_overflow_sync;
    (* async_reg = "true" *) reg phy_reset_meta, phy_reset_sync;
    (* async_reg = "true" *) reg pll_lock_meta, pll_lock_sync;
    wire [4:0] net_status = {tx_state, pll_lock_sync, phy_reset_sync, fifo_overflow_sync};
    wire [244:0] net_diag_snapshot;

    ph1p_eth_pll u_eth_pll (
        .refclk(I_sys_clk),
        .reset(1'b0),
        .clk125(clk125),
        .clk125_90(clk125_90),
        .clk25(clk25),
        .locked(pll_locked)
    );

    uiphyrst #(.CLK_FREQ(32'd25_000_000)) u_eth_phy_reset (
        .I_CLK(clk25),
        .I_rstn(pll_locked),
        .I_phyrst(pll_locked),
        .O_phyrst(phy_reset_n)
    );
    assign O_phy_rst = phy_reset_n;

    eth_udp_video_tx u_video_packetizer (
        .I_pixel_clk(I_pixel_clk),
        .I_pixel_reset(~I_pixel_reset_n),
        .I_frame_start(I_pixel_frame_start),
        .I_frame_end(I_pixel_frame_end),
        .I_pixel_valid(I_pixel_valid),
        .I_rgb565(I_pixel_rgb565),
        .I_udp_clk(clk125),
        .I_udp_reset(stack_reset),
        .I_udp_busy(udp_busy),
        .O_udp_req(udp_req),
        .O_udp_valid(udp_valid),
        .O_udp_data(udp_data),
        .O_udp_len(udp_len),
        .O_fifo_overflow(fifo_overflow),
        .O_tx_packets(tx_packets),
        .O_tx_frames(tx_frames),
        .O_tx_state(tx_state)
    );

    always @(posedge clk125 or posedge stack_reset) begin
        if(stack_reset) begin
            fifo_overflow_meta <= 1'b0;
            fifo_overflow_sync <= 1'b0;
            phy_reset_meta <= 1'b0;
            phy_reset_sync <= 1'b0;
            pll_lock_meta <= 1'b0;
            pll_lock_sync <= 1'b0;
        end else begin
            fifo_overflow_meta <= fifo_overflow;
            fifo_overflow_sync <= fifo_overflow_meta;
            phy_reset_meta <= phy_reset_n;
            phy_reset_sync <= phy_reset_meta;
            pll_lock_meta <= pll_locked;
            pll_lock_sync <= pll_lock_meta;
        end
    end

    always @(posedge clk125 or posedge stack_reset) begin
        if(stack_reset) begin
            rgmii_status_meta <= 4'b0;
            rgmii_status_sync <= 4'b0;
        end else begin
            rgmii_status_meta <= {rgmii_duplex_status, rgmii_clock_speed,
                                  rgmii_link_status};
            rgmii_status_sync <= rgmii_status_meta;
        end
    end

    always @(posedge clk125 or posedge stack_reset) begin
        if(stack_reset) begin
            gmii_tvalid_d <= 1'b0;
            tx_activity_timer <= 26'd0;
            tx_led_blink_counter <= 25'd0;
            tx_led_blink <= 1'b0;
            network_error_latched <= 1'b0;
        end else begin
            gmii_tvalid_d <= gmii_tvalid;
            if(gmii_tvalid && !gmii_tvalid_d)
                tx_activity_timer <= LED_ACTIVITY_HOLD_CYCLES;
            else if(tx_activity_timer != 0)
                tx_activity_timer <= tx_activity_timer - 1'b1;

            if(tx_led_blink_counter == LED_BLINK_HALF_CYCLES - 1'b1) begin
                tx_led_blink_counter <= 25'd0;
                tx_led_blink <= ~tx_led_blink;
            end else begin
                tx_led_blink_counter <= tx_led_blink_counter + 1'b1;
            end

            if(fifo_overflow_sync || (bad_packets != 0))
                network_error_latched <= 1'b1;
        end
    end

    always @(posedge gmii_rclk or posedge stack_reset) begin
        if(stack_reset) begin
            gmii_rvalid_d <= 1'b0;
            rx_activity_timer <= 26'd0;
            rx_led_blink_counter <= 25'd0;
            rx_led_blink <= 1'b0;
        end else begin
            gmii_rvalid_d <= gmii_rvalid;
            if(gmii_rvalid && !gmii_rvalid_d)
                rx_activity_timer <= LED_ACTIVITY_HOLD_CYCLES;
            else if(rx_activity_timer != 0)
                rx_activity_timer <= rx_activity_timer - 1'b1;

            if(rx_led_blink_counter == LED_BLINK_HALF_CYCLES - 1'b1) begin
                rx_led_blink_counter <= 25'd0;
                rx_led_blink <= ~rx_led_blink;
            end else begin
                rx_led_blink_counter <= rx_led_blink_counter + 1'b1;
            end
        end
    end

    uiudp_stack #(
        .CRC_GEN_EN(1'b1),
        .INTER_FRAME_GAP(8'd12)
    ) u_udp_stack (
        .I_uclk(clk125),
        .I_reset(stack_reset),
        .I_mac_local_addr(48'h020000000001),
        .I_udp_local_port(16'd6001),
        .I_ip_local_addr(32'hc0a8320a),
        .I_udp_dest_port(16'd6002),
        .I_ip_dest_addr(32'hc0a83214),
        .O_W_udp_busy(udp_busy),
        .I_W_udp_req(udp_req),
        .I_W_udp_valid(udp_valid),
        .I_W_udp_data(udp_data),
        .I_W_udp_len(udp_len),
        .O_R_udp_valid(rx_udp_valid),
        .O_R_udp_data(rx_udp_data),
        .O_R_udp_len(rx_udp_len),
        .O_R_udp_src_port(rx_udp_src_port),
        .I_gmii_rclk(gmii_rclk),
        .I_gmii_rvalid(gmii_rvalid),
        .I_gmii_rdata(gmii_rdata),
        .I_gmii_tclk(clk125),
        .O_gmii_tvalid(gmii_tvalid),
        .O_gmii_tdata(gmii_tdata),
        .O_ip_rerror(),
        .O_mac_rerror(),
        .O_debug_status(stack_debug)
    );

    rgmii_interface u_rgmii_interface (
        .speed_10_100(1'b0),
        .gmii_tx_clk_d(clk125),
        .gmii_tx_reset_d(stack_reset),
        .gmii_tx_reset(stack_reset),
        .gmii_tx_clk(clk125),
        .gmii_txd(gmii_tdata),
        .gmii_tx_en(gmii_tvalid),
        .gmii_tx_er(1'b0),
        .gmii_rx_reset(stack_reset),
        .gmii_rx_clk(gmii_rclk),
        .gmii_rxd(gmii_rdata),
        .gmii_rx_dv(gmii_rvalid),
        .gmii_rx_er(),
        .rgmii_txd(O_a_rgmii_txd),
        .rgmii_tx_ctl(O_a_rgmii_tx_ctl),
        .rgmii_txc(O_a_rgmii_txc),
        .rgmii_rxd(I_a_rgmii_rxd),
        .rgmii_rx_ctl(I_a_rgmii_rx_ctl),
        .rgmii_rxc(I_a_rgmii_rxc),
        .gmii_crs(),
        .gmii_col(),
        .link_status(rgmii_link_status),
        .clock_speed(rgmii_clock_speed),
        .duplex_status(rgmii_duplex_status)
    );

    eth_udp_result_rx u_result_receiver (
        .I_clk(clk125),
        .I_reset(stack_reset),
        .I_dst_clk(I_shape_dst_clk),
        .I_rx_valid(rx_udp_valid),
        .I_rx_data(rx_udp_data),
        .I_rx_len(rx_udp_len),
        .I_rx_src_port(rx_udp_src_port),
        .O_reply_packets(reply_packets),
        .O_bad_packets(bad_packets),
        .O_remote_frames(remote_frames),
        .O_remote_errors(remote_errors),
        .O_remote_frame_id(remote_frame_id),
        .O_shape_valid(O_shape_valid),
        .O_shape_type(O_shape_type),
        .O_shape_x0(O_shape_x0),
        .O_shape_y0(O_shape_y0),
        .O_shape_x1(O_shape_x1),
        .O_shape_y1(O_shape_y1)
    );

    video_diag_cdc #(.WIDTH(245)) u_net_diag_cdc (
        .src_clk(clk125), .dst_clk(I_diag_dst_clk), .rst_n(~stack_reset),
        .data({tx_packets, tx_frames, reply_packets, bad_packets,
               remote_frames, remote_errors, remote_frame_id, net_status,
               stack_debug_diag}),
        .snapshot(net_diag_snapshot)
    );
    assign {O_tx_packets, O_tx_frames, O_reply_packets, O_bad_packets,
            O_remote_frames, O_remote_errors, O_remote_frame_id, O_net_status,
            O_stack_debug} =
           net_diag_snapshot;

    // The phase-shift output is generated for the PHY timing option but the
    // board reference interface uses its 2 ns output delay on clk125.
    wire unused_clk125_90 = clk125_90;
endmodule
