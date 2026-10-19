PH1P35 <-> EG4D20 独立 UDP 双向通信测试
2026-10-19

目的
    先验证 PH1P35 发包 -> EG4D20 收包并返回 -> PH1P35 收包校验。
    完整一轮 PASS 证明两个传输方向均成功，不依靠网口灯判定。
    这是独立测试工程，未合并摄像头、MCU、DDR、HDMI 或其他外设。
    sc500cs 原工程文件和已有未提交修改保持原状。
    将测试程序装载到 PH1P35 后，板子运行网口测试，不运行摄像头显示。
    测试结束后重新下载原摄像头程序即可恢复。

两端配置
    PH1P35：192.168.50.1:6001，MAC 02:00:00:00:00:01。
    EG4D20：192.168.50.2:6002，MAC 02:00:00:00:00:02。
    EG4D20 继续使用桌面 EG4D20 工程的既有回环程序，不需要改地址或协议。
    两块板 RJ45 用四对完整网线直连；各自正常供电。
    此时电脑只通过 USB 下载/看串口，不接入两板直连的网段。
    电脑有线口仍配置 192.168.50.1；不要将它与 PH1P35 接入同一二层网络，避免 IP 重复。

数据和判定
    复位后约 2 秒开始，每轮等待约 1 秒后发送下一包。
    UDP payload 固定 64 字节：PH1E(4字节)、大端32位序号(4字节)、
    后续第 i 字节为 i XOR 序号低8位 XOR 0xA5。
    一发一收，回包端口、长度、64字节内容必须全部一致才 PASS。
    缺少回包或发送请求未获响应：TIME；内容、长度、序号、端口错误：FAIL。
    应用层序号从0递增，不把上轮延迟或重复回包算作本轮成功。
    这是固定对端的诊断协议，不是任意对端协议、TCP 或高吞吐测试。
    不支持10/100M链路，必须协商千兆。

观察结果
    PH1P35 USB串口：115200 / 8N1，无流控。
    PASS seq=00000000
    PASS seq=00000001
    ...
    TIME 表示超时；FAIL 表示收到不匹配的数据包。
    LED0：PHY复位流程完成（不能当作链路已连接）。
    LED1：本地心跳；LED2：每次PASS翻转；LED3：出现过失败/超时后常亮。
    LED3亮后不会自动清除，复位/重新下载后清除；正常PASS仍可继续。
    工程内部另有 sent_count/pass_count/timeout_count/bad_count 便于仿真查看。

实板验收步骤
    1. 确认主板是所用康芯PH1P35MDG324/50MHz/YT8511板卡及下列管脚布局。
       本机参考原理图和厂家例程对应此布局，用户尚未确认主板完整型号。
    2. EG4D20 保持/下载本目录 output/eg4d20_udp_loop.bit（来自已验证EG4D20工程）。
    3. PH1P35 下载本独立工程 output/ph1_udp_selftest.bit；建议先加载到SRAM。
       不要把 PH1 文件下载到 EG4D20，也不要把 EG4 文件下载到 PH1P35。
    4. 两板网线直连，等待千兆链路建立。
    5. 在设备管理器查看 PH1P35 的 USB串口号，关闭占用它的串口工具。
       在本工程目录 PowerShell 中运行（COM9仅为示例）：
       powershell -ExecutionPolicy Bypass -File .\tools\monitor_link.ps1 -Port COM9
    6. 连续20次不同序号PASS并保留日志，才算实际双向通信验收通过。
       测试脚本会报告此前出现的FAIL/TIME，不会隐去失败事件。
    本次没有自动下载主板，也没有物理改接两板网线，实板验收状态见 output/validation.json。

管脚（独立测试，不与摄像头约束混用）
    系统时钟 C4，50MHz；PHY RESET_N V8。
    RXC V3；RX_CTL N8；RXD[0..3] N9/T7/T8/T9。
    TXC U9；TX_CTL R10；TXD[0..3] R11/P11/T10/R12。
    LED[0..3] D10/E10/C6/D6；USB串口TX H1。
    PHY MDIO/MDC未加入，沿用板载上电strap，不声称已读回协商/延迟寄存器。
    原sc500cs使用R10作复位、R11作背光，后续合并前必须核对实际接线并解决冲突。
    本测试采用PHY参考方案的TX时钟与OUTDEL，实际相位/电平仍需实板确认。

复现
    打开 ph1_udp_selftest.al，顶层 ph1_udp_selftest，器件 PH1P35MDG324 -3。
    仿真：python .\tests\run_link.py
    默认ModelSim F:/win64，可通过 MODELSIM_BIN 指定安装目录。
    默认对端工程为桌面EG4D20，可通过 EG4D20_ROOT 指定其他路径。
    构建：
    & 'D:/New Folder/bin/td_commands_prompt.exe' 'C:/Users/21397/Desktop/fpga1/sc500cs/board_link/ph1_udp_selftest/tools/build.tcl'
    TD退出码不足以判断成功，必须看到 PH1_EG4D_LINK_BUILD_COMPLETE 且时序无负裕量。
    完整日志和大型文件：桌面 bank/ph1_eg4d_link_20261019。
    tools/build.tcl含本机绝对路径，移动项目后应更新。

参考与版权
    网络协议栈来自既有 EG4D20 工程中修复并验证的米联客参考RTL。
    PH1 RGMII/PLL/管脚来源：
    D:/HX1P35A_Contest_202606/2_Example/33_ethernet_udp_led。
    原始版权头均保留，按原资料的用途和许可使用。
    硬件图：3_原理图/开发板原理图/HX1P35B_FT_40P_2.pdf、_9.pdf。
    已查看原理图并核对管脚，不能把参考板型号确认等同于用户实板型号确认。

本次最终离线结果
    双端真实UDP/ARP/MAC栈仿真通过；PHY/PLL/RGMII在该仿真中绕过。
    6个发包与6个回包内容、地址、端口、IPv4校验和、Ethernet FCS均正确。
    人为屏蔽其中1个回包：5次PASS，1次TIME，恢复后继续成功。
    单元验证包含错误字节/端口/长度、截断、超长、旧序号、无应答、请求卡住及恢复。
    串口PASS/FAIL/TIME均经过逐位解码检查。
    TD当前约束下 Setup WNS +0.884ns，Hold WNS +0.020ns，TNS均为0；覆盖率99.97%。
    LUT6 2747/21216、寄存器3264/42432、ERAM20K 10/108、PLL 1/6。
    接收IDDR改接统一复位，RX采样改走PH1P_PHY_SCLK_V2专用IO时钟，
    修复初次构建接收输入保持时序失败；未删除或放宽输入延迟约束来掩盖失败。
    系统时钟约束按PLL实际输入修正为50MHz，未沿用例程的25MHz误设。
    保留生成PLL的IO/位置告警及级联时钟告警，最终时序已通过，仍需实板验证。
    未检测到主板USB串口，仅有蓝牙COM3/COM4；未自动下载或宣称双板实测通过。
