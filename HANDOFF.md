# 工程交接指南 (Project Handoff Guide)

把本工程（FPGA MCU SDK + 应用）交给另一台电脑，完成编译和下载。
按同型号开发板、板载 JTAG、FD IDE 调试 MCU 到 RAM 的方式说明。

---

## 0. 换电脑只需本地化三处

其余相对路径 / FD 变量尽量保留，不要全局替换盘符：

1. **工程实际位置**（例如 `E:\FPGA\sc500cs`）
2. **FD 安装位置**（例如 `D:\Anlogic\FD_2026.2`）
3. **USB 下载器位置**（JTAG Cable，必须重新扫描选择）

---

## 1. 需要发送的文件

- 推荐发送**完整工程**，并附上与源码匹配的 FPGA `.bit` 文件。
- 至少保留以下目录关系：

```text
FDwork\
├─ anlu\          SDK 工程
├─ anlu_app\      MCU RAM 调试工程
└─ shared\        应用依赖的公共代码
```

- `.project`、`.cproject`、`.settings` 等**带点的文件和目录也要保留**。
- **不要只发送 `anlu_app`**，它依赖 `anlu` 和 `shared`。
- 首次适配只用 `anlu_app`，**不要混用 `anlu_app2`**（那是 Flash/XIP 配置）。

---

## 2. 安装 FD 和下载器驱动

1. 安装 FD（版本见第 3 步，本机实际为 **FD_Release_2026.2**）。
2. 安装配套下载器驱动。
3. 找到同时含 `fd.exe` 和 `toolchain` 的目录，这就是 **FD 安装根目录**：

```text
D:\Anlogic\FD_2026.2\fd.exe
D:\Anlogic\FD_2026.2\toolchain\build-tools\bin\make.exe
D:\Anlogic\FD_2026.2\toolchain\gcc\riscv\ph1p35\bin\riscv64-unknown-elf-gcc.exe
```

若安装后多套一层目录，以真正包含这些文件的目录为准。

---

## 3. 修正旧路径

- 若 `anlu\.PlatformProject` 里还有旧路径 `PROJECT_LOCATION=D:/2026fpga/...`，改成对方自己的 SDK 位置，例如 `PROJECT_LOCATION=E:/FPGA/sc500cs/FDwork/anlu`。
- `build.ps1` 已支持 `-FdRoot` 参数，编译时传入对方 FD 根目录即可（见第 5 步）。
- 调试配置里的 OpenOCD/GDB 用 `${IDE_ROOT_PATH}` 变量，无需改。

---

## 4. 导入工程

1. 启动 FD，选一个**新的工作空间**（不必与源码同目录），例如 `E:\FD_workspace\camera`。
2. `File → Import → General → Existing Projects into Workspace`。
3. 根目录选 `...\FDwork`，勾选 `anlu` 和 `anlu_app`。
4. **不要勾选** Copy projects into workspace（保留与 shared 的相对关系）。
5. 项目名保持 `anlu`、`anlu_app` 不变。
6. 若提示同名项目已存在，先核对旧项目位置；移除引用时**不要删除磁盘文件**。

---

## 5. 编译

方式 A（IDE）：

1. 选 `anlu_app`。
2. `Project → Clean` 清理旧产物。
3. 右键 `anlu_app` → `Build Project`。
4. 看 Console 确认无错误。

方式 B（命令行，已验证可用）：

```powershell
powershell -ExecutionPolicy Bypass -File E:\FPGA\sc500cs\FDwork\anlu_app\build.ps1 -FdRoot 'D:\Anlogic\FD_2026.2'
```

（或直接双击 `FDwork\anlu_app\build.bat`）

成功后产物：`FDwork\anlu_app\build\anlu_app.elf`

---

## 6. 下载 bit + 调试

1. 开发板供电，连接板载 JTAG。
2. 用 BitWriter 下载**匹配的 FPGA bit**；下载完**断开 BitWriter 下载器连接**再关闭（否则占用 JTAG，FD 连不上）。
3. `Run → Debug Configurations → anlu_app_onecable`。
4. **重新扫描选择对方电脑的 JTAG Cable**，频率保持 1000 kHz。
5. 核对：Project=`anlu_app`、Application=`build/anlu_app.elf`、OpenOCD/GDB 用 `${IDE_ROOT_PATH}`、GDB 端口 `3333`、Load image/symbols 开启、FD 自动下载 FPGA 关闭。
6. `Apply → Debug`，停在 `main()` 后按 `F8` 运行。

> 这是 TCM/RAM 调试下载，**断电后程序不保留**（需固化走 `anlu_app2` 的 Flash 流程）。

---

## 7. 常见问题

| 报错 / 现象 | 优先检查 |
|---|---|
| 找不到 `rules.mk` | `anlu` 是否导入、SDK 路径是否正确 |
| 找不到 `../shared/...` | 是否漏发 `shared`、目录关系是否被打乱 |
| 找不到 gcc、make | FD 根目录、工具链路径 |
| 找不到 `anlu_app.elf` | 是否编译成功、Application 路径是否正确 |
| `make: *** [rules.mk:380] Error 2` | make 用了 cmd.exe → 需确保 `sh.exe` + GNU find 在 PATH（工程 Makefile 已用 `override SHELL` 强制，若仍报错请发 Error 2 上面几行） |
| `Debug session already started` | 先 Terminate 旧会话 |
| 无法打开 USB/JTAG | 驱动、重新选 Cable、下载器被 BitWriter 占用 |
| `Unsupported DTM version: 15` | JTAG 链路、所下载 bit、供电和下载器选择 |

---

## 附：本机已做的自动化修复

- `build.ps1`：支持 `-FdRoot`，并加 `$PSNativeCommandUseErrorActionPreference=$false`（防止 stderr 警告被当致命错误）。
- `anlu_app/Makefile`、`anlu_app2/Makefile`：`override SHELL := .../sh.exe` + `override export PATH`（修复 Windows find 导致的 Error 2）；`-Wl,--no-warn-rwx-segments`（消除 RWX 链接警告）。
- `onecable_ph1p35.cfg`：子配置路径改为绝对路径（修复 `./ph1p35_mcu_ir8.cfg` 找不到）。
- `FDwork\.project`：已改名为 `.project.bak`（修复 FD 导入报 "can not get FDwork's project type"）。
