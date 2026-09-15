# MIPI to HDMI 工程模块与 IP 分析

工程：`D:\2026fpga\lab_hd_1_mipi_hdmi`  
工程名：`camera_to_dsi_display`  
器件：`PH1P35MDG324`  
顶层：[`design_top_wrapper.v`](user_source/hdl_source/design_top_wrapper.v)

## 总体数据流

```text
I_sys_clk -> PLL
              ├─ 100 MHz -> MIPI RX / 控制
              ├─ 24 MHz  -> 摄像头 I2C 配置
              ├─ HDMI pixel clock
              └─ HDMI serial clock

MIPI D-PHY RX
 -> csi_unpacket_2lane
 -> raw10_unpacket_2lane
 -> uial2axis
 -> image_correction
 -> isp_top
      ├─ demosaic
      ├─ 128 bit -> 96 bit
      ├─ awb
      └─ 96 bit -> 128 bit
 -> video_in
 -> 128 bit 异步 FIFO
 -> mc_to_user_interface
 -> DDR2

DDR2 -> mc_to_user_interface -> video_out
     -> 128 bit 异步 FIFO -> HDMI pixel clock
     -> hdmi_mixer -> hdmi_tx -> TMDS/LVDS HDMI
```

## 顶层实例

| 实例 | 模块 | 作用 |
|---|---|---|
| `u_PLL` | `PLL` | 时钟生成 |
| `u_ae_set` | `ae_set` | 自动曝光参数 |
| `u_uicfgcs500` | `uicfgcs500` | CS500 摄像头 I2C 配置 |
| `u_mipi_dphy_rx_ph1p_mipiio_wrapper` | `mipi_dphy_rx_ph1p_mipiio_wrapper` | 2-lane MIPI 接收 |
| `u_csi_unpacket` | `csi_unpacket_2lane` | CSI-2 解包 |
| `u_raw10_unpacket` | `raw10_unpacket_2lane` | RAW10 解包 |
| `u_uial2axis` | `uial2axis` | 原生流转 AXI4-Stream 风格信号 |
| `image_correction` | `image_correction` | RAW 校正 |
| `u_isp_top` | `isp_top` | 去马赛克、AWB、位宽转换 |
| `u_video_in` | `video_in` | 视频写 DDR |
| `u_video_out` | `video_out` | DDR 读视频到 HDMI 像素域 |
| `u_mc_to_user_interface` | `mc_to_user_interface` | 用户接口到 DDR 控制器接口 |
| `u_ph1p35_324_ddr_wrapper` | `ph1p35_324_ddr_wrapper` | DDR2 控制器封装 |
| `u_hdmi_vtc` | `uivtc` | HDMI 时序 |
| `u_hdmi_mixer` | `hdmi_mixer` | 像素读请求和视频组合 |
| `u_hdmi_tx` | `hdmi_tx` | HDMI/TMDS 输出 |

## 摄像头与 MIPI 文件

摄像头配置：

- [`ae_set.v`](user_source/hdl_source/uiisp_beta/ae_set.v)
- [`uicfgcs500.v`](user_source/hdl_source/uics500_cfg/uicfgcs500.v)
- [`uics500reg.v`](user_source/hdl_source/uics500_cfg/uics500reg.v)
- [`uics500regAE.v`](user_source/hdl_source/uics500_cfg/uics500regAE.v)
- [`uii2c.v`](user_source/hdl_source/uics500_cfg/uii2c.v)
- [`SC500GainTbl.v`](user_source/hdl_source/uics500_cfg/SC500GainTbl.v)

MIPI D-PHY RX：

- [`mipi_dphy_rx_ph1p_mipiio_wrapper.sv`](user_source/hdl_source/mipi_dphy_rx/mipi_dphy_rx_ph1p_mipiio_wrapper.sv)
- [`ph1p_mipiio_rx_wrapper.v`](user_source/hdl_source/mipi_dphy_rx/ph1p_mipiio_rx_wrapper.v)
- [`hs_detect.enc.v`](user_source/hdl_source/mipi_dphy_rx/hs_detect.enc.v)
- [`channel_aligner.enc.v`](user_source/hdl_source/mipi_dphy_rx/channel_aligner.enc.v)
- [`channel_aligner_wrapper.enc.sv`](user_source/hdl_source/mipi_dphy_rx/channel_aligner_wrapper.enc.sv)
- [`byte_aligner.enc.v`](user_source/hdl_source/mipi_dphy_rx/byte_aligner.enc.v)
- [`byte_aligner_wrapper.enc.sv`](user_source/hdl_source/mipi_dphy_rx/byte_aligner_wrapper.enc.sv)

