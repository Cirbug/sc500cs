

`include "video_params.vh"

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,

    input wire        I_mcu_uart_rx,
    output wire       O_mcu_uart_tx,
    output wire       O_usb_sclk,
    input  wire       I_usb_miso,
    output wire       O_usb_mosi,
    output wire       O_usb_ss_n,
    input  wire       I_usb_int_n,
    output wire       O_usb_res_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
    // Lens actuator I2C: SCL=K1, SDA=K2.
    inout  wire       O_lens_scl,
    inout  wire       IO_lens_sda,
      
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
    wire [31:0] S_focus_metric_pix;
    wire [31:0] S_focus_metric_apb;
    wire        S_focus_frame_toggle;
    reg [31:0]  S_focus_metric_sync1;
    reg [31:0]  S_focus_metric_sync2;
    reg         S_cam_cfg_done_apb1;
    reg         S_cam_cfg_done_apb2;
    // MAX3421E uses hardware QSPI1 in SINGLE mode. GPIO pins are no longer
    // external SPI drivers. APB USB_CTRL releases /RES and enables SPI routing.
    assign S_mcu_gpio0_in = 1'b0;
    assign S_mcu_gpio1_in = 1'b0;
    assign S_mcu_gpio2_in = I_usb_miso;
    assign S_mcu_gpio3_in = 1'b0;
    assign S_mcu_gpio4_in = 1'b0;
    assign S_mcu_gpio5_in = I_usb_int_n;
    assign S_mcu_gpio6_in = 1'b0;
    assign S_mcu_gpio7_in = 1'b0;
    // 1: continuous R7 clock test; 0: restore normal QSPI1 routing.
    // 100 MHz / (2 * 500) = 100 kHz, independent of MCU/APB enable.
    // CS stays inactive during this test: these clocks are not SPI commands.
    localparam USB_SCLK_CONTINUOUS_TEST = 1'b1;
    generate
        if (USB_SCLK_CONTINUOUS_TEST) begin : g_usb_sclk_test
            reg [8:0] count;
            reg sclk;
            always @(posedge S_100m_clk or negedge S_rst_n) begin
                if (!S_rst_n) begin
                    count <= 9'd0;
                    sclk <= 1'b0;
                end else if (count == 9'd499) begin
                    count <= 9'd0;
                    sclk <= ~sclk;
                end else begin
                    count <= count + 9'd1;
                end
            end
            assign O_usb_sclk = sclk;
            assign O_usb_mosi = 1'b0;
            assign O_usb_ss_n = 1'b1;
        end else begin : g_usb_qspi_normal
            assign O_usb_sclk = (S_rst_n && S_apb_usb_spi_enable) ? S_mcu_qspi1_clk : 1'b0;
            assign O_usb_mosi = (S_rst_n && S_apb_usb_spi_enable) ? S_mcu_qspi1_d0_out : 1'b0;
            assign O_usb_ss_n = (S_rst_n && S_apb_usb_spi_enable) ? S_mcu_qspi1_ss : 1'b1;
        end
    endgenerate
    assign O_usb_res_n = S_rst_n && S_apb_usb_res_n;
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
    wire [1:0]  S_ui_index_apb;
    wire [15:0] S_ui_ae_apb;
    wire [15:0] S_ui_ag_apb;
    reg [15:0]  S_ae_sync1;
    reg [15:0]  S_ae_sync2;
    reg [15:0]  S_ag_sync1;
    reg [15:0]  S_ag_sync2;
    reg         S_ui_enable_p1, S_ui_enable_p2;
    reg         S_ui_edit_p1, S_ui_edit_p2;
    reg         S_ui_info_p1, S_ui_info_p2;
    reg [1:0]   S_ui_index_p1, S_ui_index_p2;
    reg [15:0]  S_ui_ae_p1, S_ui_ae_p2;
    reg [15:0]  S_ui_ag_p1, S_ui_ag_p2;
    wire        S_osd_vsync;
    wire        S_osd_hsync;
    wire        S_osd_de;
    wire [23:0] S_osd_data;

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

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_ae_sync1 <= 16'd2246;
            S_ae_sync2 <= 16'd2246;
            S_ag_sync1 <= 16'd80;
            S_ag_sync2 <= 16'd80;
        end else begin
            S_ae_sync1 <= S_ui_ae_apb;
            S_ae_sync2 <= S_ae_sync1;
            S_ag_sync1 <= S_ui_ag_apb;
            S_ag_sync2 <= S_ag_sync1;
        end
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_ui_enable_p1 <= 1'b0;
            S_ui_enable_p2 <= 1'b0;
            S_ui_edit_p1   <= 1'b0;
            S_ui_edit_p2   <= 1'b0;
            S_ui_info_p1   <= 1'b0;
            S_ui_info_p2   <= 1'b0;
            S_ui_index_p1  <= 2'd0;
            S_ui_index_p2  <= 2'd0;
            S_ui_ae_p1     <= 16'd2246;
            S_ui_ae_p2     <= 16'd2246;
            S_ui_ag_p1     <= 16'd80;
            S_ui_ag_p2     <= 16'd80;
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
        .uart1_tx    ( O_mcu_uart_tx      ),
        .uart1_rx    ( I_mcu_uart_rx      ),
        .i2c_sda_in  ( 1'b0               ),
        .i2c_sda_out ( S_mcu_i2c_sda_out  ),
        .i2c_sda_sel ( S_mcu_i2c_sda_sel  ),
        .i2c_scl_in  ( 1'b0               ),
        .i2c_scl_out ( S_mcu_i2c_scl_out  ),
        .i2c_scl_sel ( S_mcu_i2c_scl_sel  ),
        // QSPI1 single-SPI mode: D0=MOSI, D1=MISO. QSPI0 boot flash is separate.
        .qspi1_clk   ( S_mcu_qspi1_clk    ),
        .qspi1_ss    ( S_mcu_qspi1_ss     ),
        // Diagnostic mapping: feed MISO to both possible QSPI receive lanes.
        // Software must enable PINCTL.FDUPSPI before reading MAX3421E.
        // This does not implement bidirectional transfers on the MOSI pin.
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

    mcu_ui_apb_regs u_mcu_ui_apb_regs (
        .I_clk         ( S_mcu_apb_clk ),
        .I_rst         ( ~S_rst_n ),
        .I_button      ( I_button ),
        .I_usb_int_n   ( I_usb_int_n ),
        .O_usb_res_n   ( S_apb_usb_res_n ),
        .O_usb_spi_enable ( S_apb_usb_spi_enable ),
        .I_paddr       ( S_mcu_paddr ),
        .I_psel        ( S_mcu_psel ),
        .I_penable     ( S_mcu_penable ),
        .I_pwrite      ( S_mcu_pwrite ),
        .I_pwdata      ( S_mcu_pwdata ),
        .I_pstrobe     ( S_mcu_pstrobe ),
        .O_prdata      ( S_mcu_prdata ),
        .O_pready      ( S_mcu_pready ),
        .O_pslverr     ( S_mcu_pslverr ),
        .O_menu_enable ( S_ui_enable_apb ),
        .O_edit_enable ( S_ui_edit_apb ),
        .O_info_enable ( S_ui_info_apb ),
        .O_menu_index  ( S_ui_index_apb ),
        .O_exposure    ( S_ui_ae_apb ),
        .O_gain        ( S_ui_ag_apb ),
        .I_lens_busy   ( S_lens_busy ),
        .I_lens_init_done( S_lens_init_done ),
        .I_lens_error  ( S_lens_error ),
        .I_lens_diag   ( S_lens_diag ),
        .I_lens_tx_count( S_lens_tx_count ),
        .I_lens_adc_raw( S_lens_adc_raw ),
        .I_lens_adc_count( S_lens_adc_count ),
        .I_lens_bus_state( S_lens_bus_state ),
        .I_focus_metric( S_focus_metric_apb ),
        .O_lens_cmd    ( S_lens_cmd ),
        .O_lens_retry  ( S_lens_retry ),
        .O_lens_read_adc( S_lens_read_adc ),
        .O_lens_position( S_lens_position )
    );


	

  
  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn(4'b1111),
      .I_mcu_control_en(1'b1),
      .I_mcu_ae(S_ae_sync2),
      .I_mcu_ag(S_ag_sync2),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );
  
    uicfgcs500 #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
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


//ISP算法顶层模块
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
.I_tready        ()
  );


    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
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
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );

    // Use the camera image before OSD overlay for contrast autofocus.
    focus_metric u_focus_metric (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_vsync        ( S_hdmi_out_vsync ),
        .I_de           ( S_hdmi_out_de ),
        .I_data         ( S_hdmi_out_data ),
        .O_metric       ( S_focus_metric_pix ),
        .O_frame_toggle ( S_focus_frame_toggle )
    );

    ui_osd #(
        .H_ACTIVE(`HDMI_H_ACTIVE),
        .V_ACTIVE(`HDMI_V_ACTIVE)
    ) u_ui_osd (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n ),
        .I_vsync        ( S_hdmi_out_vsync ),
        .I_hsync        ( S_hdmi_out_hsync ),
        .I_de           ( S_hdmi_out_de ),
        .I_data         ( S_hdmi_out_data ),
        .I_menu_enable  ( S_ui_enable_p2 ),
        .I_edit_enable  ( S_ui_edit_p2 ),
        .I_info_enable  ( S_ui_info_p2 ),
        .I_menu_index   ( S_ui_index_p2 ),
        .I_exposure     ( S_ui_ae_p2 ),
        .I_gain         ( S_ui_ag_p2 ),
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
