
// 视频分辨率和时序集中参数文件。
// 当前模式：SC500 2592x1944 全分辨率采集，HDMI 1920x1080@30 显示。
`ifndef VIDEO_PARAMS_VH
`define VIDEO_PARAMS_VH

// 摄像头实际输出图像宽度和高度，必须与 uics500reg.v 一致。
`define SENSOR_WIDTH       2592
`define SENSOR_HEIGHT      1944

// 去掉去马赛克算法左右边界各 8 个不完整邻域像素，消除画面边缘彩色竖线。
`define SENSOR_EDGE_CROP_X 8

// RGB 缩放中间尺寸：Full 图像等比例缩小为 1920x1440。
`define SCALE_WIDTH        1920
`define SCALE_HEIGHT       1440

// 缩放并完成上下裁剪后，写入 DDR 的图像尺寸。
`define PIPE_WIDTH         1920
`define PIPE_HEIGHT        1080

// HDMI 有效显示区域宽度和高度。
`define DISPLAY_WIDTH      1920
`define DISPLAY_HEIGHT     1080

// DDR 图像与 HDMI 尺寸一致，显示读取不再进行二次裁剪。
`define DISPLAY_CROP_X     ((`PIPE_WIDTH  - `DISPLAY_WIDTH)  / 2)
`define DISPLAY_CROP_Y     ((`PIPE_HEIGHT - `DISPLAY_HEIGHT) / 2)

// 1920x1440 缩放结果上下各裁剪 180 行，得到 1920x1080。
`define SCALE_CROP_Y       ((`SCALE_HEIGHT - `PIPE_HEIGHT) / 2)

// 1920x1080@30 HDMI 标准时序。
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

// DDR 用户地址每增加 8，对应一个 128 bit（16 字节）数据字，因此地址单位为 2 字节。
// 1920x1080 RGB888 单帧需要 3110400 个地址单位；这里留出对齐裕量。
`define DDR_FRAME_STRIDE_ADDR 3200000
`endif
