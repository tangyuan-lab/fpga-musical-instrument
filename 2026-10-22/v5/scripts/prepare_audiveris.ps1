$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskTools = Join-Path $taskRoot 'build/tools/audiveris'
$taskInstaller = Join-Path $taskTools 'Audiveris-5.11.0-windowsConsole-x86_64.msi'
$taskRuntime = Join-Path $taskTools 'runtime'
$taskLog = Join-Path $taskTools 'extract.log'
$taskHash = '5f1b4e96a12c53c7da426814b76e599363c4181e291855996e0a6878dda95f71'
New-Item -ItemType Directory -Path $taskTools -Force | Out-Null
if (!(Test-Path -LiteralPath $taskInstaller)) {
    Invoke-WebRequest -Uri 'https://github.com/Audiveris/audiveris/releases/download/5.11.0/Audiveris-5.11.0-windowsConsole-x86_64.msi' -OutFile $taskInstaller
}
if ((Get-FileHash -LiteralPath $taskInstaller -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskHash) {
    throw 'Audiveris installer SHA256 differs from the official GitHub release digest'
}
# Extract the official package into the workspace, without registering a system installation.
$taskExe = Get-ChildItem -LiteralPath $taskRuntime -Filter Audiveris.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$taskExe) {
    $taskArgs = @('/a',('"'+$taskInstaller+'"'),'/qn',('TARGETDIR="'+$taskRuntime+'"'),'/l*v',('"'+$taskLog+'"'))
    $taskProcess = Start-Process -FilePath msiexec.exe -ArgumentList $taskArgs -PassThru -Wait -WindowStyle Hidden
    if ($taskProcess.ExitCode -notin @(0,3010)) { throw "Audiveris extraction failed: $($taskProcess.ExitCode); see $taskLog" }
    $taskExe = Get-ChildItem -LiteralPath $taskRuntime -Filter Audiveris.exe -Recurse | Select-Object -First 1
}
if (!$taskExe) { throw 'Audiveris executable missing from extracted package' }
Write-Output $taskExe.FullName
& $taskExe.FullName -version
if ($LASTEXITCODE -ne 0) { throw 'Audiveris runtime verification failed' }
