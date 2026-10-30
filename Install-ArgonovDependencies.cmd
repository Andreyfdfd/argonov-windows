@echo off
setlocal
set "DOTNET_ROOT=%~dp0dotnet"
set "DOTNET_ROOT_X64=%~dp0dotnet"
set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
"%~dp0runtime\pwsh.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\Install-ArgonovDependencies.ps1" %*
exit /b %ERRORLEVEL%
