`include "picture_control.v"
// RISC-V APB slave for the camera menu and physical keys.
// APB addresses are byte offsets; the CPU-side high base address is kept in
// the application as UI_APB_BASE because it is device/project dependent.
module mcu_ui_apb_regs #(
    parameter [15:0] AE_MIN  = 16'd3,
    parameter [15:0] AE_MAX  = 16'd3990,
    // VTS=2000, so 3990 is the highest safe exposure (2*VTS-10).
    parameter [15:0] AE_INIT = 16'd3990,
    parameter [15:0] AG_MIN  = 16'd16,
    parameter [15:0] AG_MAX  = 16'd143,
    // Match the _9 exposure-priority profile: user value 80 (4.13x).
    parameter [15:0] AG_INIT = 16'd80,
    // Keep the APB side inside the normal hobby-servo range.  The PWM block
    // applies the same limits, so an early/invalid MCU write cannot create an
    // extreme pulse.
    parameter [15:0] SERVO_MIN = 16'd500,
    parameter [15:0] SERVO_MAX = 16'd2500,
    parameter [15:0] SERVO_INIT = 16'd1500
)(
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [3:0]  I_button,
    input  wire        I_usb_int_n,
    output reg         O_usb_res_n,
    output reg         O_usb_spi_enable,
    input  wire [19:0] I_paddr,
    input  wire        I_psel,
    input  wire        I_penable,
    input  wire        I_pwrite,
    input  wire [31:0] I_pwdata,
    input  wire [3:0]  I_pstrobe,
    output reg  [31:0] O_prdata,
    output wire        O_pready,
    output wire        O_pslverr,
    output reg         O_menu_enable,
    output reg         O_edit_enable,
    output reg         O_info_enable,
    output reg         O_picture_page,
    output reg         O_mode_page,
    output reg  [15:0] O_picture_ctrl,
    output reg  [3:0]  O_gamma_level,
    // LSC 运行时强度（菜单"系统信息 -> 色度"）：0 = 旁路，16 = 表值原样，
    // 31 = 约 194%。5 位，每一步只有旧版的一半，便于半步微调。
    // 复位默认 16（等价于编译期表值）。MCU 开机写一次，之后由菜单维护。
    output reg  [7:0]  O_lsc_ctrl,
    // 跟踪目标颜色（APB 0xf4）：0=红 1=绿 2=蓝。三色的连通域同时都在跑、
    // 三个框都会画出来，这一位只决定"伺服跟哪一个"。
    /* 已停用：output reg [1:0] O_track_color,  见 design_top_wrapper.v 说明 */
    // 自动对焦的 ROI 尺寸（APB 0xfc）：{5'd0,h[10:0],5'd0,w[10:0]}，单位像素。
    // 0 = 没设置 -> focus_metric 用默认的 160x120（旧固件行为不变）。
    // 为什么要可写：写死的 160x120 遇到"比窗口大的目标"时，窗口整个落在目标
    // 内部（没有边缘可测），清晰度曲线变水平线，对焦就永远找不到峰值。
    output reg  [10:0] O_focus_roi_w,
    output reg  [10:0] O_focus_roi_h,
    output reg  [2:0]  O_menu_index,
    output reg  [15:0] O_exposure,
    output reg  [15:0] O_gain,
    output reg [15:0] O_vts,
    output reg [22:0] O_camera_display,
    // Image controls written by the MCU menu.  These replace the old
    // independent FPGA dbg_ctrl key path.
    output reg  [2:0]  O_image_step,
    output reg  [2:0]  O_image_effect,
    output reg  [1:0]  O_image_target,
    output reg         O_image_logo_enable,
    output reg         O_image_track_toggle,
    output reg  [7:0]  O_bin_threshold,      /* 二值化阈值 0..255，默认 128 */
    input  wire        I_lens_busy,
    input  wire        I_lens_init_done,
    input  wire        I_lens_error,
    input  wire [31:0] I_lens_diag,
    input  wire [31:0] I_lens_tx_count,
    input wire [31:0] I_lens_adc_raw, I_lens_adc_count, I_lens_bus_state,
    input  wire [31:0] I_focus_metric,
    output reg [31:0] O_focus_roi,
    input  wire [31:0] I_rtc_time0, I_rtc_time1, I_rtc_status,
    input  wire [31:0] I_rtc_set_status,
    output reg [31:0] O_rtc_set_time0, O_rtc_set_time1,
    output reg O_rtc_set,
    output reg [1:0] O_wifi_ctrl,
    input wire [1:0] I_wifi_pads,
    input wire [31:0] I_track_status, I_track_errors,
    input wire [63:0] I_video_rx_diag,I_video_capture_diag,
    input wire [31:0] I_video_display_diag,
    input wire [95:0] I_video_fault_details,
    input wire [23:0] I_ae_rgb,
    input wire [31:0] I_ae_meta,
    input wire [1:0] I_ae_sensor_ready,
    output reg         O_lens_cmd,
    output reg         O_lens_retry, O_lens_read_adc,
    output reg  [13:0] O_lens_position,
    output reg  [15:0] O_servo_pan_us,
    output reg  [15:0] O_servo_tilt_us
);

    // Full 1944-line mode: trial range 1980..2500; reset remains 2000.
    wire [15:0] write_vts=(I_pwdata[15:0]<1980)?16'd1980:(I_pwdata[15:0]>2500)?16'd2500:I_pwdata[15:0];
    wire [15:0] ae_max_dynamic=(O_vts<<1)-16'd10;
    wire [15:0] write_vts_limit=(write_vts<<1)-16'd10;
    localparam [31:0] ID_VALUE = 32'h55494D55; // "UIMU"
    wire apb_write = I_psel && I_penable && I_pwrite;
    wire apb_read  = I_psel && I_penable && !I_pwrite;
    assign O_pready = 1'b1;
    assign O_pslverr = 1'b0;

    // Servo registers (microseconds): 0x50 = V6/pan, 0x54 = V4/tilt.
    // Values are clamped to the expanded 500..2500 us touch-control range.

    // key_remove_shakes emits one clock pulse for each active-low press.
    wire [3:0] key_pulse;
    genvar k;
    generate
        for(k = 0; k < 4; k = k + 1) begin : g_key
            key_remove_shakes u_key (
                .I_clk          (I_clk),
                .I_rst_n        (~I_rst),
                .I_key_in       (I_button[k]),
                .O_key_trig_out (key_pulse[k])
            );
        end
    endgenerate

    (* async_reg="true" *) reg [1:0] ae_ready_meta,ae_ready_sync;
    always @(posedge I_clk or posedge I_rst)
        if(I_rst) begin ae_ready_meta<=0;ae_ready_sync<=0;end
        else begin ae_ready_meta<=I_ae_sensor_ready;ae_ready_sync<=ae_ready_meta;end
    reg [3:0] key_event;
    // MAX3421E INT is asynchronous to APB; poll the synchronized pin level.
    (* async_reg = "true" *) reg usb_int_meta;
    (* async_reg = "true" *) reg usb_int_sync;
    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            usb_int_meta <= 1'b1;
            usb_int_sync <= 1'b1;
        end else begin
            usb_int_meta <= I_usb_int_n;
            usb_int_sync <= usb_int_meta;
        end
    end

    always @(posedge I_clk or posedge I_rst) begin
        if(I_rst) begin
            O_usb_res_n <= 1'b0;
            O_usb_spi_enable <= 1'b0;
            key_event    <= 4'd0;
            O_menu_enable <= 1'b0;
            O_edit_enable <= 1'b0;
            O_info_enable <= 1'b0;
            O_picture_page <= 1'b0;
            O_mode_page <= 1'b0;
            O_focus_roi <= 32'h01e00370; // hidden, centered 160x120 ROI
            O_gamma_level  <= 4'd4;
            // 必须与固件的 PICTURE_DEFAULT 完全一致（FDwork/shared/menu_input.h）。
            // MCU 是跑在本 FPGA 内的软核，TD 重新配置 FPGA 时 MCU 一并复位，
            // 0x70 回到这里的复位值；若与固件默认不同，画面就会跳变
            // （旧值 0x1050 = 伽马开/黑电平16/亮度1.00，固件是 0x108C）。
            // 0x108C = 黑电平12, 伽马关, 亮度1.125x, 饱和度旁路, 白平衡平滑, 降噪0。
            O_picture_ctrl <= 16'h108C;
            O_lsc_ctrl    <= 8'd112;    // 8 位；112 = 表值原样(128) 的 7/8 = 旧 5 位口径的 14
            /* 已停用：O_track_color <= 2'd0;  （0xf4 链路）*/
            O_focus_roi_w <= 11'd0;     // 0 = focus_metric 用默认 160x120
            O_focus_roi_h <= 11'd0;
            O_menu_index  <= 3'd0;
            O_exposure    <= AE_INIT;
            O_gain        <= AG_INIT;
            O_vts<=2000; O_camera_display<={7'd127,16'h2000};
            O_image_step  <= 3'd2;
            O_image_effect <= 3'd0;
            O_image_target <= 2'd0;
            O_image_logo_enable <= 1'b1;
            O_image_track_toggle <= 1'b0;
            O_bin_threshold <= 8'd128;   /* 二值化阈值默认 128（与原来写死的值一致） */
            O_lens_cmd    <= 1'b0;
            O_lens_retry <= 0; O_lens_read_adc <= 0;
            O_lens_position <= 14'd8192;
            O_servo_pan_us  <= SERVO_INIT;
            O_servo_tilt_us <= SERVO_INIT;
            O_rtc_set_time0<=0; O_rtc_set_time1<=0; O_rtc_set<=0;
            O_wifi_ctrl<=0; // Both ESP reset and boot strap released.
        end else begin
            O_rtc_set<=0;
            O_lens_cmd <= 1'b0;
            O_lens_retry <= 0; O_lens_read_adc <= 0;
            // Preserve a press arriving in the same cycle that software clears
            // an older event.  New events have priority over write-one-to-clear.
            if(apb_write && (I_paddr[7:0] == 8'h04))
                key_event <= (key_event & ~I_pwdata[3:0]) | key_pulse;
            else
                key_event <= key_event | key_pulse;
            if(apb_write) begin
                case(I_paddr[7:0])
                    8'h04: begin end
                    8'h08: begin
                        O_menu_enable <= I_pwdata[0];
                        O_edit_enable <= I_pwdata[1];
                        O_info_enable <= I_pwdata[2];
                        O_picture_page <= I_pwdata[3];
                        O_mode_page <= I_pwdata[4];
                    end
                    8'h0c: O_menu_index <= I_pwdata[2:0];
                    8'h10: O_exposure <= (I_pwdata[15:0] < AE_MIN) ? AE_MIN :
                                           ((I_pwdata[15:0] > ae_max_dynamic) ? ae_max_dynamic : I_pwdata[15:0]);
                    8'h9c: if(&I_pstrobe[1:0]) begin
                        O_vts<=write_vts;
                        if(O_exposure>write_vts_limit) O_exposure<=write_vts_limit;
                    end
                    // MCU formats VTS BCD and exposure bar off the pixel path.
                    8'ha4: if(&I_pstrobe[2:0]) O_camera_display<=I_pwdata[22:0];
                    8'h14: O_gain <= (I_pwdata[15:0] < AG_MIN) ? AG_MIN :
                                       ((I_pwdata[15:0] > AG_MAX) ? AG_MAX : I_pwdata[15:0]);
                    // 0x20: bit0 releases reset; bit1 enables external SPI.
                    8'h20: if(I_pstrobe[0]) begin
                        O_usb_res_n <= I_pwdata[0];
                        O_usb_spi_enable <= I_pwdata[1];
                    end
                    8'h28: if(I_pstrobe[0])
                        O_lens_position <= (I_pwdata[13:0] > 14'd16383) ? 14'd16383 : I_pwdata[13:0];
                    // Command priority in controller: retry, position, ADC read.
                    8'h2c: if(I_pstrobe[0]) begin
                        O_lens_cmd <= I_pwdata[0];
                        O_lens_retry <= I_pwdata[1];
                        O_lens_read_adc <= I_pwdata[2];
                    end
                    8'h50: if(I_pstrobe[0])
                        O_servo_pan_us <= (I_pwdata[15:0] < SERVO_MIN) ? SERVO_MIN :
                                          ((I_pwdata[15:0] > SERVO_MAX) ? SERVO_MAX : I_pwdata[15:0]);
                    8'h54: if(I_pstrobe[0])
                        O_servo_tilt_us <= (I_pwdata[15:0] < SERVO_MIN) ? SERVO_MIN :
                                           ((I_pwdata[15:0] > SERVO_MAX) ? SERVO_MAX : I_pwdata[15:0]);
                    // IMAGE_CTRL (0x58): 档位 2..7 在 bits 2:0，effect 在 bits 5:3，
                    // motion target 在 bits 7:6，logo 在 bit 8，tracker reacquire 在 bit 9。
                    // 档位是 2..7（6 个模式）——原来是 2..5 的钳位，加了三色追踪后
                    // 写 6/7 会被夹回 5，导致"选追踪蓝/绿其实都在追踪红"。
                    // 3 位本身就封顶在 7，所以只需要下限钳位。
                    8'h58: if(I_pstrobe[0]) begin
                        /* 档位现在有 8 个：0=颜色识别 1=（保留，自动追踪暂未实现）
                         * 2=普通画面 3=图形识别 4=运动检测 5/6/7=追踪红/蓝/绿。
                         * 3 位正好装得下 8 个值，**位布局不用动** —— 原来把 <2 的写入夹到 2
                         * （那时 0/1 是非法值），现在 0 是正经档位，直接放行。 */
                        O_image_step <= I_pwdata[2:0];
                        O_image_effect <= (I_pwdata[5:3] > 3'd5) ? 3'd5 : I_pwdata[5:3];
                        O_image_target <= (I_pwdata[7:6] > 2'd2) ? 2'd2 : I_pwdata[7:6];
                        O_image_logo_enable <= I_pwdata[8];
                        if(I_pwdata[9])
                            O_image_track_toggle <= ~O_image_track_toggle;
                        /* 2026-10-27：二值化阈值放在本寄存器空闲的 bit[17:10]
                         * （0x00..0xfc 的 64 个槽位已全部分配完，没有新地址可用）。 */
                        O_bin_threshold <= I_pwdata[17:10];
                    end
                    // Atomic picture word: BLC[5:0], gamma[6], brightness[8:7],
                    // saturation[11:9] (0..4), AWB mode[13:12], denoise[15:14].
                    // Require both byte lanes; never publish half a setting.
                    8'h70: if(&I_pstrobe[1:0]) begin
                        O_picture_ctrl <= {I_pwdata[15:12],
                            (I_pwdata[11:9] > 3'd4 ? 3'd4 : I_pwdata[11:9]), I_pwdata[8:0]};
                    end
                    // GAM1: 0 = gamma off, 1..8 = gamma preset, default 4 (0.45).
                    8'h6c: if(I_pstrobe[0])
                        O_gamma_level <= (I_pwdata[3:0] > 4'd8) ? 4'd8 : I_pwdata[3:0];
                    8'h78: if(&I_pstrobe) O_rtc_set_time0<=I_pwdata;
                    8'h7c: if(&I_pstrobe) O_rtc_set_time1<=I_pwdata;
                    8'h80: if(&I_pstrobe && I_pwdata==32'h53455431 && !I_rtc_set_status[0]) O_rtc_set<=1;
                    8'h88: if(I_pstrobe[0]) O_wifi_ctrl<=I_pwdata[1:0];
                    // LSC 强度：5 位，超出 31 会被截断（31 已是约 194% 上限）
                    8'hec: if(I_pstrobe[0]) O_lsc_ctrl<=I_pwdata[7:0];
                    /* 已停用：8'hf4 跟踪目标颜色写入（0xf4 链路）*/
                    // 对焦 ROI 尺寸。宽高都要落在一个 32 位字里，所以要两条
                    // byte lane 同时有效，不能发布"半个设置"。
                    8'hfc: if(&I_pstrobe[1:0]) begin
                        O_focus_roi_w <= I_pwdata[10:0];
                        O_focus_roi_h <= I_pwdata[26:16];
                    end
                    8'h94: if(&I_pstrobe) O_focus_roi <= {I_pwdata[31],4'd0,
                        (I_pwdata[26:16]>11'd960 ? 11'd960 : I_pwdata[26:16]),5'd0,
                        (I_pwdata[10:0]>11'd1760 ? 11'd1760 : I_pwdata[10:0])};
                    default: begin end
                endcase
            end
        end
    end

    always @* begin
        O_prdata = 32'd0;
        if(apb_read) begin
            case(I_paddr[7:0])
                8'h00: O_prdata = ID_VALUE;
                8'h04: O_prdata = {28'd0, key_event};
                8'h08: O_prdata = {27'd0, O_mode_page, O_picture_page, O_info_enable, O_edit_enable, O_menu_enable};
                8'h0c: O_prdata = {29'd0, O_menu_index};
                8'h10: O_prdata = {16'd0, O_exposure};
                8'h9c: O_prdata = {16'd0,O_vts};
                8'ha0: O_prdata = 32'h56545331; // VTS1: dynamic frame length + eight-row menu
                8'ha4: O_prdata = {9'd0,O_camera_display};
                8'ha8: O_prdata = 32'h54524b31; // TRK1: coherent tracking result mailbox
                8'hac: O_prdata = I_track_status;
                8'hb0: O_prdata = I_track_errors;
                8'hb4: O_prdata = 32'h56494432; // VID2: validated triple-buffer video
                8'hb8: O_prdata = I_video_rx_diag[63:32]; // bad/good RAW frames
                8'hbc: O_prdata = I_video_rx_diag[31:0]; // flags[31:24], lines, words
                8'hc0: O_prdata = I_video_capture_diag[63:32]; // rejected/published frames
                8'hc4: O_prdata = I_video_capture_diag[31:0]; // capture flags/state
                8'hc8: O_prdata = I_video_display_diag; // underflow frames/flags
                8'hcc: O_prdata = I_video_fault_details[31:0]; // first bad packet header
                8'hd0: O_prdata = I_video_fault_details[63:32]; // reason/state/remaining
                8'hd4: O_prdata = I_video_fault_details[95:64]; // first bad line/words
                8'hdc: O_prdata = 32'h41454d31; // AEM1: normalized software AE metering
                8'he0: O_prdata = {8'd0,I_ae_rgb};
                8'he4: O_prdata = I_ae_meta; // frame sequence[23:16], sampled words[13:0]
                8'he8: O_prdata = {30'd0,ae_ready_sync};
                8'hd8: O_prdata = 32'h44455431; // DET1: sticky RX failure evidence
                8'h14: O_prdata = {16'd0, O_gain};
                8'h18: O_prdata = 32'h0001081e; // Full sensor input, HDMI 1080p30
                8'h1c: O_prdata = 32'h4d415831; // "MAX1": USB extension present
                8'h20: O_prdata = {30'd0, O_usb_spi_enable, O_usb_res_n};
                8'h24: O_prdata = {29'd0, O_usb_spi_enable, O_usb_res_n, usb_int_sync};
                8'h28: O_prdata = {18'd0, O_lens_position};
                8'h30: O_prdata = {29'd0, I_lens_error, I_lens_init_done, I_lens_busy};
                8'h34: O_prdata = I_focus_metric;
                8'h38: O_prdata = 32'h4c494333; // "LIC3": open drain, retry, ADC84/85
                8'h3c: O_prdata = I_lens_diag;
                8'h40: O_prdata = I_lens_tx_count;
                8'h44: O_prdata = I_lens_adc_raw;
                8'h48: O_prdata = I_lens_adc_count;
                8'h4c: O_prdata = I_lens_bus_state;
                8'h50: O_prdata = {16'd0, O_servo_pan_us};
                8'h54: O_prdata = {16'd0, O_servo_tilt_us};
                8'h58: O_prdata = {14'd0, O_bin_threshold, O_image_track_toggle,
                                   O_image_logo_enable, O_image_target,
                                   O_image_effect, O_image_step};
                8'h5c: O_prdata = 32'h20261011; // Firmware/bitstream pairing.
                8'h60: O_prdata = I_rtc_time0;
                8'h64: O_prdata = I_rtc_time1;
                8'h68: O_prdata = I_rtc_status;
                8'h70: O_prdata = {16'd0, O_picture_ctrl};
                8'h6c: O_prdata = 32'h47414D30 | {28'd0, O_gamma_level}; // GAM1
                8'h74: O_prdata = 32'h50494331; // PIC1 capability, independent of camera build ID.
                8'h78: O_prdata = O_rtc_set_time0;
                8'h7c: O_prdata = O_rtc_set_time1;
                8'h80: O_prdata = I_rtc_set_status;
                8'h84: O_prdata = 32'h52544332; // RTC2: verified serial setting.
                8'h88: O_prdata = {30'd0,O_wifi_ctrl};
                8'h8c: O_prdata = {30'd0,I_wifi_pads};
                8'h94: O_prdata = O_focus_roi;
                8'h98: O_prdata = 32'h41465231; // AFR1: touch focus ROI
                8'h90: O_prdata = 32'h57494631; // WIF1: UART0 and boot/reset pads.
                8'hec: O_prdata = {24'd0, O_lsc_ctrl}; // LSC 强度（读回，8 位）
                // COL1：本版色度是 8 位（128 = 表值原样、112 = 旧 14、0..255），同时表示
                // “三色识别 + 目标跟踪”能力 —— 三者在我们这条线上总是一起出现。
                // 采用 gege 的地址（0xf8 = COL1），保持与他固件的互操作性：他的固件探测
                // 0xf8==COL1 判三色能力，我们的固件用它判“色度是 8 位”。
                // 老 bit 只有 0xf0「LSC1」= 5 位（16 = 表值原样，0..31），固件按 v<<3 折算。
                8'hf8: O_prdata = 32'h434f4c31; // COL1 capability: 8-bit LSC + 3-colour/track
                8'hf0: O_prdata = 32'h4c534331; // LSC1 capability: runtime LSC strength
                /* 已停用：8'hf4 跟踪目标颜色读回（0xf4 链路）*/
                8'hfc: O_prdata = {5'd0, O_focus_roi_h, 5'd0, O_focus_roi_w}; // 对焦 ROI 尺寸
                default: O_prdata = 32'd0;
            endcase
        end
    end
endmodule

