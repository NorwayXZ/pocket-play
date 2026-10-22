[Setup]
AppId={{B3C64B95-3B40-49B2-8B9B-EB4157832823}
AppName=Pocket Play
AppVersion=0.3.0
DefaultDirName={localappdata}\Programs\Pocket Play
DefaultGroupName=Pocket Play
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=PocketPlay-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\PocketPlay.exe
[Files]
Source: "..\build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Pocket Play"; Filename: "{app}\PocketPlay.exe"
Name: "{autodesktop}\Pocket Play"; Filename: "{app}\PocketPlay.exe"; Tasks: desktopicon
[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"
[Run]
Filename: "{app}\PocketPlay.exe"; Description: "Launch Pocket Play"; Flags: nowait postinstall skipifsilent