顶层配置：`LANE_NUM=2`、`BYTE_NUM=1`。MIPI 输出为 `S_csi_rx_clk`、`S_hs_rx_valid`、`S_hs_rx_data[15:0]`。

## ISP 文件

ISP 入口：[`isp_top.v`](user_source/hdl_source/isp/isp_top.v)

内部数据流：`demosaic -> data128_96 -> awb -> data_96bit_to_128bit`。

去马赛克相关：

- [`demosaic.v`](user_source/hdl_source/isp/demosaic_4x_2_0/demosaic.v)
- [`bilinear_interpolation.v`](user_source/hdl_source/isp/demosaic_4x_2_0/bilinear_interpolation.v)
- [`line_buffer_demosaic.v`](user_source/hdl_source/isp/demosaic_4x_2_0/line_buffer_demosaic.v)
- [`raw_matrix_3x3_buffer.v`](user_source/hdl_source/isp/demosaic_4x_2_0/raw_matrix_3x3_buffer.v)
- [`mipi_to_raw_converter.v`](user_source/hdl_source/isp/demosaic_4x_2_0/mipi_to_raw_converter.v)
- [`zhenghe.v`](user_source/hdl_source/isp/demosaic_4x_2_0/zhenghe.v)
- [`blk_mem_gen_demosaic.v`](user_source/hdl_source/isp/demosaic_4x_2_0/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v)
- [`blk_mem_gen_zhenghe.v`](user_source/hdl_source/isp/demosaic_4x_2_0/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v)

AWB 相关：

- [`awb.v`](user_source/hdl_source/isp/awb/awb.v)
- [`signal_delay.v`](user_source/hdl_source/isp/awb/signal_delay.v)
- [`divider_gate.v`](user_source/hdl_source/isp/awb/divider/divider_gate.v)
- [`blk_mem_gen_awb_delay_signal.v`](user_source/hdl_source/isp/awb/ram/blk_mem_gen_awb_delay_signal.v)

位宽转换：

- [`data128_96.v`](user_source/hdl_source/isp/data128_96/data128_96.v)
- [`data96_128.v`](user_source/hdl_source/isp/data96_128/data96_128.v)

## DDR 视频缓存文件

- [`video_in.v`](user_source/hdl_source/video_in.v)：接收 ISP 数据，跨时钟 FIFO 后写 DDR；使用 4 个帧缓冲基地址 `0`、`7000000`、`14000000`、`21000000`。
- [`video_out.v`](user_source/hdl_source/video_out.v)：按 HDMI 帧同步读 DDR，经 FIFO 输出 24 bit RGB。
- [`mc_to_user_interface.v`](user_source/hdl_source/mc_to_user_interface.v)：将读写请求打包进 155 bit FIFO。
- [`ph1p35_324_ddr_wrapper.v`](user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v)
- [`ddr2.v`](user_source/hdl_source/ph1p35_ddr/ddr2/ddr2.v)
- [`ph1p_ddrmc_wrapper_63f4ac254419.v`](user_source/hdl_source/ph1p35_ddr/ddr2/ph1p_ddrmc_wrapper_63f4ac254419.v)

DDR 内部 PHY/MC 文件位于 `user_source/hdl_source/ph1p35_ddr/ddr2/src/rtl/{phy,mc,init,clk,misc}`。

## HDMI 文件

