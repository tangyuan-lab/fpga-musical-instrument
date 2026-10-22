param([Parameter(Mandatory=$true)][string]$ModelSimBin)
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'handoff'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('fpga_basic_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$cases = @(
    @{Name='tb_key16_note_map'; Files=@('integration/keyboard_16/key16_note_map.v','integration/keyboard_16/tb_key16_note_map.sv')},
    @{Name='tb_integer_rules'; Files=@('integration/poly4_shared/tb_integer_rules.sv')},
    @{Name='tb_i2s_tx_16'; Files=@('integration/i2s/i2s_tx_16.v','sim/tb_i2s_tx_16.sv')}
)
Push-Location $testRoot
try {
    foreach ($case in $cases) {
        & (Join-Path $ModelSimBin 'vlib.exe') $case.Name
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
        $sources = @($case.Files | ForEach-Object { Join-Path $root $_ })
        & (Join-Path $ModelSimBin 'vlog.exe') -sv -work $case.Name @sources
        if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($case.Name)" }
        $output = & (Join-Path $ModelSimBin 'vsim.exe') -c -lib $case.Name $case.Name -do 'run -all; quit -f' 2>&1
        $status = $LASTEXITCODE
        $output | Set-Content -Encoding UTF8 ($case.Name + '.txt')
        if ($status -ne 0 -or -not ($output -match '# PASS ') -or ($output -match '\*\* (Fatal|Error)')) { throw "Simulation failed: $($case.Name)" }
        Write-Output "PASS $($case.Name)"
    }
    Write-Output "Logs: $testRoot"
} finally { Pop-Location }
