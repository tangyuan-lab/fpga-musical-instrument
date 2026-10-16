$ErrorActionPreference = 'Stop'
$simulator = (Get-Command vsim -ErrorAction Stop).Source
$runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('fpga_2026-10-16_' + [guid]::NewGuid().ToString('N'))
if ($runRoot -match '[^\x00-\x7F]') {
    throw 'ModelSim 10.6d requires an ASCII temporary path. Set TEMP to an ASCII directory and retry.'
}
New-Item -ItemType Directory -Path $runRoot | Out-Null
$stages = @(
    @{ Name = 'ab_compare'; Script = 'run_ab.do' },
    @{ Name = 'long_tail'; Script = 'run_long_tail.do' },
    @{ Name = 'retrigger'; Script = 'run_retrigger.do' }
)
foreach ($stage in $stages) {
    $source = Join-Path $PSScriptRoot $stage.Name
    $target = Join-Path $runRoot $stage.Name
    New-Item -ItemType Directory -Path $target | Out-Null
    Get-ChildItem -LiteralPath $source -File | Where-Object { $_.Extension -in @('.v', '.sv', '.do') } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $target
    }
    Copy-Item -LiteralPath (Join-Path $source 'mem') -Destination $target -Recurse
    New-Item -ItemType Directory -Path (Join-Path $target 'sim') | Out-Null
    Push-Location $target
    try {
        & $simulator -c -do $stage.Script
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $($stage.Name)" }
    } finally { Pop-Location }
}
Write-Host "PASS: all 2026-10-16 simulations. Results: $runRoot"
