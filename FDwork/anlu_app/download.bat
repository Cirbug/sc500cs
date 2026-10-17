@echo off
rem ============================================================
rem  One-click: download anlu_app.elf to MCU TCM (RAM) and run.
rem  Prerequisite: FPGA bit loaded (BitWriter) + JTAG driver installed.
rem ============================================================
set "PATH=D:\fang\toolchain\build-tools\bin;D:\fang\toolchain\gcc\riscv\ph1p35\bin;%PATH%"
set OCD=D:\fang\toolchain\openocd\fpsoc\bin\openocd.exe
set GDB=D:\fang\toolchain\gcc\riscv\ph1p35\bin\riscv64-unknown-elf-gdb.exe
set SCRIPTS=D:\fang\toolchain\openocd\fpsoc\share\openocd\scripts
set CFG=%~dp0onecable_ph1p35.cfg
set ELF=%~dp0build\anlu_app.elf

if not exist "%ELF%" (
    echo [ERROR] %ELF% not found. Build first with build.bat.
    pause
    exit /b 1
)

echo [1/3] Starting OpenOCD (JTAG)...
start "OpenOCD" "%OCD%" -s "%SCRIPTS%" -f "%CFG%"
timeout /t 5 /nobreak >nul

echo [2/3] Loading ELF to MCU and running...
"%GDB%" -batch -x "%~dp0download_ram.gdb" "%ELF%"

echo [3/3] Stopping OpenOCD...
taskkill /f /im openocd.exe >nul 2>&1
echo.
echo Done. If errors appear above, check: JTAG driver, FPGA bit, board power.
pause
