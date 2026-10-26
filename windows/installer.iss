; ProDFOS installer for Windows (Inno Setup 6). CI builds it after `flutter build windows`:
;   iscc /DAppVersion=1.0.N windows\installer.iss   ->   build\ProDFOS-Setup.exe
; Installs for the current user (no admin rights), so the app can update itself:
; it downloads a newer ProDFOS-Setup.exe and runs it with /SILENT (see lib/core/services/update_service.dart).

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6E2B8E57-3C3A-4F0B-9A0E-5D1C7F2A9B41}
AppName=ProDFOS
AppVersion={#AppVersion}
AppPublisher=Martin B
AppPublisherURL=https://github.com/fisbal/prodfos
DefaultDirName={localappdata}\Programs\ProDFOS
DefaultGroupName=ProDFOS
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir=..\build
OutputBaseFilename=ProDFOS-Setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\prodfos.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; An update closes the running ProDFOS first, then opens the new one.
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ProDFOS"; Filename: "{app}\prodfos.exe"
Name: "{autodesktop}\ProDFOS"; Filename: "{app}\prodfos.exe"; Tasks: desktopicon

[Registry]
; "Open with > ProDFOS" for PDF files (does not take over the default PDF app).
Root: HKCU; Subkey: "Software\Classes\ProDFOS.pdf"; ValueType: string; ValueData: "PDF document"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\ProDFOS.pdf\DefaultIcon"; ValueType: string; ValueData: "{app}\prodfos.exe,0"
Root: HKCU; Subkey: "Software\Classes\ProDFOS.pdf\shell\open\command"; ValueType: string; ValueData: """{app}\prodfos.exe"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\.pdf\OpenWithProgids"; ValueType: string; ValueName: "ProDFOS.pdf"; ValueData: ""; Flags: uninsdeletevalue

[Run]
; Also after a silent update, so ProDFOS comes back by itself.
Filename: "{app}\prodfos.exe"; Description: "{cm:LaunchProgram,ProDFOS}"; Flags: nowait postinstall
