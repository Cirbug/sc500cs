param(
    [Parameter(Mandatory=$true)][string]$Port,
    [ValidateRange(1,1000)][int]$PassCount = 20,
    [ValidateRange(5,3600)][int]$TimeoutSeconds = 60
)
# USB UART only: no DTR/RTS reset, no FPGA programming or network changes.
$ErrorActionPreference = 'Stop'
$egOutput = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\output'))
New-Item -ItemType Directory -Force -Path $egOutput | Out-Null
$egLog = Join-Path $egOutput 'hardware_serial.log'
$egSerial = [IO.Ports.SerialPort]::new($Port,115200,[IO.Ports.Parity]::None,8,[IO.Ports.StopBits]::One)
$egSerial.DtrEnable = $false
$egSerial.RtsEnable = $false
$egSerial.Handshake = [IO.Ports.Handshake]::None
$egSerial.ReadTimeout = 500
$egSerial.NewLine = "`n"
$egPass = 0
$egBad = 0
$egTimeout = 0
$egLastSequence = $null
$egSequences = [Collections.Generic.HashSet[uint32]]::new()
$egDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
Set-Content -Encoding utf8 -LiteralPath $egLog -Value ("Started {0:o}; port={1}; 115200 8N1" -f (Get-Date),$Port)
try {
    $egSerial.Open()
    while ((Get-Date) -lt $egDeadline -and $egPass -lt $PassCount) {
        try { $egLine = $egSerial.ReadLine().Trim() } catch [TimeoutException] { continue }
        if ($egLine -notmatch '^(PASS|FAIL|TIME) seq=([0-9a-fA-F]{8})$') { continue }
        $egKind = $Matches[1]
        $egSequence = [Convert]::ToUInt32($Matches[2],16)
        Write-Host $egLine
        Add-Content -Encoding utf8 -LiteralPath $egLog -Value $egLine
        if ($egKind -eq 'PASS') {
            if (-not $egSequences.Add($egSequence)) { throw 'Duplicate PASS sequence; not counting it twice.' }
            if ($null -ne $egLastSequence -and $egSequence -ne (($egLastSequence + 1L) -band 0xffffffffL)) {
                throw 'Nonconsecutive PASS sequences; inspect the serial log.'
            }
            $egLastSequence = $egSequence
            $egPass++
        } elseif ($egKind -eq 'FAIL') { $egBad++; $egPass = 0; $egLastSequence = $null }
        else { $egTimeout++; $egPass = 0; $egLastSequence = $null }
    }
    $egSummary = "consecutive_pass=$egPass fail_events=$egBad timeout_events=$egTimeout"
    Add-Content -Encoding utf8 -LiteralPath $egLog -Value $egSummary
    if ($egPass -lt $PassCount) { throw "Hardware acceptance incomplete: $egSummary; log=$egLog" }
    Write-Host "HARDWARE PASS: $PassCount consecutive PH1->EG->PH1 byte-checked UDP returns."
    Write-Host "Earlier events: fail=$egBad timeout=$egTimeout. Log: $egLog"
} finally {
    if ($egSerial.IsOpen) { $egSerial.Close() }
    $egSerial.Dispose()
}
