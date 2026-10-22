param(
[ValidateSet('audio_smoke', 'polyphony_demo', 'polyphony_timbre_demo', 'pressure_audio', 'pressure_audio_hdmi', 'mcp3208_13key_hdmi', 'instrument_full', 'instrument_touch', 'instrument_touch16', 'instrument_workstation', 'adc_screen_diag', 'hdmi_colorbar_800x600', 'usb_touch_probe', 'pressure_audio_hdmi_touch_probe', 'uart_ping_echo', 'uart_tx_diag', 'midi_upload_probe', 'midi_player', 'lcd_ctp_test', 'lcd_only_test')]
    [string]$Target = 'pressure_audio',
    [switch]$ReuseSynthesis
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gowinExeCandidates = @(
    $env:GOWIN_SH,
    # 1.9.11 Education is the locally licensed command-line installation.
    # Keep 1.9.12 as a fallback for machines where its license is available.
    'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe',
    'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe'
)
$gowinExe = $gowinExeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if (-not $gowinExe) {
    throw "Gowin command line tool not found in: $($gowinExeCandidates -join ', ')"
}

$taskSourcePaths = @()
$taskSourceHashes = @{}
if ($Target -eq 'instrument_workstation') {
    # 防止长时间构建期间源码改变后，旧网表被标记为最新可下载位流。
    $taskSourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'rtl') -Recurse -File |
        Where-Object { $_.Extension -in @('.sv','.v','.inc') } | ForEach-Object FullName)
    $taskSourcePaths += @('build_instrument_workstation.tcl','build_instrument_workstation_pnr.tcl','instrument_workstation.cst','instrument_full.cst','instrument_full.sdc') |
        ForEach-Object { Join-Path $projectRoot "gowin\$_" }
    $taskSourcePaths += @((Join-Path $projectRoot 'config\instrument_registry.json'),
        (Join-Path $projectRoot 'scripts\prepare_workstation.py'))
    foreach ($taskSourcePath in $taskSourcePaths) {
        $taskSourceHashes[$taskSourcePath] = (Get-FileHash -LiteralPath $taskSourcePath -Algorithm SHA256).Hash
    }
}
$taskTcl = Join-Path $projectRoot "gowin\build_$Target.tcl"
if ($ReuseSynthesis) {
    # 只换SPI脚位时复用网表：必须匹配已发布位流的全部RTL/SDC，且电气属性一致。
    if ($Target -ne 'instrument_workstation') { throw 'ReuseSynthesis仅支持instrument_workstation。' }
    $taskPreviousFs = Join-Path $projectRoot 'build\ready-to-program\instrument_workstation_sram.fs'
    $taskNetlist = Join-Path $projectRoot 'build\gowin\instrument_workstation\impl\gwsynthesis\instrument_workstation.vg'
    $taskPreviousPnr = Join-Path $projectRoot 'build\gowin\instrument_workstation\impl\pnr\instrument_workstation.fs'
    foreach ($taskFile in @($taskPreviousFs,"$taskPreviousFs.sha256","$taskPreviousFs.sources.json",$taskNetlist,$taskPreviousPnr)) {
        if (!(Test-Path -LiteralPath $taskFile)) { throw '缺少已验证的网表/位流，须完整构建。' }
    }
    $taskPreviousHash = (Get-Content -LiteralPath "$taskPreviousFs.sha256" -Raw).Trim()
    if ((Get-FileHash -LiteralPath $taskPreviousFs).Hash -ne $taskPreviousHash -or
        (Get-FileHash -LiteralPath $taskPreviousPnr).Hash -ne $taskPreviousHash) { throw '旧位流与布局结果不一致，禁止复用。' }
    $taskPreviousSources = Get-Content -LiteralPath "$taskPreviousFs.sources.json" -Raw | ConvertFrom-Json
    foreach ($taskSourcePath in $taskSourcePaths | Where-Object { [IO.Path]::GetExtension($_) -in @('.sv','.v','.inc','.sdc') }) {
        $taskExpected = $taskPreviousSources.PSObject.Properties[$taskSourcePath]
        if (!$taskExpected -or $taskExpected.Value -ne $taskSourceHashes[$taskSourcePath]) {
            throw "RTL或时序约束已改变，须完整构建：$taskSourcePath"
        }
    }
    $taskBaseCst = Join-Path $projectRoot 'gowin\instrument_full.cst'
    $taskExpectedCst = $taskPreviousSources.PSObject.Properties[$taskBaseCst]
    if (!$taskExpectedCst -or $taskExpectedCst.Value -ne $taskSourceHashes[$taskBaseCst]) { throw '原始电气约束已改变，须完整构建。' }
    function Get-TaskNormalizedCst([string]$taskPath) {
        $taskText = Get-Content -LiteralPath $taskPath -Encoding UTF8 -Raw
        $taskText = [regex]::Replace($taskText,'//[^\r\n]*','')
        $taskText = [regex]::Replace($taskText,'(IO_LOC "mcp[01]_[^"]+"\s+)[^;]+;','${1}SPI_PIN;')
        return [regex]::Replace($taskText,'\s','')
    }
    if ((Get-TaskNormalizedCst $taskBaseCst) -ne
        (Get-TaskNormalizedCst (Join-Path $projectRoot 'gowin\instrument_workstation.cst'))) {
        throw '约束变化超出SPI球号，须完整构建。'
    }
    $taskPinnedNetlist = $taskPreviousSources.PSObject.Properties[$taskNetlist]
    if ($taskPinnedNetlist) {
        if ((Get-FileHash -LiteralPath $taskNetlist).Hash -ne $taskPinnedNetlist.Value) { throw '缓存网表哈希不一致。' }
    } elseif ((Get-Item -LiteralPath $taskNetlist).LastWriteTimeUtc -gt (Get-Item -LiteralPath $taskPreviousPnr).LastWriteTimeUtc) {
        throw '网表比已验证位流新，须完整构建。'
    }
    $taskSourcePaths += $taskNetlist
    $taskSourceHashes[$taskNetlist] = (Get-FileHash -LiteralPath $taskNetlist).Hash
    $taskTcl = Join-Path $projectRoot 'gowin\build_instrument_workstation_pnr.tcl'
    Write-Output '已验证RTL/SDC/电气设置一致，复用综合网表，仅重新布局布线。'
}
& $gowinExe $taskTcl
if ($LASTEXITCODE -ne 0) {
    throw "Gowin build failed, exit code: $LASTEXITCODE"
}

