# PH1P35 UART1 Hello World

This program is built for JTAG loading into the MCU TCM at `0x08000000`.
It uses the Anlogic PH1P35 BSP and sends its log through USART1 at 115200 8N1.

Build from PowerShell:

```powershell
.\build.ps1
```

Output files are created under `build/`. The ELF used for JTAG debugging is:

```text
build/helloworld_ph1p35_tcm_uart1.elf
```

The FPGA must first be configured with:

```text
..\..\td_project\camera_to_dsi_display_Runs\phy_1\camera_to_dsi_display.bit
```
