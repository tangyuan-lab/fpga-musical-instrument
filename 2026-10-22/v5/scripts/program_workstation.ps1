# 下载已通过时序检查且与当前源码一致的工作站 SRAM 位流。
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFs = Join-Path $taskRoot 'build\ready-to-program\instrument_workstation_sram.fs'
$taskTiming = Join-Path $taskRoot 'build\gowin\instrument_workstation\impl\pnr\instrument_workstation_tr_content.html'
foreach ($taskFile in @($taskFs,"$taskFs.sha256","$taskFs.sources.json",$taskTiming)) {
    if (!(Test-Path -LiteralPath $taskFile)) { throw '请先构建 instrument_workstation 并通过全部门槛。' }
}
$taskHash = (Get-FileHash -LiteralPath $taskFs -Algorithm SHA256).Hash
if ($taskHash -ne (Get-Content -LiteralPath "$taskFs.sha256" -Raw).Trim()) { throw '位流哈希不一致。' }
$taskPnrFs = Join-Path $taskRoot 'build\gowin\instrument_workstation\impl\pnr\instrument_workstation.fs'
if ($taskHash -ne (Get-FileHash -LiteralPath $taskPnrFs -Algorithm SHA256).Hash) { throw '位流与当前布局布线结果不一致。' }
$taskSourceHashes = Get-Content -LiteralPath "$taskFs.sources.json" -Raw | ConvertFrom-Json
foreach ($taskSource in $taskSourceHashes.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath $taskSource.Name -Algorithm SHA256).Hash -ne $taskSource.Value) {
        throw "源码已经改变，请重新构建：$($taskSource.Name)"
    }
}
$taskTimingText = Get-Content -LiteralPath $taskTiming -Raw
foreach ($taskCheck in @('Setup','Hold')) {
    $taskMatch = [regex]::Match($taskTimingText,"Numbers of $taskCheck Violated Endpoints</td>\s*<td>(\d+)</td>")
    if (!$taskMatch.Success -or [int]$taskMatch.Groups[1].Value -ne 0) { throw "$taskCheck 时序未通过。" }
}
$taskCli = 'C:\Gowin\Gowin_V1.9.12.03_x64\Programmer\bin\programmer_cli.exe'
& python (Join-Path $taskRoot 'scripts\verify_workstation_pinout.py')
if ($LASTEXITCODE -ne 0) { throw '实际PnR引脚报告未通过接线核对，禁止下载。' }
$taskLog = Join-Path $taskRoot 'build\instrument_workstation_program.log'
Write-Output "SRAM file: $taskFs"
Write-Output "SHA256: $taskHash"
& $taskCli --device GW5AT-60B --operation_index 2 --fsFile $taskFs --cable-index 4 --frequency 15MHz 2>&1 |
    Tee-Object -FilePath $taskLog
if ($LASTEXITCODE -ne 0) { throw "SRAM 下载失败；见 $taskLog" }
Write-Output '工作站 SRAM 下载完成。'
