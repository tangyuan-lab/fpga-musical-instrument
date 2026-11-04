@echo off
setlocal
cd /d "%~dp0"
set "PYTHON_CMD="
call :try_python "%~dp0.venv\Scripts\python.exe"
if not defined PYTHON_CMD call :try_python "%USERPROFILE%\miniconda3\python.exe"
if not defined PYTHON_CMD call :try_python python
if not defined PYTHON_CMD call :try_python py
if not defined PYTHON_CMD (
    echo No Python environment with workstation dependencies was found.
    echo Install dependencies using: python -m pip install -r host_app\requirements_workstation.txt
    pause
    exit /b 1
)
if /i "%~1"=="--check" (
    echo Workstation Python: %PYTHON_CMD%
    "%PYTHON_CMD%" -c "import sys; from host_app.workstation_gui import WorkstationWindow; print('PASS workstation imports: '+sys.executable)"
    exit /b
)
echo Workstation Python: %PYTHON_CMD%
"%PYTHON_CMD%" -m host_app.workstation_gui %*
if errorlevel 1 (
    echo Workstation startup failed. The error is shown above.
    pause
    exit /b 1
)
endlocal
exit /b 0

:try_python
"%~1" -c "from PySide6.QtWidgets import QApplication; import serial,mido,numpy,PIL,fitz,cv2" >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=%~1"
exit /b 0
