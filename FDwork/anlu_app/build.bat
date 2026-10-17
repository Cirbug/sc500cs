@echo off
rem ============================================================
rem  anlu_app (RAM debug) one-click build
rem  Double-click this file to build. Output: build\anlu_app.elf
rem ============================================================
set "PATH=D:\fang\toolchain\build-tools\bin;D:\fang\toolchain\gcc\riscv\ph1p35\bin;%PATH%"
cd /d "%~dp0"
"D:\fang\toolchain\build-tools\bin\make.exe" all TARGET=anlu_app SDK_ROOT=../anlu COMPILE_PREFIX=riscv64-unknown-elf-
echo.
if %ERRORLEVEL% EQU 0 (
    echo ============================================
    echo   BUILD OK: build\anlu_app.elf
    echo ============================================
) else (
    echo ============================================
    echo   BUILD FAILED: see the messages above
    echo ============================================
)
echo.
pause
