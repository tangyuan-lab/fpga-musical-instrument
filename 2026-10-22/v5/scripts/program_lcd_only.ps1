param(
    [string]$Bitstream = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Bitstream)) {
    $Bitstream = Join-Path $root 'build\ready-to-program\lcd_only_test_sram.fs'
}
if (-not (Test-Path -LiteralPath $Bitstream)) {
    throw "Bitstream not found: $Bitstream"
}

$programmers = @(
    'C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe',
    'C:\Gowin\Gowin_V1.9.11.03_Education_x64\Programmer\bin\programmer_cli.exe'
)
$cli = $programmers | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $cli) {
    throw 'Gowin programmer_cli.exe not found.'
}

& $cli --device GW5AT-60B --operation_index 2 --fsFile $Bitstream --cable-index 1 --frequency 2.5MHz
if ($LASTEXITCODE -ne 0) {
    throw "Programmer returned exit code $LASTEXITCODE. Check USB/JTAG connection."
}
