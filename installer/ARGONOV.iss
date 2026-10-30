# ARGONOV SHELL - per-user installer
#define AppName "ARGONOV SHELL"
#define AppVersion "0.1.0"
#define AppPublisher "Andreyfdfd"
#define AppExeName "runtime\pwsh.exe"

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
UninstallDisplayIcon={app}\{#AppExeName}
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
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные параметры:"; Flags: unchecked

[Dirs]
Name: "{app}\music"; Flags: uninsneveruninstall
Name: "{app}\vendor"; Flags: uninsneveruninstall
Name: "{app}\data"; Flags: uninsneveruninstall
Name: "{app}\config"; Flags: uninsneveruninstall

[Files]
Source: "..\payload\powershell\*"; DestDir: "{app}\runtime"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\modules\*"; DestDir: "{app}\modules"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\profile.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Start-Argonov.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ARGONOV SHELL"; Filename: "{app}\{#AppExeName}"; Parameters: "-NoLogo -NoExit -File ""{app}\Start-Argonov.ps1"""; WorkingDir: "{app}"
Name: "{autodesktop}\ARGONOV SHELL"; Filename: "{app}\{#AppExeName}"; Parameters: "-NoLogo -NoExit -File ""{app}\Start-Argonov.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Parameters: "-NoLogo -NoExit -File ""{app}\Start-Argonov.ps1"""; Description: "Запустить ARGONOV SHELL"; Flags: postinstall nowait skipifsilent
