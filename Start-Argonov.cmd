@echo off
setlocal
set "DOTNET_ROOT=%~dp0dotnet"
set "DOTNET_ROOT_X64=%~dp0dotnet"
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
if exist "%ARGONOV_DEPENDENCY_ROOT%\Git\cmd" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\Git\cmd;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\Python314" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\Python314;%ARGONOV_DEPENDENCY_ROOT%\Python314\Scripts;%PATH%"
if exist "%LOCALAPPDATA%\Programs\Python\Launcher" set "PATH=%LOCALAPPDATA%\Programs\Python\Launcher;%PATH%"
"%~dp0runtime\pwsh.exe" -NoLogo -NoProfile -NoExit -File "%~dp0Start-Argonov.ps1" %*
exit /b %ERRORLEVEL%
