@echo off
REM Simple batch file to run Metricus load test
REM This must be run as Administrator
REM Compatible with PowerShell 5.1 and PowerShell 7

echo Metricus Load Test
echo ==================
echo.
echo This will run a 2-minute load test on port 8080
echo Compatible with PowerShell 5.1 and PowerShell 7
echo Press Ctrl+C to cancel, or
pause

REM Try PowerShell 7 first (pwsh), then fall back to PowerShell 5.1 (powershell)
where pwsh >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Using PowerShell 7...
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0Run-MetricusLoadTest.ps1"
) else (
    echo Using PowerShell 5.1...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Run-MetricusLoadTest.ps1"
)

echo.
echo Test completed. Press any key to exit.
pause >nul