- [`uivtc.v`](user_source/hdl_source/vtc/uivtc.v)：1024x600 时序。
- [`hdmi_mixer.v`](user_source/hdl_source/hdmi_mixer.v)：视频读请求和像素组合。
- [`hdmi_tx.v`](user_source/hdl_source/hdmi_tx.v)：HDMI TX 顶层。
- [`hdmi_1_4b_transmitter_core_wrapper.enc.v`](user_source/hdl_source/hdmi_1_4b_transmitter_core_wrapper.enc.v)：HDMI 1.4b/TMDS 编码。
- [`hdmi_phy_warpper.v`](user_source/hdl_source/hdmi_phy_warpper.v)：HDMI PHY 封装。
- [`lane_lvds_10_1.v`](user_source/hdl_source/lane_lvds_10_1.v)：10:1 LVDS 串行输出。
- [`I2S_receiver.v`](user_source/hdl_source/I2S_receiver.v)
- [`audio_arc_calculate.v`](user_source/hdl_source/audio_arc_calculate.v)
- [`key_remove_shakes.v`](user_source/hdl_source/key_remove_shakes.v)

当前时序参数：`H_ActiveSize=1024`、`H_FrameSize=1344`、`V_ActiveSize=600`、`V_FrameSize=635`。

## IP 核清单

这些 IP 在 `td_project/camera_to_dsi_display.al` 中以 XML/IPC 登记：

| IP | 配置文件 | 用途 |
|---|---|---|
| `PLL` | [`PLL.xml`](user_source/ip_source/PLL/PLL.xml) | 时钟生成 |
| `w128_d512_fifo` | [`w128_d512_fifo.xml`](user_source/ip_source/w128_d512_fifo/w128_d512_fifo.xml) | 128 bit、深度 512 异步 FIFO |
| `w155_d512_fifo` | [`w155_d512_fifo.xml`](user_source/ip_source/w155_d512_fifo/w155_d512_fifo.xml) | 155 bit、深度 512 请求 FIFO |
| `blk_mem_gen_awb_delay_signal` | [`blk_mem_gen_awb_delay_signal.xml`](user_source/ip_source/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.xml) | AWB 延迟 RAM |
| `divider` | [`divider.ipc`](user_source/ip_source/divider/divider.ipc) | AWB 除法器 |
| `ddr2` | [`ddr2.xml`](user_source/hdl_source/ph1p35_ddr/ddr2/ddr2.xml) | DDR2 控制器和 PHY |
| `blk_mem_gen_demosaic` | [`blk_mem_gen_demosaic.xml`](user_source/hdl_source/isp/demosaic_4x_2_0/blk_mem_gen_demosaic/blk_mem_gen_demosaic.xml) | 去马赛克行缓存 |
| `blk_mem_gen_zhenghe` | [`blk_mem_gen_zhenghe.xml`](user_source/hdl_source/isp/demosaic_4x_2_0/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.xml) | 数据整合 RAM |

以 HDL/加密封装形式提供的专用核：

- MIPI D-PHY RX：`user_source/hdl_source/mipi_dphy_rx/*`
- HDMI 1.4b transmitter：`hdmi_1_4b_transmitter_core_wrapper.enc.v`
- HDMI PHY/LVDS serializer：`hdmi_phy_warpper.v`、`lane_lvds_10_1.v`

存在但当前顶层未直接使用：`MCU.v`、`MCU_f9f874759a41.v`、`w40_d512_fifo.v`。其中 `MCU` 由 `ps_wrapper.v` 引用，但 `ps_wrapper` 没有被当前顶层实例化。

## 工程约束

- [`pin.adc`](user_source/constraints_source/pin.adc)
- [`camera_to_dsi_display.sdc`](td_project/camera_to_dsi_display.sdc)

## 连接注意事项

1. `isp_top` 的 ready 信号连接不完整：顶层 `S_ISP_O_tready` 没有明显有效驱动，`isp_top.I_tready` 未连接。
2. `video_in.I_mipi_rx_error` 被固定为 `1'b0`，MIPI 错帧回退逻辑当前关闭。
3. `hdmi_tx` 的 `O_hdmi_clk_p`、`O_hdmi_tx_p` 未连接，实际使用 `O_tmds_ch0_p/ch1_p/ch2_p/clk_p`。
4. 工程 XML 中部分路径指向 `D:/2026fpga/al/lab_hd_1_mipi_hdmi`，打开工程时应确认实际加载目录。
5. `ph1p35_324_ddr_wrapper.v` 中的 `dhi_clk` 未显式声明，依赖 Verilog 隐式 net 行为。
