param([string]$FdRoot, [string]$BuildRoot = $PSScriptRoot)
$ErrorActionPreference = "Stop"
if (!$FdRoot) {
    $FdRoot = @('D:\FD\FD','F:\AnlogicFpga\FD_2026.1') |
        Where-Object { Test-Path -LiteralPath "$_\toolchain\gcc\riscv\ph1p35\bin\riscv64-unknown-elf-gcc.exe" } |
        Select-Object -First 1
}
if (!$FdRoot) { throw 'Pass -FdRoot pointing to the installed FD directory.' }
$buildTools = Join-Path $FdRoot 'toolchain\build-tools\bin'
$toolchain = Join-Path $FdRoot 'toolchain\gcc\riscv\ph1p35\bin'
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot).Replace('\','/')
New-Item -ItemType Directory -Force -Path "$BuildRoot/build" | Out-Null
$previousPath = $env:Path
Push-Location $PSScriptRoot
try {
    $env:Path = "$buildTools;$toolchain;$previousPath"
    & "$buildTools\make.exe" all TARGET=anlu_app SDK_ROOT=../anlu COMPILE_PREFIX=riscv64-unknown-elf- "TARGET_PATH=$BuildRoot" "APP_TAR_DIR=$BuildRoot/build"
    if ($LASTEXITCODE -ne 0) { throw "Firmware build failed: $LASTEXITCODE" }
} finally {
    $env:Path = $previousPath
    Pop-Location
}
