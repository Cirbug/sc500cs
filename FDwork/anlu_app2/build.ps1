$ErrorActionPreference = "Stop"
$buildTools = "F:\AnlogicFpga\FD_2026.1\toolchain\build-tools\bin"
$toolchain = "F:\AnlogicFpga\FD_2026.1\toolchain\gcc\riscv\ph1p35\bin"
$previousPath = $env:Path
Push-Location $PSScriptRoot
try {
    $env:Path = "$buildTools;$toolchain;$previousPath"
    & "$buildTools\make.exe" all TARGET=anlu_app2 SDK_ROOT=../anlu COMPILE_PREFIX=riscv64-unknown-elf-
    if ($LASTEXITCODE -ne 0) { throw "Firmware build failed: $LASTEXITCODE" }
} finally {
    $env:Path = $previousPath
    Pop-Location
}
