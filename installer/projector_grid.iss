#define AppName "Projector Grid"
#define AppExeName "projector_grid.exe"
#define AppPublisher "Aleksei Vlasov"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=installer\output\
OutputBaseFilename=ProjectorGrid_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoVersion={#AppVersion}
SourceDir=..\

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Windows puts the app's icon in a toast's header only for an AUMID that a
; Start menu shortcut carries; both must match DesktopNotificationService.
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; AppUserModelID: "ProjectorGrid.ProjectorGrid"; AppUserModelToastActivatorCLSID: "B6C4A1E2-5F3D-4E8A-9C71-2D0F8E6A4B13"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; Web Access (TCP) and OSC (UDP) listen on ports the user can change, so the
; rule allows the program, not a port. Many machines have firewall
; notifications off and block it silently; where the prompt does show, a
; Cancel leaves a block rule for the exe that outranks any allow rule, so
; that goes first. Windows names the prompt's rules after the exe's
; FileDescription, the same name as ours, so deleting by that name clears
; both and keeps rules an admin added under another name. Sites' show
; networks are usually unidentified, i.e. Public, hence any profile, limited
; to the local subnet.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#AppName}"" program=""{app}\{#AppExeName}"""; StatusMsg: "Configuring Windows Firewall..."; Flags: runhidden
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#AppName}"" dir=in action=allow program=""{app}\{#AppExeName}"" enable=yes profile=any remoteip=localsubnet"; StatusMsg: "Configuring Windows Firewall..."; Flags: runhidden
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#AppName}"" program=""{app}\{#AppExeName}"""; Flags: runhidden; RunOnceId: "RemoveFirewallRule"
