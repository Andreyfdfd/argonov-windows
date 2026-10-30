@echo off
setlocal
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
set "DOTNET_ROOT=%ARGONOV_DEPENDENCY_ROOT%\dotnet"
set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe"
if not exist "%ARGONOV_PWSH%" (
    echo ARGONOV PowerShell runtime was not found: "%ARGONOV_PWSH%"
    exit /b 2
)
"%ARGONOV_PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\Install-ArgonovDependencies.ps1" %*
exit /b %ERRORLEVEL%
