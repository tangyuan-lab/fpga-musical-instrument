param([switch]$ReuseSynthesis, [switch]$SynthesisOnly)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'build') -Force | Out-Null
& python scripts/prepare_workstation_v2.py
if ($LASTEXITCODE -ne 0) { throw 'V2 generation failed' }
$taskTcl = Join-Path $taskRoot 'gowin/build_instrument_workstation_v2.tcl'
$taskSources = @((Get-ChildItem -LiteralPath (Join-Path $taskRoot 'rtl') -File -Recurse | Where-Object {$_.Extension -in @('.v','.sv','.inc')} | ForEach-Object FullName))
$taskSources += @($taskTcl,(Join-Path $taskRoot 'gowin/instrument_workstation_v2.cst'),(Join-Path $taskRoot 'gowin/instrument_workstation_v2.sdc'))
$taskSources += @((Join-Path $taskRoot 'gowin/build_instrument_workstation_v2_syn.tcl'),(Join-Path $taskRoot 'gowin/build_instrument_workstation_v2_pnr.tcl'),(Join-Path $taskRoot 'scripts/verify_workstation_pinout.py'),(Join-Path $taskRoot 'config/instrument_registry.json'))
$taskHashes = @{}
foreach ($taskSource in $taskSources) { $taskHashes[$taskSource] = (Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash }
$taskExe = $env:GOWIN_SH
if (!$taskExe) { $taskExe = 'C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' }
if (!(Test-Path -LiteralPath $taskExe)) { throw '请设置GOWIN_SH为本机gw_sh.exe路径' }
$taskNetlist = Join-Path $taskRoot 'build/gowin/instrument_workstation_v2/impl/gwsynthesis/instrument_workstation_v2.vg'
$taskCache = Join-Path $taskRoot 'build/gowin/instrument_workstation_v2/synthesis_cache.json'
$taskSynTcl = Join-Path $taskRoot 'gowin/build_instrument_workstation_v2_syn.tcl'
$taskPnrTcl = Join-Path $taskRoot 'gowin/build_instrument_workstation_v2_pnr.tcl'
$taskSynHashes = @{}
foreach ($taskSource in $taskSources) { if ($taskSource -match '\.(v|sv|inc)$') { $taskSynHashes[$taskSource] = $taskHashes[$taskSource] } }
$taskSynHashes[$taskSynTcl] = (Get-FileHash -LiteralPath $taskSynTcl -Algorithm SHA256).Hash
function Invoke-V2Gowin([string]$Tcl, [string]$Log) {
    $ErrorActionPreference = 'Continue'
    & $taskExe $Tcl 2>&1 | Tee-Object -FilePath $Log
    $taskResult = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($taskResult -ne 0 -or (Select-String -LiteralPath $Log -Pattern 'ERROR\s*\(' -Quiet)) { throw "Gowin failed; see $Log" }
}
if ($ReuseSynthesis) {
    if (!(Test-Path -LiteralPath $taskCache) -or !(Test-Path -LiteralPath $taskNetlist)) { throw 'No verified synthesis cache' }
    $taskCached = Get-Content -LiteralPath $taskCache -Raw | ConvertFrom-Json
    if ((Get-FileHash -LiteralPath $taskNetlist -Algorithm SHA256).Hash -ne $taskCached.netlist) { throw 'Cached netlist hash mismatch' }
    foreach ($taskSource in $taskSynHashes.Keys) {
        if ($taskCached.sources.$taskSource -ne $taskSynHashes[$taskSource]) { throw "Synthesis cache stale: $taskSource" }
    }
} else {
    $taskStarted = Get-Date
    Invoke-V2Gowin $taskSynTcl (Join-Path $taskRoot 'build/instrument_workstation_v2_synthesis.log')
    if (!(Test-Path -LiteralPath $taskNetlist) -or (Get-Item -LiteralPath $taskNetlist).LastWriteTime -lt $taskStarted) { throw 'No fresh netlist produced' }
    foreach ($taskSource in $taskSynHashes.Keys) {
        if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ne $taskSynHashes[$taskSource]) { throw "Sources changed during synthesis: $taskSource" }
    }
    @{netlist=(Get-FileHash -LiteralPath $taskNetlist -Algorithm SHA256).Hash;sources=$taskSynHashes} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $taskCache -Encoding UTF8
}
if ($SynthesisOnly) { Write-Output 'PASS V2 synthesis; cache bound to RTL hashes'; exit 0 }
$taskPnrStarted = Get-Date
Invoke-V2Gowin $taskPnrTcl (Join-Path $taskRoot 'build/instrument_workstation_v2_build.log')
$taskPnr = Join-Path $taskRoot 'build/gowin/instrument_workstation_v2/impl/pnr'
foreach ($taskArtifact in @('instrument_workstation_v2.fs','instrument_workstation_v2_tr_content.html','instrument_workstation_v2.pin.html')) {
    $taskArtifactPath = Join-Path $taskPnr $taskArtifact
    if (!(Test-Path -LiteralPath $taskArtifactPath) -or (Get-Item -LiteralPath $taskArtifactPath).LastWriteTime -lt $taskPnrStarted) { throw "No fresh PnR artifact: $taskArtifact" }
}
$taskTiming = Get-Content -LiteralPath (Join-Path $taskPnr 'instrument_workstation_v2_tr_content.html') -Raw
foreach ($taskCheck in @('Setup','Hold')) {
    $taskMatch = [regex]::Match($taskTiming,"Numbers of $taskCheck Violated Endpoints</td>\s*<td>(\d+)</td>")
    if (!$taskMatch.Success -or [int]$taskMatch.Groups[1].Value -ne 0) { throw "$taskCheck timing failed; bitstream not published" }
}
foreach ($taskSource in $taskSources) {
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ne $taskHashes[$taskSource]) { throw "Sources changed during build: $taskSource" }
}
& python (Join-Path $taskRoot 'scripts/verify_workstation_pinout.py') --target instrument_workstation_v2
if ($LASTEXITCODE -ne 0) { throw 'V2 actual pin report does not match confirmed ADC/UART/I2S wiring' }
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'build/ready-to-program') -Force | Out-Null
$taskReady = Join-Path $taskRoot 'build/ready-to-program/instrument_workstation_v2_sram.fs'
Copy-Item -LiteralPath (Join-Path $taskPnr 'instrument_workstation_v2.fs') -Destination $taskReady -Force
$taskHash = (Get-FileHash -LiteralPath $taskReady -Algorithm SHA256).Hash
Set-Content -LiteralPath "$taskReady.sha256" -Value $taskHash -Encoding ASCII
$taskHashes | ConvertTo-Json | Set-Content -LiteralPath "$taskReady.sources.json" -Encoding UTF8
Write-Output "PASS V2 Setup/Hold 0/0: $taskReady SHA256=$taskHash"
