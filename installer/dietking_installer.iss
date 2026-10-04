#define MyAppName "DietKing"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "DietKing"
#define MyAppExeName "DietKing.exe"

[Setup]
AppId={{D9E6C4F2-5E5A-4C2B-9D31-7A8D52C42026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\DietKing
DefaultGroupName={#MyAppName}

OutputDir=output
OutputBaseFilename=DietKing Setup

Compression=lzma
SolidCompression=yes

ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin

SetupIconFile=dietking.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autodesktop}\DietKing"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\DietKing"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "تشغيل DietKing"; Flags: nowait postinstall skipifsilent