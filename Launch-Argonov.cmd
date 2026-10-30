@echo off
setlocal
where wt.exe >nul 2>&1
if not errorlevel 1 (
    wt.exe -p "ARGONOV SHELL"
    if not errorlevel 1 exit /b 0
)
if exist "%LOCALAPPDATA%\Programs\ARGONOV-Dependencies\WindowsTerminal\wt.exe" (
    start "" "%LOCALAPPDATA%\Programs\ARGONOV-Dependencies\WindowsTerminal\wt.exe" -p "ARGONOV SHELL"
    exit /b 0
)
call "%~dp0Start-Argonov.cmd"
exit /b %ERRORLEVEL%
