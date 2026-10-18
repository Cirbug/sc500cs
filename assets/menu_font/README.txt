固定中文菜单字库（含 REC1 延时摄影菜单）

范围
  主菜单：菜单、曝光、增益、图像设置、录制设置、显示模式、图像特效、标志、帧长。
  图像页：黑电平、伽马、数字亮度、饱和度、白平衡、降噪、恢复默认、直方图均衡。
  状态：返回、关闭、开启、自动、平滑、近灰、低、中、高、恢复。
  录制页：单张拍照、开始录制、停止录制、保存间隔、已保存、状态、返回。
  新增状态：空闲、写入、错误、录制。
  显示模式页：普通画面、图形识别、运动检测、红色目标跟踪，按 1..4 排序。
  画面特效说明：灰度、反色、二值化、复古色、边缘检测。
  形状类别说明：矩形、梯形、圆形、三角形、菱形；梯形仅保留类型接口兼容。
  数字、倍率和时间沿用现有 ASCII 字体。“安路”标志使用原有显示逻辑。

字模
  105 个去重汉字，每字 32x32 单色；0 号字形留空。
  2026-10-18 保留原 102 字的编号与像素，追加“直”“方”“均”，ROM 容量不变。
  jop3.0 主菜单由 MCU 的 mcu_menu.h / mcu_menu_map.h 生成；均衡行仅在 HEQ1 接口存在时显示。
  画面说明扩展保留原 89 字的编号和像素，追加 13 字，共用现有菜单 ROM 端口。
  2026-10-16 保留原 87 字的编号与全部像素，追加“帧”“长”两个字。
  新增两字使用本机 NotoSansSC-VF.ttf 的 Bold 实例，来源及 SHA256 见 manifest.json。
  Noto Sans SC Bold，28 像素栅格化并居中到 32x32，二值阈值 128。
  一行一个 32 位字，bit31 在左，地址 = 字编号*32 + 字内行号。
  ROM 填充到 128 字：4096x32 位，共 16384 字节。
  manifest.json 保存字编号、菜单文本、字体文件 SHA256 和生成参数。
  rows.hex 是独立仿真参考；RTL 内嵌相同常量，不依赖 readmemh 路径。
  effects.hex / shapes.hex：按特效或类别编号索引的四字映射，供逐像素仿真参考。
  源字体采用 SIL OFL 1.1，许可证见 OFL.txt。
  来源：https://github.com/google/fonts/tree/main/ofl/notosanssc

实现
  user_source/hdl_source/ui_font_cn.v：同步字库 ROM。
  user_source/hdl_source/ui_font_cn_map.vh：固定菜单字编号映射。
  user_source/hdl_source/ui_osd.v：默认中文渲染，参数 MENU_CHINESE=0 可编译英文版。
  主工程打开 RESULT_CHINESE=1，共享字库显示特效名称和形状结果。
  hdmi_mixer 的 SHAPE_LABEL_ENABLE=0 关闭原英文形状标签，保留原有框线。
  中文模式下视频、DE、HSYNC、VSYNC 全部统一增加一拍延迟。
  黑色字模背景透明，菜单底色与选中条透出。
  八行主菜单顶部为 y=644，底部仍为 y=1004；匹配 MCU 已同步更新触屏区域。
  标签查表使用 9 位地址（页 2 位、行 4 位、字位置 3 位），labels.hex 共 512 项。
  MCU 仍负责页面、选择、编辑、参数和按键/触屏操作。
  本版文本固定在 FPGA，不含 MCU 任意字符串写入接口、Flash 字库或 UTF-8 解析。

重新取模
  安装 Python Pillow，执行：
  python tools/generate_menu_font.py --font "字体路径/Noto Sans SC Bold (TrueType).otf"
  如需保留现有字模，仅追加新汉字，使用 --extend-existing。
  修改脚本中的 LABELS/VALUES/EFFECTS/SHAPES 可替换用字；超出 127 个字需扩大编号和 ROM。
  同时检查文字数量、菜单行距与点击区域，重新仿真及编译 FPGA。

验证和构建
  tests/tb_menu_chinese.v：逐像素比对字模、全部状态、菜单隐藏、数字/时钟、同步延迟。
  当前含录制功能版本：tests/build_sd_recorder.tcl。
  输出：build/sd_recorder_20261013/camera_to_dsi_display_sd.bit。
  录制菜单需要匹配的新 MCU 固件，详见 tests/SD_RECORDER.txt。
  上板检查：三页汉字完整、点击左减右加/返回、按钮显示隐藏、时钟、视频对齐。

初版汉化历史验证（不代表新增录制后的资源/时序）
  逐像素仿真通过：6 帧，453632 个中文文字区域像素，包含全部状态值和隐藏菜单。
  其余像素与英文基线逐像素比较；同步控制和空白期数据延迟检查通过。
  主菜单预览：build/menu_chinese_main.png
  图像页预览：build/menu_chinese_picture.png（状态值为仿真示例）
  TD 完整布局布线与 bitgen 完成：Setup WNS=0.112ns，Hold WNS=0.020ns，TNS 均为零。
  Slice 18688/21216（88.08%）；ERAM 63/108，较此前新增 3 块；DSP 14/40。
  字库采用 TD 的 AUTO ROM 推断。生成器已移除工具不支持的 block 属性；
  本次综合也按 AUTO 推断，字模与逻辑相同。
  尚未上板验证。
