@echo off
setlocal
set "DOTNET_ROOT=%~dp0dotnet"
set "DOTNET_ROOT_X64=%~dp0dotnet"
set "PATH=%DOTNET_ROOT%;%PATH%"
"%~dp0runtime\pwsh.exe" -NoLogo -NoExit -File "%~dp0Start-Argonov.ps1" %*
exit /b %ERRORLEVEL%
