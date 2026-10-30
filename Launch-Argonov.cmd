@echo off
setlocal
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
where wt.exe >nul 2>&1
if not errorlevel 1 (
    wt.exe -p "ARGONOV SHELL"
    if not errorlevel 1 exit /b 0
)
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" (
    start "" "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -p "ARGONOV SHELL"
    exit /b 0
)
if exist "%ARGONOV_DEPENDENCY_ROOT%\WindowsTerminal\wt.exe" (
    start "" "%ARGONOV_DEPENDENCY_ROOT%\WindowsTerminal\wt.exe" -p "ARGONOV SHELL"
    exit /b 0
)
call "%~dp0Start-Argonov.cmd"
exit /b %ERRORLEVEL%
