@echo off
setlocal
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
set "DOTNET_ROOT=%ARGONOV_DEPENDENCY_ROOT%\dotnet"
set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe"
if not exist "%ARGONOV_PWSH%" (
    echo ARGONOV PowerShell runtime was not found: "%ARGONOV_PWSH%"
    pause
    exit /b 2
)
echo Repairing ARGONOV SHELL dependencies...
"%ARGONOV_PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\Install-ArgonovDependencies.ps1" -InstallGit -InstallPython -InstallTerminal -InstallSensors
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
    echo Some components could not be installed. See:
    echo %%LOCALAPPDATA%%\ARGONOV\installer\dependency-install.log
) else (
    echo Dependency check and repair completed.
)
pause
exit /b %RESULT%