$buildDir = Join-Path $projectRoot "build\gowin\$Target"
$errors = Get-ChildItem -LiteralPath $buildDir -Recurse -Filter '*.log' |
    Select-String -Pattern '\bERROR\b'
if ($errors) {
    $errors | Select-Object -First 15
    throw 'Build logs contain an ERROR entry'
}

$bitstream = Join-Path $buildDir "impl\pnr\$Target.fs"
$timingFile = Join-Path $buildDir "impl\pnr\$($Target)_tr_content.html"
if (-not (Test-Path -LiteralPath $bitstream)) {
    throw 'SRAM bitstream was not generated'
}
if (-not (Test-Path -LiteralPath $timingFile)) {
    throw 'Timing analysis report is missing'
}

$timingText = Get-Content -Raw -LiteralPath $timingFile
foreach ($check in @('Setup', 'Hold')) {
    $pattern = "Numbers of $check Violated Endpoints</td>\s*<td>(\d+)</td>"
    $result = [regex]::Match($timingText, $pattern)
    if (-not $result.Success) {
        throw "Cannot parse $check timing result"
    }
    if ([int]$result.Groups[1].Value -ne 0) {
        throw "$check timing has violated endpoints"
    }
}

$readyDir = Join-Path $projectRoot 'build\ready-to-program'
foreach ($taskSourcePath in $taskSourcePaths) {
    if ((Get-FileHash -LiteralPath $taskSourcePath -Algorithm SHA256).Hash -ne $taskSourceHashes[$taskSourcePath]) {
        throw "构建期间源码已改变，未发布可下载位流：$taskSourcePath"
    }
}
New-Item -ItemType Directory -Path $readyDir -Force | Out-Null
$readyFile = Join-Path $readyDir "$($Target)_sram.fs"
Copy-Item -LiteralPath $bitstream -Destination $readyFile -Force
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $readyFile
$hashFile = "$readyFile.sha256"
Set-Content -LiteralPath $hashFile -Value $hash.Hash -Encoding ASCII
if ($Target -eq 'instrument_workstation') {
    $taskSourceHashes | ConvertTo-Json | Set-Content -LiteralPath "$readyFile.sources.json" -Encoding UTF8
}
Write-Output "Build passed: $readyFile"
Write-Output 'Setup/Hold violated endpoints: 0/0'
Write-Output "SHA256: $($hash.Hash)"

