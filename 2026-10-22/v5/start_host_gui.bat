@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>&1
if not errorlevel 1 (
    set "PYTHON_CMD=py"
) else (
    where python >nul 2>&1
    if errorlevel 1 (
        echo 未找到 Python 3。请先安装 Python 3.10 或更高版本。
        pause
        exit /b 1
    )
    set "PYTHON_CMD=python"
)

%PYTHON_CMD% -c "import serial" >nul 2>&1
if errorlevel 1 (
    echo 正在安装上位机所需的 pyserial...
    %PYTHON_CMD% -m pip install -r host_app\requirements.txt
    if errorlevel 1 (
        echo pyserial 安装失败，请检查网络或使用管理员权限重新运行。
        pause
        exit /b 1
    )
)

%PYTHON_CMD% -m host_app.gui
if errorlevel 1 (
    echo 上位机启动失败，请查看上面的错误信息。
    pause
)
endlocal
