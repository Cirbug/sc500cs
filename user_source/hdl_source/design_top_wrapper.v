`include "video_params.vh"
// Keep the mailbox reachable from existing TD GUI/generated source lists.
`include "red_track_mailbox.v"

module design_top_wrapper (
    output wire O_sd_clk, O_sd_mosi, O_sd_cs,
    input wire I_sd_miso,
    input wire        I_sys_clk,
    input wire        I_rst_n,

    input wire        I_mcu_uart_rx,
    output wire       O_mcu_uart_tx,
    // ESP-01: module TXD -> E12/RX0, module RXD <- E16/TX0.
    input  wire       I_wifi_uart_rx,
    output wire       O_wifi_uart_tx,
    inout  wire       IO_wifi_reset_n,
    inout  wire       IO_wifi_gpio0,
    output wire       O_usb_sclk,
    input  wire       I_usb_miso,
    // MAX3421E uses this same pad as the return-data line while its
    // half-duplex SPI mode is active.  It must therefore be tri-stated during
    // QSPI receive phases instead of being a permanently driven output.
    inout  wire       O_usb_mosi,
    output wire       O_usb_ss_n,
    input  wire       I_usb_int_n,
    output wire       O_usb_res_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
    // Lens actuator I2C: SCL=R6, SDA=R7.
    inout  wire       O_lens_scl,
    inout  wire       IO_lens_sda,
    // DS3231 RTC I2C: SCL=D15, SDA=C18.  Both lines are open-drain.
    inout  wire       IO_rtc_scl,
    inout  wire       IO_rtc_sda,
    // Two hobby-servo control outputs, constrained to V6 and V4.
    output wire       O_servo_pan,
    output wire       O_servo_tilt,

    input wire [3:0]  I_button,

    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    // RISC-V core clock: PLL clk3_out, configured to 300 MHz.
    // Keep the 100 MHz clock for APB, timer and the video logic.
    wire        	S_mcu_300m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    // _9 post-DDR image branch.  The denoiser is kept as a side branch so
    // the existing DDR/HDMI timing and the current menu/OSD path stay intact.
    reg         S_video_de_1d;
    wire        S_video_dn_de;
    wire [23:0] S_video_dn_data;
    wire [23:0] S_shape_input_data;
    wire [7:0]  S_dn_noise;
    wire [7:0]  S_dn_mean_y;
    reg         S_isp_stat_t1, S_isp_stat_t2, S_isp_stat_t3;
    reg [7:0]   S_isp_sat_pre_hdmi, S_isp_sat_post_hdmi;
    reg [7:0]   S_isp_mean_r_hdmi, S_isp_mean_g_hdmi, S_isp_mean_b_hdmi;
    reg [7:0]   S_isp_min_r_hdmi;

    // _9 image-menu state. All four physical keys are handled by the MCU
    // menu; these values cross from the MCU APB clock into HDMI below.
    wire [2:0]  S_dbg_disp_mode;
    wire [2:0]  S_dbg_step;
    wire [2:0]  S_dbg_effect_sel;
    wire        S_dbg_awb_bypass;
    wire        S_dbg_recog_mode;
    wire        S_logo_enable;
    wire [1:0]  S_motion_target;
    reg         S_track_reacquire;

    wire        S_shape_valid;
    wire [2:0]  S_shape_type;
    wire [11:0] S_shape_x0, S_shape_y0, S_shape_x1, S_shape_y1;
    wire        S_motion_valid;
    wire [15:0] S_motion_count;
    wire [2:0]  S_motion_tvalid;
    wire [11:0] S_motion_x0_0, S_motion_y0_0, S_motion_x1_0, S_motion_y1_0;
    wire [11:0] S_motion_x0_1, S_motion_y0_1, S_motion_x1_1, S_motion_y1_1;
    wire [11:0] S_motion_x0_2, S_motion_y0_2, S_motion_x1_2, S_motion_y1_2;
    wire        S_color_valid;
    wire [2:0]  S_color_code;
    wire [15:0] S_color_count;
    wire [11:0] S_color_x0, S_color_y0, S_color_x1, S_color_y1;
    wire        S_track_new, S_track_valid;
    wire [1:0]  S_track_state, S_track_dx, S_track_dy, S_track_lx, S_track_ly;
    wire [11:0] S_track_x0, S_track_y0, S_track_x1, S_track_y1, S_track_cx, S_track_cy;
    wire signed [12:0] S_track_ex, S_track_ey;
    wire [6:0]  S_track_area;
    wire [31:0] S_track_status_apb, S_track_errors_apb;
    wire [23:0] S_hdmi_base_data;
    wire        S_hdmi_overlay_valid;
    wire        S_effect_vsync, S_effect_hsync, S_effect_de;
    wire [23:0] S_effect_data;
    wire        S_edge_vsync, S_edge_hsync, S_edge_de;
    wire [23:0] S_edge_data;
    wire        S_edge_flag;
    wire [7:0]  S_edge_gray;
    wire        S_final_vsync, S_final_hsync, S_final_de;
    wire [23:0] S_final_data;

    wire        S_mcu_apb_clk;
    wire [19:0] S_mcu_paddr;
    wire        S_mcu_psel;
    wire        S_mcu_penable;
    wire        S_mcu_pwrite;
    wire [31:0] S_mcu_pwdata;
    wire [3:0]  S_mcu_pstrobe;
    wire [2:0]  S_mcu_pprot;
    wire [31:0] S_mcu_prdata;
    wire        S_mcu_pready;
    wire        S_mcu_pslverr;
    // MCU AHB/QSPI/GPIO ports enabled in the regenerated IP.  AHB has no
    // slave in this design, so its return channel is tied to an always-ready
    // response. GPIO0..GPIO5 are used as a diagnostic bit-banged SPI link to
    // MAX3421E; GPIO6/7 and the MCU I2C pins are intentionally unused.
    wire        S_mcu_core_sysrst;
    wire        S_mcu_gpio0_in, S_mcu_gpio1_in, S_mcu_gpio3_in;
    wire        S_mcu_gpio4_in, S_mcu_gpio6_in, S_mcu_gpio7_in;
    // Preserve the two external SPI inputs so ChipWatch can probe them.
    (* keep *) wire S_mcu_gpio2_in;
    (* keep *) wire S_mcu_gpio5_in;
    wire        S_mcu_gpio0_out, S_mcu_gpio1_out, S_mcu_gpio2_out, S_mcu_gpio3_out;
    wire        S_mcu_gpio4_out, S_mcu_gpio5_out, S_mcu_gpio6_out, S_mcu_gpio7_out;
    wire        S_mcu_gpio0_dir, S_mcu_gpio1_dir, S_mcu_gpio2_dir, S_mcu_gpio3_dir;
    wire        S_mcu_gpio4_dir, S_mcu_gpio5_dir, S_mcu_gpio6_dir, S_mcu_gpio7_dir;
    wire        S_mcu_i2c_sda_out, S_mcu_i2c_sda_sel;
    wire        S_mcu_i2c_scl_out, S_mcu_i2c_scl_sel;
    wire        S_mcu_qspi1_clk;
    wire        S_mcu_qspi1_ss;
    wire        S_mcu_qspi1_d0_out;
    wire        S_mcu_qspi1_d1_out;
    wire        S_mcu_qspi1_d2_out;
    wire        S_mcu_qspi1_d3_out;
    wire [3:0]  S_mcu_qspi1_dir;
    wire        S_apb_usb_res_n;
    wire        S_apb_usb_spi_enable;
    wire        S_lens_cmd;
    wire [13:0] S_lens_position;
    wire        S_lens_busy;
    wire        S_lens_init_done;
    wire        S_lens_error;
    wire [31:0] S_lens_diag;
    wire [31:0] S_lens_tx_count;
    wire S_lens_retry, S_lens_read_adc;
    wire [31:0] S_lens_adc_raw, S_lens_adc_count, S_lens_bus_state;
    wire [7:0]  S_rtc_seconds, S_rtc_minutes, S_rtc_hours;
    wire [7:0]  S_rtc_day, S_rtc_date, S_rtc_month, S_rtc_year;
    wire        S_rtc_busy, S_rtc_valid, S_rtc_error, S_rtc_osf;
    wire [3:0]  S_rtc_fault;
    wire [31:0] S_rtc_read_count;
    wire [31:0] S_rtc_time0, S_rtc_time1, S_rtc_status;
    wire [31:0] S_rtc_set_time0, S_rtc_set_time1, S_rtc_set_status;
    wire S_rtc_set;
    wire [1:0] S_wifi_ctrl;
    (* async_reg="true" *) reg [1:0] S_wifi_pad_meta, S_wifi_pad_sync;
    // Open-drain control: reset defaults to release, GPIO0 defaults to
    // normal flash boot. External 3.3V pull-ups must hold both pins before
    // FPGA configuration too. Never actively drive against a module button.
    assign IO_wifi_reset_n = S_wifi_ctrl[0] ? 1'b0 : 1'bz;
    assign IO_wifi_gpio0 = S_wifi_ctrl[1] ? 1'b0 : 1'bz;
    always @(posedge S_mcu_apb_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin S_wifi_pad_meta<=2'b11; S_wifi_pad_sync<=2'b11; end
        else begin S_wifi_pad_meta<={IO_wifi_gpio0,IO_wifi_reset_n}; S_wifi_pad_sync<=S_wifi_pad_meta; end
    end
    wire [31:0] S_focus_roi_apb;
    (* async_reg="true" *) reg [31:0] S_focus_roi_p1, S_focus_roi_p2;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_focus_roi_p1<=32'h01e00370; S_focus_roi_p2<=32'h01e00370;
        end else begin
            S_focus_roi_p1<=S_focus_roi_apb; S_focus_roi_p2<=S_focus_roi_p1;
        end
    end
    wire [31:0] S_focus_metric_pix;
    wire [31:0] S_focus_metric_apb;
    wire [15:0] S_servo_pan_us;
    wire [15:0] S_servo_tilt_us;
    wire        S_focus_frame_toggle;
    reg [31:0]  S_focus_metric_sync1;
    reg [31:0]  S_focus_metric_sync2;
    reg         S_cam_cfg_done_apb1;
    reg         S_cam_cfg_done_apb2;
    // MAX3421E is driven by MCU QSPI1 in single-SPI mode.
    assign S_mcu_gpio0_in = 1'b0;
    assign S_mcu_gpio1_in = 1'b0;
    assign S_mcu_gpio2_in = I_usb_miso;
    assign S_mcu_gpio3_in = 1'b0;
    assign S_mcu_gpio4_in = 1'b0;
    assign S_mcu_gpio5_in = I_usb_int_n;
    assign S_mcu_gpio6_in = 1'b0;
    assign S_mcu_gpio7_in = 1'b0;
    // Set to 1 only for the standalone U4 key test bit. The normal design
    // remains the QSPI1 routing in the else branch.
    localparam USB_U4_KEY_TEST = 1'b0;
    wire [3:0] u4_key_pulse;
    reg  u4_test_level;
    genvar u4_key_i;
    generate
        for (u4_key_i = 0; u4_key_i < 4; u4_key_i = u4_key_i + 1) begin : g_u4_key_debounce
            key_remove_shakes u_u4_key_test (
                .I_clk          ( S_100m_clk ),
                .I_rst_n        ( S_rst_n ),
                .I_key_in       ( I_button[u4_key_i] ),
                .O_key_trig_out ( u4_key_pulse[u4_key_i] )
            );
        end
    endgenerate
    always @(posedge S_100m_clk or negedge S_rst_n) begin
        if (!S_rst_n)
            u4_test_level <= 1'b1;
        else if (|u4_key_pulse)
            u4_test_level <= ~u4_test_level;
    end
    generate
        if (USB_U4_KEY_TEST) begin : g_u4_key_test
            assign O_usb_sclk = 1'b0;
            assign O_usb_mosi = 1'b0;
            assign O_usb_ss_n = u4_test_level;
            assign O_usb_res_n = S_rst_n;
        end else begin : g_usb_qspi_normal
            assign O_usb_sclk = (S_rst_n && S_apb_usb_spi_enable) ? S_mcu_qspi1_clk : 1'b0;
            // MAX3421E is configured for full-duplex SPI.  Keep C8 as the
            // master MOSI output for both the command and the 0x00 dummy
            // byte; the response is sampled from the separate B10/MISO pad.
            // Do not use qspi1_dir here: releasing C8 would select the
            // MAX3421E half-duplex turnaround protocol instead.
            assign O_usb_mosi = (S_rst_n && S_apb_usb_spi_enable)
                              ? S_mcu_qspi1_d0_out : 1'bz;
            assign O_usb_ss_n = (S_rst_n && S_apb_usb_spi_enable) ? S_mcu_qspi1_ss : 1'b1;
            // Diagnostic mode: keep MAX3421E /RES released after FPGA reset.
            // The pin is still low while the FPGA itself is in reset.
            assign O_usb_res_n = S_rst_n;
        end
    endgenerate
    (* keep *) wire        S_mcu_ahb_clk;
    (* keep *) wire [1:0]  S_mcu_htrans;
    (* keep *) wire        S_mcu_hwrite;
    (* keep *) wire [30:0] S_mcu_haddr;
    (* keep *) wire [2:0]  S_mcu_hsize;
    (* keep *) wire [2:0]  S_mcu_hburst;
    (* keep *) wire [3:0]  S_mcu_hprot;
    (* keep *) wire        S_mcu_hmastlock;
    (* keep *) wire [31:0] S_mcu_hwdata;
    wire [31:0] S_mcu_hrdata;
    wire [1:0]  S_mcu_hresp;
    wire        S_mcu_hready;
    assign S_mcu_hrdata = 32'd0;
    assign S_mcu_hresp  = 2'b00;
    assign S_mcu_hready = 1'b1;
    wire        S_ui_enable_apb;
    wire        S_ui_edit_apb;
    wire        S_ui_info_apb;
    wire [2:0]  S_ui_index_apb;
    wire S_picture_page_apb;
    wire S_mode_page_apb;
    reg S_mode_page_p1, S_mode_page_p2;
    reg S_picture_page_p1, S_picture_page_p2;
    wire [15:0] S_picture_apb, S_picture_isp, S_picture_pixel;
    picture_control_cdc u_picture_isp (
        .src_clk(S_mcu_apb_clk), .dst_clk(S_csi_rx_clk), .rst_n(S_rst_n),
        .requested(S_picture_apb), .frame_start(S_raw_tuser), .active(S_picture_isp)
    );
    picture_control_cdc u_picture_pixel (
        .src_clk(S_mcu_apb_clk), .dst_clk(S_hdmi_pixel_clk), .rst_n(S_rst_n),
        .requested(S_picture_apb), .frame_start(S_hdmi_vsync), .active(S_picture_pixel)
    );
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_picture_page_p1<=0; S_picture_page_p2<=0;
            S_mode_page_p1<=0; S_mode_page_p2<=0;
        end else begin
            S_picture_page_p1<=S_picture_page_apb; S_picture_page_p2<=S_picture_page_p1;
            S_mode_page_p1<=S_mode_page_apb; S_mode_page_p2<=S_mode_page_p1;
        end
    end
    wire [15:0] S_ui_vts_apb,S_cam_vts;
    wire [47:0] S_camera_settings;
    wire [22:0] S_camera_display_apb,S_camera_display_pixel;
    wire [15:0] S_ui_ae_apb;
    wire [15:0] S_ui_ag_apb;
    wire [2:0]  S_image_step_apb;
    wire [2:0]  S_image_effect_apb;
    wire [1:0]  S_image_target_apb;
    wire        S_image_logo_apb;
    wire        S_image_track_toggle_apb;
    reg         S_ui_enable_p1, S_ui_enable_p2;
    reg         S_ui_edit_p1, S_ui_edit_p2;
    reg         S_ui_info_p1, S_ui_info_p2;
    reg [2:0]   S_ui_index_p1, S_ui_index_p2;
    reg [15:0]  S_ui_ae_p1, S_ui_ae_p2;
    reg [15:0]  S_ui_ag_p1, S_ui_ag_p2;
    reg [15:0]  S_ui_servo_pan_p1, S_ui_servo_pan_p2;
    reg [15:0]  S_ui_servo_tilt_p1, S_ui_servo_tilt_p2;
    reg [7:0]   S_rtc_hours_p1, S_rtc_hours_p2;
    reg [7:0]   S_rtc_minutes_p1, S_rtc_minutes_p2;
    reg [7:0]   S_rtc_seconds_p1, S_rtc_seconds_p2;
    reg         S_rtc_valid_p1, S_rtc_valid_p2;
    reg         S_rtc_error_p1, S_rtc_error_p2;
    reg         S_rtc_osf_p1, S_rtc_osf_p2;
    (* async_reg="true" *) reg [15:0] S_rtc_count_p1, S_rtc_count_p2;
    reg [15:0] S_rtc_count_p3, S_rtc_count_seen;
    reg [2:0]   S_image_step_p1, S_image_step_p2;
    reg [2:0]   S_image_effect_p1, S_image_effect_p2;
    reg [1:0]   S_image_target_p1, S_image_target_p2;
    reg         S_image_logo_p1, S_image_logo_p2;
    reg         S_image_track_p1, S_image_track_p2, S_image_track_seen;
    wire        S_osd_vsync;
    wire        S_osd_hsync;
    wire        S_osd_de;
    wire [23:0] S_osd_data;

    // MCU retains _9 hardware IDs 2..5: normal, shape, motion, red tracking.
    // Original ID 1 is removed; the OSD numbers the remaining modes 1..4.
    assign S_dbg_step       = S_image_step_p2;
    assign S_dbg_disp_mode  = (S_image_step_p2 >= 3'd3) ? 3'd0 : 3'd5;
    assign S_dbg_recog_mode = (S_image_step_p2 >= 3'd3);
    assign S_dbg_effect_sel = (S_image_step_p2 >= 3'd3) ? 3'd0 : S_image_effect_p2;
    assign S_dbg_awb_bypass = 1'b0;
    assign S_motion_target  = S_image_target_p2;
    assign S_logo_enable    = S_image_logo_p2;

    assign S_focus_metric_apb = S_focus_metric_sync2;

    // Synchronize the frame metric and camera-config completion into the MCU
    // APB clock domain.  The metric remains stable for a complete frame.
    always @(posedge S_mcu_apb_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_focus_metric_sync1 <= 32'd0;
            S_focus_metric_sync2 <= 32'd0;
            S_cam_cfg_done_apb1  <= 1'b0;
            S_cam_cfg_done_apb2  <= 1'b0;
        end else begin
            S_focus_metric_sync1 <= S_focus_metric_pix;
            S_focus_metric_sync2 <= S_focus_metric_sync1;
            S_cam_cfg_done_apb1  <= S_cam_cfg_done;
            S_cam_cfg_done_apb2  <= S_cam_cfg_done_apb1;
        end
    end

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    reg         S_dbg_hs_valid_d;
    reg [10:0]  S_dbg_csi_words;
    reg [10:0]  S_dbg_good_lines;
    reg         S_dbg_frame_seen_once;
    reg         S_dbg_frame_repeat_seen;
    reg         S_dbg_width_1920_seen;
    reg         S_dbg_height_1080_seen;
    reg         S_dbg_isp_frame_seen_once;
    reg         S_dbg_isp_frame_repeat_seen;
    reg [1:0]   S_dbg_frame_repeat_sync;
    reg [1:0]   S_dbg_width_1920_sync;
    reg [1:0]   S_dbg_height_1080_sync;
    reg [1:0]   S_dbg_isp_frame_repeat_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;


    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    // RAW10 2592-pixel lines contain 3240 payload bytes, or 810 valid
    // 32-bit words after csi_unpacket.  Count complete lines and frames so
    // the on-screen diagnostic verifies the sensor's actual output format.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_hs_valid_d             <= 1'b0;
            S_dbg_csi_words              <= 11'd0;
            S_dbg_good_lines             <= 11'd0;
            S_dbg_frame_seen_once        <= 1'b0;
            S_dbg_frame_repeat_seen      <= 1'b0;
            S_dbg_width_1920_seen        <= 1'b0;
            S_dbg_height_1080_seen       <= 1'b0;
            S_dbg_isp_frame_seen_once    <= 1'b0;
            S_dbg_isp_frame_repeat_seen  <= 1'b0;
        end
        else begin
            S_dbg_hs_valid_d <= S_hs_rx_valid;

            if(!S_dbg_hs_valid_d && S_hs_rx_valid)
                S_dbg_csi_words <= 11'd0;
            else if(S_csi_valid)
                S_dbg_csi_words <= S_dbg_csi_words + 11'd1;

            if(S_dbg_hs_valid_d && !S_hs_rx_valid && (S_dbg_csi_words != 0)) begin
                if(S_dbg_csi_words == 11'd810) begin
                    S_dbg_width_1920_seen <= 1'b1;
                    S_dbg_good_lines <= S_dbg_good_lines + 11'd1;
                end
            end

            if(S_csi_frame_start) begin
                if(S_dbg_frame_seen_once) begin
                    S_dbg_frame_repeat_seen <= 1'b1;
                    if(S_dbg_good_lines == 11'd1944)
                        S_dbg_height_1080_seen <= 1'b1;
                end
                else
                    S_dbg_frame_seen_once <= 1'b1;
                S_dbg_good_lines <= 11'd0;
            end

            if(S_ISP_O_tuser) begin
                if(S_dbg_isp_frame_seen_once)
                    S_dbg_isp_frame_repeat_seen <= 1'b1;
                else
                    S_dbg_isp_frame_seen_once <= 1'b1;
            end
        end
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
            S_dbg_frame_repeat_sync <= 2'b00;
            S_dbg_width_1920_sync <= 2'b00;
            S_dbg_height_1080_sync <= 2'b00;
            S_dbg_isp_frame_repeat_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            S_dbg_frame_repeat_sync <= {S_dbg_frame_repeat_sync[0], S_dbg_frame_repeat_seen};
            S_dbg_width_1920_sync <= {S_dbg_width_1920_sync[0], S_dbg_width_1920_seen};
            S_dbg_height_1080_sync <= {S_dbg_height_1080_sync[0], S_dbg_height_1080_seen};
            S_dbg_isp_frame_repeat_sync <= {S_dbg_isp_frame_repeat_sync[0], S_dbg_isp_frame_repeat_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status = {
        S_dbg_height_1080_sync[1] & S_dbg_isp_frame_repeat_sync[1],
        S_dbg_width_1920_sync[1],
        S_dbg_frame_repeat_sync[1],
        S_dbg_cam_cfg_seen_sync[1]
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;

    camera_menu_cdc #(.WIDTH(48),.RESET_VALUE({16'd3990,16'd80,16'd2000})) u_camera_settings (
        .src_clk(S_mcu_apb_clk),.dst_clk(S_24m_clk),.rst_n(S_rst_n),
        .requested({S_ui_ae_apb,S_ui_ag_apb,S_ui_vts_apb}),.active(S_camera_settings));
    camera_menu_cdc #(.WIDTH(23),.RESET_VALUE({7'd127,16'h2000})) u_camera_display (
        .src_clk(S_mcu_apb_clk),.dst_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .requested(S_camera_display_apb),.active(S_camera_display_pixel));

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_ui_enable_p1 <= 1'b0;
            S_ui_enable_p2 <= 1'b0;
            S_ui_edit_p1   <= 1'b0;
            S_ui_edit_p2   <= 1'b0;
            S_ui_info_p1   <= 1'b0;
            S_ui_info_p2   <= 1'b0;
            S_ui_index_p1  <= 3'd0;
            S_ui_index_p2  <= 3'd0;
            S_ui_ae_p1     <= 16'd5990;
            S_ui_ae_p2     <= 16'd5990;
            S_ui_ag_p1     <= 16'd80;
            S_ui_ag_p2     <= 16'd80;
            S_ui_servo_pan_p1  <= 16'd1500;
            S_ui_servo_pan_p2  <= 16'd1500;
            S_ui_servo_tilt_p1 <= 16'd1500;
            S_ui_servo_tilt_p2 <= 16'd1500;
            S_rtc_hours_p1   <= 8'd0;
            S_rtc_hours_p2   <= 8'd0;
            S_rtc_minutes_p1 <= 8'd0;
            S_rtc_minutes_p2 <= 8'd0;
            S_rtc_seconds_p1 <= 8'd0;
            S_rtc_seconds_p2 <= 8'd0;
            S_rtc_valid_p1   <= 1'b0;
            S_rtc_valid_p2   <= 1'b0;
            S_rtc_error_p1   <= 1'b0;
            S_rtc_error_p2   <= 1'b0;
            S_rtc_osf_p1     <= 1'b1;
            S_rtc_osf_p2     <= 1'b1;
            S_rtc_count_p1   <= 0; S_rtc_count_p2 <= 0;
            S_rtc_count_p3   <= 0; S_rtc_count_seen <= 0;
            S_image_step_p1    <= 3'd2;
            S_image_step_p2    <= 3'd2;
            S_image_effect_p1  <= 3'd0;
            S_image_effect_p2  <= 3'd0;
            S_image_target_p1  <= 2'd0;
            S_image_target_p2  <= 2'd0;
            S_image_logo_p1    <= 1'b1;
            S_image_logo_p2    <= 1'b1;
            S_image_track_p1   <= 1'b0;
            S_image_track_p2   <= 1'b0;
            S_image_track_seen <= 1'b0;
            S_track_reacquire  <= 1'b0;
        end else begin
            S_ui_enable_p1 <= S_ui_enable_apb;
            S_ui_enable_p2 <= S_ui_enable_p1;
            S_ui_edit_p1   <= S_ui_edit_apb;
            S_ui_edit_p2   <= S_ui_edit_p1;
            S_ui_info_p1   <= S_ui_info_apb;
            S_ui_info_p2   <= S_ui_info_p1;
            S_ui_index_p1  <= S_ui_index_apb;
            S_ui_index_p2  <= S_ui_index_p1;
            S_ui_ae_p1     <= S_ui_ae_apb;
            S_ui_ae_p2     <= S_ui_ae_p1;
            S_ui_ag_p1     <= S_ui_ag_apb;
            S_ui_ag_p2     <= S_ui_ag_p1;
            S_ui_servo_pan_p1  <= S_servo_pan_us;
            S_ui_servo_pan_p2  <= S_ui_servo_pan_p1;
            S_ui_servo_tilt_p1 <= S_servo_tilt_us;
            S_ui_servo_tilt_p2 <= S_ui_servo_tilt_p1;
            S_rtc_hours_p1   <= S_rtc_hours;
            S_rtc_minutes_p1 <= S_rtc_minutes;
            S_rtc_seconds_p1 <= S_rtc_seconds;
            S_rtc_count_p1 <= S_rtc_read_count[15:0];
            S_rtc_count_p2 <= S_rtc_count_p1;
            S_rtc_count_p3 <= S_rtc_count_p2;
            // Time is held for a second in the source clock domain. The
            // synchronized completion counter reaches this capture after
            // the complete time bundle has had two extra clocks to settle.
            if(S_rtc_count_p3 != S_rtc_count_seen) begin
                S_rtc_count_seen <= S_rtc_count_p3;
                S_rtc_hours_p2 <= S_rtc_hours_p1;
                S_rtc_minutes_p2 <= S_rtc_minutes_p1;
                S_rtc_seconds_p2 <= S_rtc_seconds_p1;
            end
            S_rtc_valid_p1   <= S_rtc_valid;
            S_rtc_valid_p2   <= S_rtc_valid_p1;
            S_rtc_error_p1   <= S_rtc_error;
            S_rtc_error_p2   <= S_rtc_error_p1;
            S_rtc_osf_p1     <= S_rtc_osf;
            S_rtc_osf_p2     <= S_rtc_osf_p1;
            S_image_step_p1    <= S_image_step_apb;
            S_image_step_p2    <= S_image_step_p1;
            S_image_effect_p1  <= S_image_effect_apb;
            S_image_effect_p2  <= S_image_effect_p1;
            S_image_target_p1  <= S_image_target_apb;
            S_image_target_p2  <= S_image_target_p1;
            S_image_logo_p1    <= S_image_logo_apb;
            S_image_logo_p2    <= S_image_logo_p1;
            S_image_track_p1   <= S_image_track_toggle_apb;
            S_image_track_p2   <= S_image_track_p1;
            S_track_reacquire  <= S_image_track_p2 ^ S_image_track_seen;
            S_image_track_seen <= S_image_track_p2;
        end
    end
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),
        .clk2_out    ( S_mcu_apb_clk     ),
        .clk3_out    ( S_mcu_300m_clk    ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );

    // TD derives the generated MCU_JTAG_SEL from JTAG_Available. Regenerating
    // USART0 restored "1" (PIB), disconnecting the board's PAD debug chain.
    // Keep this board-level override outside generated IP so regeneration
    // cannot silently switch away from the one-cable PAD connection.
    defparam u_mcu.MCU_521bd43d073e_Inst.MCU_JTAG_SEL = "0";
    RISCV_F6F1D1P0_0 u_mcu (
        .core_sysrst ( S_mcu_core_sysrst ),
        // Constant inputs require MCU_JTAG_SEL="0" (PAD path) in the IP.
        // MCU_JTAG_SEL="1" selects the fabric/PIB inputs below; tying those
        // inputs low does not provide an active MCU debug connection.
        .jtag_tck    ( 1'b0               ),
        .jtag_tms    ( 1'b0               ),
        .jtag_tdi    ( 1'b0               ),
        .jtag_tdo    (                    ),
        .gpio0_in    ( S_mcu_gpio0_in    ),
        .gpio0_out   ( S_mcu_gpio0_out   ),
        .gpio0_dir   ( S_mcu_gpio0_dir   ),
        .gpio1_in    ( S_mcu_gpio1_in    ),
        .gpio1_out   ( S_mcu_gpio1_out   ),
        .gpio1_dir   ( S_mcu_gpio1_dir   ),
        .gpio2_in    ( S_mcu_gpio2_in    ),
        .gpio2_out   ( S_mcu_gpio2_out   ),
        .gpio2_dir   ( S_mcu_gpio2_dir   ),
        .gpio3_in    ( S_mcu_gpio3_in    ),
        .gpio3_out   ( S_mcu_gpio3_out   ),
        .gpio3_dir   ( S_mcu_gpio3_dir   ),
        .gpio4_in    ( S_mcu_gpio4_in    ),
        .gpio4_out   ( S_mcu_gpio4_out   ),
        .gpio4_dir   ( S_mcu_gpio4_dir   ),
        .gpio5_in    ( S_mcu_gpio5_in    ),
        .gpio5_out   ( S_mcu_gpio5_out   ),
        .gpio5_dir   ( S_mcu_gpio5_dir   ),
        .gpio6_in    ( S_mcu_gpio6_in    ),
        .gpio6_out   ( S_mcu_gpio6_out   ),
        .gpio6_dir   ( S_mcu_gpio6_dir   ),
        .gpio7_in    ( S_mcu_gpio7_in    ),
        .gpio7_out   ( S_mcu_gpio7_out   ),
        .gpio7_dir   ( S_mcu_gpio7_dir   ),
        .uart0_tx    ( O_wifi_uart_tx     ),
        .uart0_rx    ( I_wifi_uart_rx     ),
        .uart1_tx    ( O_mcu_uart_tx      ),
        .uart1_rx    ( I_mcu_uart_rx      ),
        .i2c_sda_in  ( 1'b0               ),
        .i2c_sda_out ( S_mcu_i2c_sda_out  ),
        .i2c_sda_sel ( S_mcu_i2c_sda_sel  ),
        .i2c_scl_in  ( 1'b0               ),
        .i2c_scl_out ( S_mcu_i2c_scl_out  ),
        .i2c_scl_sel ( S_mcu_i2c_scl_sel  ),
        // QSPI1 single-SPI mode: D0=MOSI/half-duplex return, D1=MISO in
        // full-duplex mode. QSPI0 is hardwired to the FPGA configuration
        // flash; QSPI1 is the external MAX3421E interface below.
        .qspi1_clk   ( S_mcu_qspi1_clk    ),
        .qspi1_ss    ( S_mcu_qspi1_ss     ),
        // The PH1P SINGLE receive path differs between MCU IP revisions
        // (some sample D0, others sample D1). Mirror the external MAX3421E
        // MISO pad into both receive inputs; MOSI is still driven only by
        // qspi1_d0_out/C8, so this cannot create a second external driver.
        .qspi1_d0_in ( I_usb_miso         ),
        .qspi1_d1_in ( I_usb_miso         ),
        .qspi1_d2_in ( 1'b0               ),
        .qspi1_d3_in ( 1'b0               ),
        .qspi1_d0_out( S_mcu_qspi1_d0_out ),
        .qspi1_d1_out( S_mcu_qspi1_d1_out ),
        .qspi1_d2_out( S_mcu_qspi1_d2_out ),
        .qspi1_d3_out( S_mcu_qspi1_d3_out ),
        .qspi1_dir   ( S_mcu_qspi1_dir    ),
        // AHB is enabled in the regenerated IP.  There is no AHB slave in
        // this design, so return an idle, zero-data, zero-error response.
        .ahb_clk     ( S_mcu_ahb_clk      ),
        .htrans      ( S_mcu_htrans       ),
        .hwrite      ( S_mcu_hwrite       ),
        .haddr       ( S_mcu_haddr        ),
        .hsize       ( S_mcu_hsize        ),
        .hburst      ( S_mcu_hburst       ),
        .hprot       ( S_mcu_hprot        ),
        .hmastlock   ( S_mcu_hmastlock    ),
        .hwdata      ( S_mcu_hwdata       ),
        .hrdata      ( S_mcu_hrdata       ),
        .hresp       ( S_mcu_hresp        ),
        .hready      ( S_mcu_hready       ),
        .apb_clk     ( S_mcu_apb_clk      ),
        .apb_rst     ( ~S_rst_n           ),
        .paddr       ( S_mcu_paddr        ),
        .psel        ( S_mcu_psel         ),
        .penable     ( S_mcu_penable      ),
        .pwrite      ( S_mcu_pwrite       ),
        .pwdata      ( S_mcu_pwdata       ),
        .pstrobe     ( S_mcu_pstrobe      ),
        .pprot       ( S_mcu_pprot        ),
        .prdata      ( S_mcu_prdata       ),
        .pready      ( S_mcu_pready       ),
        .pslverr     ( S_mcu_pslverr      ),
        .core_clk    ( S_mcu_300m_clk     ),
        .timer_clk   ( S_100m_clk         ),
        .core_reset  ( ~S_rst_n           ),
        .por_reset   ( ~S_rst_n           ),
        .nmi         ( 1'b0               ),
        .clic_irq    ( 23'd0              )
    );

    lens_i2c_ctrl #(
        .CLK_DIV       ( 16'd499 ), // 50 MHz APB clock -> approximately 100 kHz I2C
        .INIT_POSITION ( 14'd8192 )
    ) u_lens_i2c_ctrl (
        .I_clk         ( S_mcu_apb_clk ),
        .I_rst_n       ( S_rst_n ),
        .I_cfg_done    ( S_cam_cfg_done_apb2 ),
        .I_cmd_valid   ( S_lens_cmd ),
        .I_retry       ( S_lens_retry ),
        .I_read_adc    ( S_lens_read_adc ),
        .I_position    ( S_lens_position ),
        .O_scl         ( O_lens_scl ),
        .IO_sda        ( IO_lens_sda ),
        .O_busy        ( S_lens_busy ),
        .O_init_done   ( S_lens_init_done ),
        .O_error       ( S_lens_error ),
        .O_diag        ( S_lens_diag ),
        .O_tx_count    ( S_lens_tx_count ),
        .O_adc_raw     ( S_lens_adc_raw ),
        .O_adc_count   ( S_lens_adc_count ),
        .O_bus_state   ( S_lens_bus_state )
    );

    // DS3231 is on its own bus so VCM recovery and MAX3421E traffic cannot
    // disturb the clock.  The controller returns raw BCD values through APB.
    ds3231_i2c_ctrl #(
        .CLK_DIV      ( 16'd499 ),
        .POLL_CYCLES  ( 32'd50000000 ),
        .GAP_CYCLES   ( 32'd1000 )
    ) u_ds3231_i2c_ctrl (
        .I_set(S_rtc_set), .I_set_time0(S_rtc_set_time0), .I_set_time1(S_rtc_set_time1),
        .O_set_status(S_rtc_set_status),
        .I_clk        ( S_mcu_apb_clk ),
        .I_rst_n      ( S_rst_n ),
        .IO_scl       ( IO_rtc_scl ),
        .IO_sda       ( IO_rtc_sda ),
        .O_seconds    ( S_rtc_seconds ),
        .O_minutes    ( S_rtc_minutes ),
        .O_hours      ( S_rtc_hours ),
        .O_day        ( S_rtc_day ),
        .O_date       ( S_rtc_date ),
        .O_month      ( S_rtc_month ),
        .O_year       ( S_rtc_year ),
        .O_busy       ( S_rtc_busy ),
        .O_valid      ( S_rtc_valid ),
        .O_error      ( S_rtc_error ),
        .O_fault      ( S_rtc_fault ),
        .O_osf        ( S_rtc_osf ),
        .O_read_count ( S_rtc_read_count )
    );

    assign S_rtc_time0 = {8'd0, S_rtc_hours, S_rtc_minutes, S_rtc_seconds};
    assign S_rtc_time1 = {S_rtc_year, S_rtc_month, S_rtc_date, S_rtc_day};
    // [31:16] successful read count, [15:8] reserved, [7] OSF, [6:3] fault,
    // [2] error, [1] valid, [0] busy.
    assign S_rtc_status = {S_rtc_read_count[15:0], 8'd0, S_rtc_osf, S_rtc_fault,
                           S_rtc_error, S_rtc_valid, S_rtc_busy};

    // 50 MHz APB clock: 20 ns/count, so 1 us equals 50 counts.
    servo_pwm_2ch u_servo_pwm_2ch (
        .I_clk       ( S_mcu_apb_clk  ),
        .I_rst_n     ( S_rst_n         ),
        // Use the reset-safe APB copies.  The raw APB outputs can change in
        // the same cycle as MCU startup; feeding them directly to PWM can
        // create a malformed first pulse.
        .I_pan_us    ( S_ui_servo_pan_p2  ),
        .I_tilt_us   ( S_ui_servo_tilt_p2 ),
        .O_pan       ( O_servo_pan    ),
        .O_tilt      ( O_servo_tilt   )
    );


    wire [31:0] rec_rdata, legacy_rdata, rec_ui_status;
    wire legacy_ready, legacy_error;
    wire rec_select=(S_mcu_paddr[19:12]==8'h01);
    wire rec_block, rec_wr, rec_rd, video_read_valid;
    wire [24:0] rec_addr;
    wire [127:0] rec_data;
    assign S_mcu_prdata=rec_select?rec_rdata:legacy_rdata;
    assign S_mcu_pready=rec_select?1'b1:legacy_ready;
    assign S_mcu_pslverr=rec_select?1'b0:legacy_error;
    sd_recorder u_recorder (
        .rst_n(S_rst_n), .apb_clk(S_mcu_apb_clk),
        .pixel_clk(S_hdmi_pixel_clk), .ddr_clk(S_ddr_clk),
        .addr(S_mcu_paddr[7:0]), .sel(S_mcu_psel && rec_select),
        .enable(S_mcu_penable), .write(S_mcu_pwrite), .wdata(S_mcu_pwdata),
        .rdata(rec_rdata), .vs(S_edge_vsync), .de(S_edge_de), .rgb(S_edge_data),
        .sd_clk(O_sd_clk), .sd_mosi(O_sd_mosi), .sd_cs(O_sd_cs), .sd_miso(I_sd_miso),
        .vi_busy(S_video_in_wr_busy), .vo_busy(S_video_out_rd_busy),
        .vo_read(S_vo_ddr_rd_en), .ready(S_ddr_user_ready),
        .rd_valid(S_ddr_user_rd_valid), .rd_data(S_ddr_user_rd_data),
        .block_video(rec_block), .wr_en(rec_wr), .rd_en(rec_rd),
        .mem_addr(rec_addr), .mem_data(rec_data),
        .video_rd_valid(video_read_valid), .ui_status(rec_ui_status)
    );

    mcu_ui_apb_regs u_mcu_ui_apb_regs (
        .I_clk         ( S_mcu_apb_clk ),
        .I_rst         ( ~S_rst_n ),
        .I_button      ( I_button ),
        .I_usb_int_n   ( I_usb_int_n ),
        .O_usb_res_n   ( S_apb_usb_res_n ),
        .O_usb_spi_enable ( S_apb_usb_spi_enable ),
        .I_paddr       ( S_mcu_paddr ),
        .I_psel        ( S_mcu_psel && !rec_select ),
        .I_penable     ( S_mcu_penable ),
        .I_pwrite      ( S_mcu_pwrite ),
        .I_pwdata      ( S_mcu_pwdata ),
        .I_pstrobe     ( S_mcu_pstrobe ),
        .O_prdata      ( legacy_rdata ),
        .O_pready      ( legacy_ready ),
        .O_pslverr     ( legacy_error ),
        .O_menu_enable ( S_ui_enable_apb ),
        .O_edit_enable ( S_ui_edit_apb ),
        .O_info_enable ( S_ui_info_apb ),
        .O_menu_index  ( S_ui_index_apb ),
        .O_picture_page( S_picture_page_apb ),
        .O_mode_page   ( S_mode_page_apb ),
        .O_picture_ctrl( S_picture_apb ),
        .O_exposure    ( S_ui_ae_apb ),
        .O_vts(S_ui_vts_apb), .O_camera_display(S_camera_display_apb),
        .O_gain        ( S_ui_ag_apb ),
        .O_image_step  ( S_image_step_apb ),
        .O_image_effect( S_image_effect_apb ),
        .O_image_target( S_image_target_apb ),
        .O_image_logo_enable( S_image_logo_apb ),
        .O_image_track_toggle( S_image_track_toggle_apb ),
        .I_lens_busy   ( S_lens_busy ),
        .I_lens_init_done( S_lens_init_done ),
        .I_lens_error  ( S_lens_error ),
        .I_lens_diag   ( S_lens_diag ),
        .I_lens_tx_count( S_lens_tx_count ),
        .I_lens_adc_raw( S_lens_adc_raw ),
        .I_lens_adc_count( S_lens_adc_count ),
        .I_lens_bus_state( S_lens_bus_state ),
        .I_focus_metric( S_focus_metric_apb ),
        .O_focus_roi   ( S_focus_roi_apb ),
        .I_rtc_time0   ( S_rtc_time0 ),
        .I_rtc_time1   ( S_rtc_time1 ),
        .I_rtc_status  ( S_rtc_status ),
        .O_rtc_set_time0(S_rtc_set_time0), .O_rtc_set_time1(S_rtc_set_time1),
        .O_rtc_set(S_rtc_set), .I_rtc_set_status(S_rtc_set_status),
        .O_wifi_ctrl(S_wifi_ctrl), .I_wifi_pads(S_wifi_pad_sync),
        .I_track_status(S_track_status_apb), .I_track_errors(S_track_errors_apb),
        .O_lens_cmd    ( S_lens_cmd ),
        .O_lens_retry  ( S_lens_retry ),
        .O_lens_read_adc( S_lens_read_adc ),
        .O_lens_position( S_lens_position ),
        .O_servo_pan_us ( S_servo_pan_us ),
        .O_servo_tilt_us( S_servo_tilt_us )
    );


	

  
  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn(4'b1111),
      .I_mcu_control_en(1'b1),
      .I_mcu_ae(S_camera_settings[47:32]),
      .I_mcu_ag(S_camera_settings[31:16]),
      .I_mcu_vts(S_camera_settings[15:0]),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag),
      .O_vts(S_cam_vts)
  );
  
    uicfgcs500 #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .I_vts(S_cam_vts),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(`SENSOR_WIDTH),
.IMG_HEIGHT(`SENSOR_HEIGHT),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// The legacy image_correction block is fixed at 1024 pixels per line and
// would truncate the official 1920x1080 stream.  The official SC500 example
// sends the native RAW10 AXI stream directly into the ISP.
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


// ISP algorithm top level.  The image algorithm now follows the _9 project:
// frame-level AWB -> chroma coring -> saturation -> linear downscale ->
// display denoise -> gamma/brightness. PIC1 settings arrive atomically from
// the MCU mailbox and are applied at the next raw frame boundary. Chroma
// coring remains in its existing fixed-zero configuration.
wire [7:0] S_isp_stat_sat_pre;
wire [7:0] S_isp_stat_sat_post;
wire [7:0] S_isp_stat_mean_r;
wire [7:0] S_isp_stat_mean_g;
wire [7:0] S_isp_stat_mean_b;
wire [7:0] S_isp_stat_min_r;
wire       S_isp_stat_frm_tgl;

isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_awb_bypass    (S_picture_isp[13:12] == 2'd3),
.I_blc_off       ({2'd0,S_picture_isp[5:0]}),
.I_gamma_en      (S_picture_isp[6]),
.I_bright        (S_picture_isp[8:7]),
.I_core_sel      (3'd0),
.I_awb_gate_en   (S_picture_isp[13:12] == 2'd2),
.I_awb_gate_th   (8'd32),
.I_awb_smooth_en (S_picture_isp[13:12] != 2'd0),
.I_sat_off       (S_picture_isp[11:9] == 3'd0),
.I_sat_sel       (S_picture_isp[10:9] - 2'd1),
.I_denoise       (S_picture_isp[15:14]),
.O_stat_sat_pre  (S_isp_stat_sat_pre),
.O_stat_sat_post (S_isp_stat_sat_post),
.O_stat_mean_r   (S_isp_stat_mean_r),
.O_stat_mean_g   (S_isp_stat_mean_g),
.O_stat_mean_b   (S_isp_stat_mean_b),
.O_stat_min_r    (S_isp_stat_min_r),
.O_stat_frm_tgl  (S_isp_stat_frm_tgl),
.I_tready        ()
  );

    // ISP statistics are produced in the MIPI clock domain.  Transfer the
    // stable per-frame values with the same toggle protocol used by _9 rather
    // than feeding an asynchronous multi-bit bus directly into the OSD.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_isp_stat_t1      <= 1'b0;
            S_isp_stat_t2      <= 1'b0;
            S_isp_stat_t3      <= 1'b0;
            S_isp_sat_pre_hdmi <= 8'd0;
            S_isp_sat_post_hdmi<= 8'd0;
            S_isp_mean_r_hdmi  <= 8'd0;
            S_isp_mean_g_hdmi  <= 8'd0;
            S_isp_mean_b_hdmi  <= 8'd0;
            S_isp_min_r_hdmi   <= 8'd0;
        end else begin
            S_isp_stat_t1 <= S_isp_stat_frm_tgl;
            S_isp_stat_t2 <= S_isp_stat_t1;
            S_isp_stat_t3 <= S_isp_stat_t2;
            if(S_isp_stat_t2 ^ S_isp_stat_t3) begin
                S_isp_sat_pre_hdmi  <= S_isp_stat_sat_pre;
                S_isp_sat_post_hdmi <= S_isp_stat_sat_post;
                S_isp_mean_r_hdmi   <= S_isp_stat_mean_r;
                S_isp_mean_g_hdmi   <= S_isp_stat_mean_g;
                S_isp_mean_b_hdmi   <= S_isp_stat_mean_b;
                S_isp_min_r_hdmi    <= S_isp_stat_min_r;
            end
        end
    end


    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy | rec_block ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en | rec_wr;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en | rec_rd;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : rec_addr;

    assign S_ddr_user_wr_data  = rec_wr ? rec_data : S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy | rec_block ),
        .I_video_out_rp      ( S_video_out_rp       ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( video_read_valid ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    uivtc #(
        .H_ActiveSize ( `HDMI_H_ACTIVE ),
        .H_FrameSize  ( `HDMI_H_TOTAL ),
        .H_SyncStart  ( `HDMI_H_SYNC_START ),
        .H_SyncEnd    ( `HDMI_H_SYNC_END ),
        .V_ActiveSize ( `HDMI_V_ACTIVE ),
        .V_FrameSize  ( `HDMI_V_TOTAL ),
        .V_SyncStart  ( `HDMI_V_SYNC_START ),
        .V_SyncEnd    ( `HDMI_V_SYNC_END )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    // Match video_out's one-cycle read latency before entering the _9
    // 3x3 line-buffer branch.  The branch is enabled only for recognition
    // modes; normal display modes receive a delay-only output from it.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n)
            S_video_de_1d <= 1'b0;
        else
            S_video_de_1d <= S_hdmi_window_rd_en;
    end

    rgb24_denoise u_rgb24_denoise_9 (
        .I_clk         (S_hdmi_pixel_clk),
        .I_rst_n       (S_hdmi_rst_n),
        .I_sel         (S_dbg_recog_mode ? 4'd9 : 4'd0),
        .I_tone        (2'd0),
        .I_vsync       (S_hdmi_vsync),
        .I_de          (S_video_de_1d),
        .I_data        (S_video_rd_data),
        .O_de          (S_video_dn_de),
        .O_data        (S_video_dn_data),
        .O_noise       (S_dn_noise),
        .O_mean_y      (S_dn_mean_y),
        .O_smooth_data (S_shape_input_data)
    );

    // Image mode/effect/target/logo are supplied by the MCU APB menu.  The
    // former FPGA-side dbg_ctrl and its second key debouncer are intentionally
    // removed so all four physical buttons have one owner.

    // The current ISP/DDR path remains the source of the display pixels. The
    // recognition branches are parallel consumers and do not alter USB, VCM,
    // MCU, or manual-servo ownership of the video path.
    shape_recognizer_simple #(
        .IMG_WIDTH    (`DISPLAY_WIDTH),
        .IMG_HEIGHT   (`DISPLAY_HEIGHT),
        .SAMPLE_SHIFT (4),
        .Y_THRESHOLD  (8'd96)
    ) u_shape_recognizer_99 (
        .I_clk      ( S_hdmi_pixel_clk ),
        .I_rst_n    ( S_hdmi_rst_n ),
        .I_vsync    ( S_hdmi_vsync ),
        .I_hsync    ( S_hdmi_hsync ),
        .I_user     ( S_hdmi_user ),
        .I_de       ( S_video_dn_de ),
        .I_data     ( S_shape_input_data ),
        .I_enable   ( S_dbg_recog_mode && (S_dbg_step == 3'd3) ),
        .O_valid    ( S_shape_valid ),
        .O_type     ( S_shape_type ),
        .O_x0       ( S_shape_x0 ), .O_y0 ( S_shape_y0 ),
        .O_x1       ( S_shape_x1 ), .O_y1 ( S_shape_y1 )
    );

    motion_detect #(
        .IMG_WIDTH      (`DISPLAY_WIDTH),
        .IMG_HEIGHT     (`DISPLAY_HEIGHT),
        .BLOCK_SHIFT    (5),
        .DIFF_THRESHOLD (8'd20),
        .MIN_BLOCKS     (16'd4)
    ) u_motion_detect_99 (
        .I_clk      ( S_hdmi_pixel_clk ),
        .I_rst_n    ( S_hdmi_rst_n ),
        .I_user     ( S_hdmi_user ),
        .I_de       ( S_video_dn_de ),
        .I_data     ( S_video_dn_data ),
        .I_enable   ( S_dbg_recog_mode && (S_dbg_step == 3'd4) ),
        .I_target_mode ( S_motion_target ),
        .O_valid    ( S_motion_valid ), .O_count ( S_motion_count ),
        .O_tvalid   ( S_motion_tvalid ),
        .O_x0_0 (S_motion_x0_0), .O_y0_0 (S_motion_y0_0),
        .O_x1_0 (S_motion_x1_0), .O_y1_0 (S_motion_y1_0),
        .O_x0_1 (S_motion_x0_1), .O_y0_1 (S_motion_y0_1),
        .O_x1_1 (S_motion_x1_1), .O_y1_1 (S_motion_y1_1),
        .O_x0_2 (S_motion_x0_2), .O_y0_2 (S_motion_y0_2),
        .O_x1_2 (S_motion_x1_2), .O_y1_2 (S_motion_y1_2)
    );

    color_detect #(
        .IMG_WIDTH    (`DISPLAY_WIDTH),
        .IMG_HEIGHT   (`DISPLAY_HEIGHT),
        .SAMPLE_SHIFT (4),
        .MIN_SAMPLES  (16'd16)
    ) u_color_detect_99 (
        .I_clk      ( S_hdmi_pixel_clk ),
        .I_rst_n    ( S_hdmi_rst_n ),
        .I_user     ( S_hdmi_user ),
        .I_de       ( S_video_dn_de ),
        .I_data     ( S_video_dn_data ),
        .I_enable   ( S_dbg_recog_mode && (S_dbg_step == 3'd4) ),
        .O_valid    ( S_color_valid ), .O_color ( S_color_code ),
        .O_count    ( S_color_count ),
        .O_x0       ( S_color_x0 ), .O_y0 (S_color_y0),
        .O_x1       ( S_color_x1 ), .O_y1 (S_color_y1)
    );

    red_target_tracker #(
        .IMG_WIDTH    (`DISPLAY_WIDTH),
        .IMG_HEIGHT   (`DISPLAY_HEIGHT),
        .SAMPLE_SHIFT (4),
        .REPORT_AREA_PERCENT (0)
    ) u_red_target_tracker_99 (
        .I_clk       ( S_hdmi_pixel_clk ),
        .I_rst_n     ( S_hdmi_rst_n ),
        .I_enable    ( S_dbg_recog_mode && (S_dbg_step == 3'd5) ),
        .I_reacquire ( S_track_reacquire ),
        .I_user      ( S_hdmi_user ),
        .I_de        ( S_video_dn_de ),
        .I_data      ( S_shape_input_data ),
        .O_new_result (S_track_new), .O_valid (S_track_valid),
        .O_state     (S_track_state),
        .O_x0 (S_track_x0), .O_y0 (S_track_y0),
        .O_x1 (S_track_x1), .O_y1 (S_track_y1),
        .O_cx (S_track_cx), .O_cy (S_track_cy),
        .O_error_x (S_track_ex), .O_error_y (S_track_ey),
        .O_dir_x (S_track_dx), .O_dir_y (S_track_dy),
        .O_level_x (S_track_lx), .O_level_y (S_track_ly),
        .O_area_percent (S_track_area)
    );

    red_track_mailbox u_red_track_mailbox (
        .pixel_clk(S_hdmi_pixel_clk), .apb_clk(S_mcu_apb_clk),
        .rst_n(S_hdmi_rst_n && S_rst_n),
        .enable(S_dbg_step == 3'd5), .reacquire(S_track_reacquire),
        .new_result(S_track_new), .valid(S_track_valid), .state(S_track_state),
        .dir_x(S_track_dx), .dir_y(S_track_dy),
        .level_x(S_track_lx), .level_y(S_track_ly),
        .error_x(S_track_ex), .error_y(S_track_ey),
        .status(S_track_status_apb), .errors(S_track_errors_apb)
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( `DISPLAY_WIDTH ),
        .IMG_HEIGHT ( `DISPLAY_HEIGHT ),
        // 正常摄像头显示模式；改为 1 可输出全屏彩条进行 HDMI 链路诊断。
        .DEBUG_MODE ( 0    )
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .I_dbg_mode      ( S_dbg_disp_mode ),
        .I_dbg_step      ( S_dbg_step ),
        .I_dbg_effect    ( S_dbg_effect_sel ),
        .I_dbg_awb_off   ( S_dbg_awb_bypass ),
        .I_recog_mode    ( S_dbg_recog_mode ),
        .I_logo_enable   ( S_logo_enable ),
        .I_motion_target ( S_motion_target ),
        .I_dbg_sat_pre   ( S_isp_sat_pre_hdmi ),
        .I_dbg_sat_post  ( S_isp_sat_post_hdmi ),
        .I_dbg_mean_r    ( S_isp_mean_r_hdmi ),
        .I_dbg_mean_g    ( S_isp_mean_g_hdmi ),
        .I_dbg_mean_b    ( S_isp_mean_b_hdmi ),
        .I_dbg_min_r     ( S_isp_min_r_hdmi ),
        .I_dbg_noise     ( S_dn_noise ),
        .I_dbg_mean_y    ( S_dn_mean_y ),
        .I_shape_valid   ( S_shape_valid ), .I_shape_type (S_shape_type),
        .I_shape_x0      ( S_shape_x0 ), .I_shape_y0 (S_shape_y0),
        .I_shape_x1      ( S_shape_x1 ), .I_shape_y1 (S_shape_y1),
        .I_motion_valid  ( S_motion_valid ), .I_motion_count (S_motion_count),
        .I_motion_tvalid ( S_motion_tvalid ),
        .I_motion_x0_0 (S_motion_x0_0), .I_motion_y0_0 (S_motion_y0_0),
        .I_motion_x1_0 (S_motion_x1_0), .I_motion_y1_0 (S_motion_y1_0),
        .I_motion_x0_1 (S_motion_x0_1), .I_motion_y0_1 (S_motion_y0_1),
        .I_motion_x1_1 (S_motion_x1_1), .I_motion_y1_1 (S_motion_y1_1),
        .I_motion_x0_2 (S_motion_x0_2), .I_motion_y0_2 (S_motion_y0_2),
        .I_motion_x1_2 (S_motion_x1_2), .I_motion_y1_2 (S_motion_y1_2),
        .I_color_valid  ( S_color_valid ), .I_color_code (S_color_code),
        .I_color_count  ( S_color_count ),
        .I_color_x0 (S_color_x0), .I_color_y0 (S_color_y0),
        .I_color_x1 (S_color_x1), .I_color_y1 (S_color_y1),
        .I_track_new (S_track_new), .I_track_valid (S_track_valid),
        .I_track_state (S_track_state),
        .I_track_dx (S_track_dx), .I_track_dy (S_track_dy),
        .I_track_lx (S_track_lx), .I_track_ly (S_track_ly),
        .I_track_x0 (S_track_x0), .I_track_y0 (S_track_y0),
        .I_track_x1 (S_track_x1), .I_track_y1 (S_track_y1),
        .I_track_cx (S_track_cx), .I_track_cy (S_track_cy),
        .I_track_ex (S_track_ex), .I_track_ey (S_track_ey),
        .I_track_area (S_track_area),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    ),
        .O_base_data     ( S_hdmi_base_data   ),
        .O_overlay_valid ( S_hdmi_overlay_valid )
    );

    // _9 style effect chain: process camera pixels only, then restore the
    // mixer OSD colors through video_overlay_final.  This keeps the current
    // recognition/menu/RTC OSD visible while replacing the old adjacent-pixel
    // edge effect with the spatial Sobel implementation.
    image_filter u_image_filter_9 (
        .I_clk    (S_hdmi_pixel_clk),
        .I_rst_n  (S_hdmi_rst_n),
        .I_vsync  (S_hdmi_out_vsync),
        .I_hsync  (S_hdmi_out_hsync),
        .I_de     (S_hdmi_out_de),
        .I_data   (S_hdmi_base_data),
        .I_mode   ((S_dbg_effect_sel <= 3'd4) ? S_dbg_effect_sel : 3'd0),
        .O_vsync  (S_effect_vsync),
        .O_hsync  (S_effect_hsync),
        .O_de     (S_effect_de),
        .O_data   (S_effect_data)
    );

    sobel_edge #(
        .IMG_WIDTH  (`DISPLAY_WIDTH),
        .IMG_HEIGHT (`DISPLAY_HEIGHT),
        .H_TOTAL    (`HDMI_H_TOTAL),
        .THRESHOLD  (11'd60),
        .EDGE_WHITE (1)
    ) u_sobel_edge_9 (
        .I_clk       (S_hdmi_pixel_clk),
        .I_rst_n     (S_hdmi_rst_n),
        .I_sobel_en  (S_dbg_effect_sel == 3'd5),
        .I_vsync     (S_effect_vsync),
        .I_hsync     (S_effect_hsync),
        .I_de        (S_effect_de),
        .I_data      (S_effect_data),
        .O_vsync     (S_edge_vsync),
        .O_hsync     (S_edge_hsync),
        .O_de        (S_edge_de),
        .O_data      (S_edge_data),
        .O_edge      (S_edge_flag),
        .O_gray      (S_edge_gray)
    );

    video_overlay_final #(.EFFECT_LATENCY(5)) u_video_overlay_final_9 (
        .I_clk            (S_hdmi_pixel_clk),
        .I_rst_n          (S_hdmi_rst_n),
        .I_overlay_valid  (S_hdmi_overlay_valid),
        .I_overlay_color  (S_hdmi_out_data),
        .I_vsync          (S_edge_vsync),
        .I_hsync          (S_edge_hsync),
        .I_de             (S_edge_de),
        .I_data           (S_edge_data),
        .O_vsync          (S_final_vsync),
        .O_hsync          (S_final_hsync),
        .O_de             (S_final_de),
        .O_data           (S_final_data)
    );

    // Measure the selected region before effects, recognition and OSD overlays.
    focus_metric u_focus_metric (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_vsync        ( S_hdmi_out_vsync ),
        .I_de           ( S_hdmi_out_de ),
        .I_data         ( S_hdmi_base_data ),
        .I_roi          ( S_focus_roi_p2 ),
        .O_metric       ( S_focus_metric_pix ),
        .O_frame_toggle ( S_focus_frame_toggle )
    );

    ui_osd #(
        .H_ACTIVE(`HDMI_H_ACTIVE),
        .V_ACTIVE(`HDMI_V_ACTIVE),
        .PIXEL_CLOCK_HZ(`HDMI_PIXEL_CLOCK_HZ)
    ) u_ui_osd (
        .I_record_status (rec_ui_status),
        .I_mipi_clk(S_csi_rx_clk), .I_mipi_frame_start(S_csi_frame_start),
        .I_camera_display(S_camera_display_pixel),
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_vsync        ( S_final_vsync ),
        .I_hsync        ( S_final_hsync ),
        .I_de           ( S_final_de ),
        .I_data         ( S_final_data ),
        .I_menu_enable  ( S_ui_enable_p2 ),
        .I_edit_enable  ( S_ui_edit_p2 ),
        .I_info_enable  ( S_ui_info_p2 ),
        .I_menu_index   ( S_ui_index_p2 ),
        .I_picture_page ( S_picture_page_p2 ),
        .I_mode_page    ( S_mode_page_p2 ),
        .I_focus_roi    ( S_focus_roi_p2 ),
        .I_image_step   ( S_image_step_p2 ),
        .I_picture_ctrl ( S_picture_pixel ),
        .I_exposure     ( S_ui_ae_p2 ),
        .I_gain         ( S_ui_ag_p2 ),
        .I_servo_pan_us ( S_ui_servo_pan_p2 ),
        .I_servo_tilt_us( S_ui_servo_tilt_p2 ),
        .I_rtc_hours    ( S_rtc_hours_p2 ),
        .I_rtc_minutes  ( S_rtc_minutes_p2 ),
        .I_rtc_seconds  ( S_rtc_seconds_p2 ),
        .I_rtc_valid    ( S_rtc_valid_p2 ),
        .I_rtc_error    ( S_rtc_error_p2 ),
        .I_rtc_osf      ( S_rtc_osf_p2 ),
        .O_vsync        ( S_osd_vsync ),
        .O_hsync        ( S_osd_hsync ),
        .O_de           ( S_osd_de ),
        .O_data         ( S_osd_data )
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_osd_vsync       ),
        .I_video_in_de      ( S_osd_de          ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_osd_data        ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


    
endmodule
