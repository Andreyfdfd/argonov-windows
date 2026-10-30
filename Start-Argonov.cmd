@echo off
setlocal
if not defined ARGONOV_DEPENDENCY_ROOT set "ARGONOV_DEPENDENCY_ROOT=%LOCALAPPDATA%\Programs\ARGONOV-Dependencies"
set "DOTNET_ROOT=%ARGONOV_DEPENDENCY_ROOT%\dotnet"
set "DOTNET_ROOT_X64=%DOTNET_ROOT%"
set "ARGONOV_PWSH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell\pwsh.exe"
if not exist "%ARGONOV_PWSH%" (
    echo ARGONOV PowerShell runtime was not found: "%ARGONOV_PWSH%"
    echo Run Setup.exe again or repair the shared PowerShell dependency.
    exit /b 2
)
if exist "%ARGONOV_DEPENDENCY_ROOT%\Git\cmd" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\Git\cmd;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\PowerShell" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\PowerShell;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\dotnet" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\dotnet;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\Git\usr\bin" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\Git\usr\bin;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\Python314" set "PATH=%ARGONOV_DEPENDENCY_ROOT%\Python314;%ARGONOV_DEPENDENCY_ROOT%\Python314\Scripts;%PATH%"
if exist "%ARGONOV_DEPENDENCY_ROOT%\PythonPackages" set "PYTHONPATH=%ARGONOV_DEPENDENCY_ROOT%\PythonPackages;%PYTHONPATH%"
if exist "%LOCALAPPDATA%\Programs\Python\Launcher" set "PATH=%LOCALAPPDATA%\Programs\Python\Launcher;%PATH%"
"%ARGONOV_PWSH%" -NoLogo -NoProfile -NoExit -File "%~dp0Start-Argonov.ps1" %*
exit /b %ERRORLEVEL%
