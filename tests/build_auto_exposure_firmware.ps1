param([Parameter(Mandatory=$true)][string]$FdRoot)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildTools = Join-Path $FdRoot 'toolchain/build-tools/bin'
$riscvTools = Join-Path $FdRoot 'toolchain/gcc/riscv/ph1p35/bin'
if (!(Test-Path (Join-Path $riscvTools 'riscv64-unknown-elf-gcc.exe'))) {
    throw 'FdRoot must contain the PH1P35 RISC-V toolchain.'
}
$ramOut = (Join-Path $root 'build/auto_exposure/firmware_ram').Replace('\','/')
$flashOut = (Join-Path $root 'build/auto_exposure/firmware_flash').Replace('\','/')
& (Join-Path $root 'FDwork/anlu_app/build.ps1') -FdRoot $FdRoot -BuildRoot $ramOut
if ($LASTEXITCODE -ne 0) { throw 'RAM firmware build failed.' }
$previousPath = $env:Path
Push-Location (Join-Path $root 'FDwork/anlu_app2')
try {
    $env:Path = "$buildTools;$riscvTools;$previousPath"
    & (Join-Path $buildTools 'make.exe') all TARGET=anlu_app2 SDK_ROOT=../anlu `
        COMPILE_PREFIX=riscv64-unknown-elf- "TARGET_PATH=$flashOut" "APP_TAR_DIR=$flashOut/build"
    if ($LASTEXITCODE -ne 0) { throw 'Flash firmware build failed.' }
} finally {
    $env:Path = $previousPath
    Pop-Location
}
& python (Join-Path $root 'tests/check_mcu_ui_elf.py') "$ramOut/build/anlu_app.elf" --tools $riscvTools
if ($LASTEXITCODE -ne 0) { throw 'RAM capacity/startup validation failed.' }
# FD's normal launch uses each project's build/ directory. Publish the checked
# pair there too, so a new bit cannot silently run with a pre-MCU-menu ELF.
foreach ($item in @(
    @{ Source = $ramOut; Project = 'anlu_app'; Name = 'anlu_app' },
    @{ Source = $flashOut; Project = 'anlu_app2'; Name = 'anlu_app2' }
)) {
    $destination = Join-Path $root "FDwork/$($item.Project)/build"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    foreach ($extension in @('elf', 'bin', 'map')) {
        Copy-Item -LiteralPath (Join-Path $item.Source "build/$($item.Name).$extension") -Destination $destination
    }
}
