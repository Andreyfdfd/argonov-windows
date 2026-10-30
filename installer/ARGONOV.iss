; ARGONOV SHELL - per-user installer
#define AppName "ARGONOV SHELL"
#define AppVersion "0.1.0"
#define AppPublisher "Andreyfdfd"
#define AppExeName "PowerShell\pwsh.exe"

[Setup]
AppId={{F62C96D2-2A2B-4F69-9F31-4DAA9F9F78D2}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\ARGONOV SHELL
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
Uninstallable=yes
UninstallDisplayIcon={localappdata}\Programs\ARGONOV-Dependencies\{#AppExeName}
OutputDir=..\dist
OutputBaseFilename=ARGONOV-SHELL-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
ChangesEnvironment=no
UsePreviousAppDir=yes
VersionInfoVersion=0.1.0.0
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"; Flags: unchecked
Name: "installGit"; Description: "Установить Git for Windows (MinGit, если отсутствует)"; GroupDescription: "Компоненты и зависимости:"; Flags: checkedonce
Name: "installPython"; Description: "Установить Python 3.14 и пакет QR-кодов qrcode + Pillow"; GroupDescription: "Компоненты и зависимости:"; Flags: checkedonce
Name: "installTerminal"; Description: "Установить Windows Terminal (если отсутствует)"; GroupDescription: "Компоненты и зависимости:"; Flags: checkedonce
Name: "installSensors"; Description: "Установить LibreHardwareMonitor для датчиков SYSINFO"; GroupDescription: "Компоненты и зависимости:"; Flags: checkedonce

[Dirs]
Name: "{localappdata}\Programs\ARGONOV-Dependencies"; Flags: uninsneveruninstall
Name: "{localappdata}\Programs\ARGONOV-Dependencies\PowerShell"; Flags: uninsneveruninstall
Name: "{localappdata}\Programs\ARGONOV-Dependencies\dotnet"; Flags: uninsneveruninstall
Name: "{app}\music"; Flags: uninsneveruninstall
Name: "{app}\vendor"; Flags: uninsneveruninstall
Name: "{app}\data"; Flags: uninsneveruninstall
Name: "{app}\config"; Flags: uninsneveruninstall

[Files]
Source: "..\payload\powershell\*"; DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\PowerShell"; Flags: ignoreversion recursesubdirs createallsubdirs uninsneveruninstall
Source: "..\payload\dotnet\*"; DestDir: "{localappdata}\Programs\ARGONOV-Dependencies\dotnet"; Flags: ignoreversion recursesubdirs createallsubdirs uninsneveruninstall
Source: "..\Start-Argonov.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Launch-Argonov.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Install-ArgonovDependencies.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Repair-ArgonovDependencies.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\setup\*"; DestDir: "{app}\setup"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\modules\*"; DestDir: "{app}\modules"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\profile.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Start-Argonov.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ARGONOV SHELL"; Filename: "{app}\Launch-Argonov.cmd"; WorkingDir: "{app}"
Name: "{autoprograms}\ARGONOV SHELL\Repair dependencies"; Filename: "{app}\Repair-ArgonovDependencies.cmd"; WorkingDir: "{app}"
Name: "{autodesktop}\ARGONOV SHELL"; Filename: "{app}\Launch-Argonov.cmd"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Launch-Argonov.cmd"; Description: "Запустить ARGONOV SHELL"; Flags: postinstall nowait skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  Params: string;
  CommandLine: string;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    Params := '';
    if WizardIsTaskSelected('installGit') then Params := Params + ' -InstallGit';
    if WizardIsTaskSelected('installPython') then Params := Params + ' -InstallPython';
    if WizardIsTaskSelected('installTerminal') then Params := Params + ' -InstallTerminal';
    if WizardIsTaskSelected('installSensors') then Params := Params + ' -InstallSensors';

    begin
      CommandLine := '/D /S /C ""' + ExpandConstant('{app}\Install-ArgonovDependencies.cmd') + '"' + Params + '"';
      if not Exec(ExpandConstant('{sys}\cmd.exe'), CommandLine, ExpandConstant('{app}'), SW_SHOW, ewWaitUntilTerminated, ResultCode) then
        MsgBox('ARGONOV установлен, но запуск установщика дополнительных компонентов не удался. Проверьте файл dependency-install.log в %LOCALAPPDATA%\ARGONOV\installer.', mbError, MB_OK)
      else if ResultCode <> 0 then
        MsgBox('ARGONOV установлен, но один или несколько компонентов не удалось установить. Подробности находятся в %LOCALAPPDATA%\ARGONOV\installer\dependency-install.log. Оболочку можно запустить и повторить настройку позже.', mbError, MB_OK);
    end;
  end;
end;
