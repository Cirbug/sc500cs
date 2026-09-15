
// 视频分辨率和时序集中参数文件。
// 当前模式：SC500 1920x1080@30，HDMI 1920x1080@30。
`ifndef VIDEO_PARAMS_VH
`define VIDEO_PARAMS_VH

// 摄像头实际输出图像宽度和高度，必须与 uics500reg.v 一致。
`define SENSOR_WIDTH       1920
`define SENSOR_HEIGHT      1080
// 当前 ISP/RAW 数据流使用的图像宽度和高度。
`define PIPE_WIDTH         `SENSOR_WIDTH
`define PIPE_HEIGHT        `SENSOR_HEIGHT

// HDMI 有效显示区域宽度和高度。
`define DISPLAY_WIDTH      1920
`define DISPLAY_HEIGHT     1080

// 1920x1080@30 HDMI 时序参数。
// 水平方向：有效区、总周期、同步起始位置、同步结束位置。
`define HDMI_H_ACTIVE      1920
`define HDMI_H_TOTAL       2200
`define HDMI_H_SYNC_START  2008
`define HDMI_H_SYNC_END    2052
// 垂直方向：有效区、总周期、同步起始位置、同步结束位置。
`define HDMI_V_ACTIVE      1080
`define HDMI_V_TOTAL       1125
`define HDMI_V_SYNC_START  1084
`define HDMI_V_SYNC_END    1089
// HDMI 水平前沿、同步脉冲和后沿长度。
`define HDMI_H_FP             88
`define HDMI_H_SYNC           44
`define HDMI_H_BP            148
// HDMI 垂直前沿、同步脉冲和后沿长度。
`define HDMI_V_FP              4
`define HDMI_V_SYNC            5
`define HDMI_V_BP             36

// DDR 环形帧缓存的帧地址间隔，单位为字节。
// 该值不是图像宽度；修改输出格式时需要确认它大于单帧数据大小。
`define DDR_FRAME_STRIDE_BYTES 7000000
`endif
