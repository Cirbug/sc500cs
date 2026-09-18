$ErrorActionPreference = "Stop"

$buildTools = "F:\AnlogicFpga\FD_2026.1\toolchain\build-tools\bin"
$toolchain = "F:\AnlogicFpga\FD_2026.1\toolchain\gcc\riscv\ph1p35\bin"
$make = Join-Path $buildTools "make.exe"

if (-not (Test-Path -LiteralPath $make)) {
    throw "FD build tools were not found at: $buildTools"
}

$env:Path = "$buildTools;$toolchain;$env:Path"
& $make -j8
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
