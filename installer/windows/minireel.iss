#ifndef AppVersion
  #error AppVersion must be provided by the packaging script.
#endif
#ifndef WindowsVersion
  #error WindowsVersion must be provided by the packaging script.
#endif
#ifndef BuildDir
  #error BuildDir must point to the complete Flutter Release directory.
#endif
#ifndef OutputDir
  #error OutputDir must be provided by the packaging script.
#endif

[Setup]
AppId={{2752B5ED-BFA8-4B35-A11F-8B5ED97C05AB}
AppName=MiniReel
AppVersion={#AppVersion}
AppVerName=MiniReel {#AppVersion}
AppPublisher=Minireel
AppPublisherURL=https://github.com/Minireel/minireel
AppSupportURL=https://github.com/Minireel/minireel/issues
AppUpdatesURL=https://github.com/Minireel/minireel/releases
VersionInfoVersion={#WindowsVersion}
VersionInfoProductVersion={#WindowsVersion}
VersionInfoProductTextVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\MiniReel
DefaultGroupName=MiniReel
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=MiniReel-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\minireel.exe
LicenseFile=..\..\License
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Excludes: "*.pdb,*.exp,*.lib"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MiniReel"; Filename: "{app}\minireel.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\MiniReel"; Filename: "{app}\minireel.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\minireel.exe"; Description: "{cm:LaunchProgram,MiniReel}"; Flags: nowait postinstall skipifsilent
