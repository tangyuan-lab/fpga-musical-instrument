Set-Location (Split-Path -Parent $PSScriptRoot)

$pythonCommand = Get-Command py -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand) {
    & py -m host_app.gui
    exit $LASTEXITCODE
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand) {
    & python -m host_app.gui
    exit $LASTEXITCODE
}

Write-Error "没有找到 Python。请安装 Python 3.10+，然后执行：python -m pip install -r host_app\requirements.txt"
exit 1
