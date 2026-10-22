param(
    [string]$Bitstream = ""
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Bitstream)) {
    $candidates = @(
        (Join-Path $root 'build\ready-to-program\lcd_ctp_test_sram.fs'),
        (Join-Path $root 'bitstream\lcd_ctp_test_sram.fs')
    )
    $Bitstream = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($Bitstream) -or -not (Test-Path -LiteralPath $Bitstream)) {
    throw "找不到位流文件，请把 .fs 路径作为参数传入。"
}
$programmers = @(
    'C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe',
    'C:\Gowin\Gowin_V1.9.11.03_Education_x64\Programmer\bin\programmer_cli.exe'
)
$cli = $programmers | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $cli) {
    throw '找不到 Gowin programmer_cli.exe，请先安装 Gowin Programmer。'
}
Write-Host "目标位流：$Bitstream"
& $cli --device GW5AT-60B --operation_index 2 --fsFile $Bitstream --cable-index 4 --frequency 15MHz
if ($LASTEXITCODE -ne 0) {
    throw "Gowin Programmer 返回错误码 $LASTEXITCODE"
}
Write-Host 'LCD/CTP SRAM 下载完成。断电后需要重新下载；要固化到 Flash 请另行选择 Flash 操作。'
