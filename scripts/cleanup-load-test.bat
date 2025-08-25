@echo off
REM Simple batch file to cleanup Metricus load test resources
REM This must be run as Administrator
REM Compatible with PowerShell 5.1 and PowerShell 7

echo Metricus Load Test Cleanup
echo ==========================
echo.
echo This will remove any leftover test resources
echo Compatible with PowerShell 5.1 and PowerShell 7
echo Press Ctrl+C to cancel, or
pause

REM Try PowerShell 7 first (pwsh), then fall back to PowerShell 5.1 (powershell)
where pwsh >nul 2>nul
if %ERRORLEVEL% == 0 (
    echo Using PowerShell 7...
    pwsh.exe -ExecutionPolicy Bypass -File "%~dp0Cleanup-LoadTest.ps1"
) else (
    echo Using PowerShell 5.1...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Cleanup-LoadTest.ps1"
)

echo.
echo Cleanup completed. Press any key to exit.
pause >nul
