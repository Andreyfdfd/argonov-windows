@echo off
setlocal
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
set "ARGONOV_COMMAND=cmd.exe /d /s /c ""%~dp0Start-Argonov.cmd"""
where wt.exe >nul 2>&1
if not errorlevel 1 (
    wt.exe -d "%USERPROFILE%" cmd.exe /d /s /c ""%~dp0Start-Argonov.cmd""
    if not errorlevel 1 exit /b 0
)
if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" (
    start "" "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" -d "%USERPROFILE%" cmd.exe /d /s /c ""%~dp0Start-Argonov.cmd""
    exit /b 0
)
if exist "%ARGONOV_DEPENDENCY_ROOT%\WindowsTerminal\wt.exe" (
    start "" "%ARGONOV_DEPENDENCY_ROOT%\WindowsTerminal\wt.exe" -d "%USERPROFILE%" cmd.exe /d /s /c ""%~dp0Start-Argonov.cmd""
    exit /b 0
)
call "%~dp0Start-Argonov.cmd"
exit /b %ERRORLEVEL%
