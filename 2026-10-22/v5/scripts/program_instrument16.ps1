# 固定下载通过时序检查的 16 键 SRAM 位流；不写入 Flash。
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFs = Join-Path $taskRoot 'build\ready-to-program\instrument_touch16_sram.fs'
$taskTiming = Join-Path $taskRoot 'build\gowin\instrument_touch16\impl\pnr\instrument_touch16_tr_content.html'
if (!(Test-Path -LiteralPath $taskFs) -or !(Test-Path -LiteralPath "$taskFs.sha256")) {
    throw '请先执行 scripts/build.ps1 -Target instrument_touch16 并通过构建检查。'
}
$taskHash = (Get-FileHash -LiteralPath $taskFs -Algorithm SHA256).Hash
if ($taskHash -ne (Get-Content -LiteralPath "$taskFs.sha256" -Raw).Trim()) {
    throw '位流与 SHA256 记录不一致，请重新构建。'
}
$taskPnrFs = Join-Path $taskRoot 'build\gowin\instrument_touch16\impl\pnr\instrument_touch16.fs'
if ($taskHash -ne (Get-FileHash -LiteralPath $taskPnrFs -Algorithm SHA256).Hash) {
    throw '就绪位流与当前 PnR 产物不一致，请完成构建后再下载。'
}
$taskTimingText = Get-Content -LiteralPath $taskTiming -Raw
foreach ($taskCheck in @('Setup','Hold')) {
    $taskMatch = [regex]::Match($taskTimingText,"Numbers of $taskCheck Violated Endpoints</td>\s*<td>(\d+)</td>")
    if (!$taskMatch.Success -or [int]$taskMatch.Groups[1].Value -ne 0) {
        throw "$taskCheck 时序检查未通过，停止下载。"
    }
}
$taskCli = 'C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe'
$taskLog = Join-Path $taskRoot 'build\instrument_touch16_program.log'
Write-Output "SRAM file: $taskFs"
Write-Output "SHA256: $taskHash"
& $taskCli --device GW5AT-60B --operation_index 2 --fsFile $taskFs --cable-index 4 --frequency 15MHz 2>&1 |
    Tee-Object -FilePath $taskLog
if ($LASTEXITCODE -ne 0) { throw "SRAM 下载失败，退出码 $LASTEXITCODE；见 $taskLog" }
Write-Output '16 键 SRAM 下载完成。'
