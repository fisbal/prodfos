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
; Tell Explorer the PDF association changed (icons and double-click refresh at once).
ChangesAssociations=yes

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
; If ProDFOS was once chosen as the PDF app from the portable zip ("Choose another app > prodfos.exe"),
; Windows keeps opening PDFs with THAT old copy (no Print, never updated). Windows stores that choice as
; Applications\prodfos.exe, so point it at the installed, self-updating ProDFOS. The user's choice of
; default app is kept; only the program it starts changes.
Root: HKCU; Subkey: "Software\Classes\Applications\prodfos.exe"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "ProDFOS"
Root: HKCU; Subkey: "Software\Classes\Applications\prodfos.exe\DefaultIcon"; ValueType: string; ValueData: "{app}\prodfos.exe,0"
Root: HKCU; Subkey: "Software\Classes\Applications\prodfos.exe\shell\open\command"; ValueType: string; ValueData: """{app}\prodfos.exe"" ""%1"""
Root: HKCU; Subkey: "Software\Classes\Applications\prodfos.exe\SupportedTypes"; ValueType: string; ValueName: ".pdf"; ValueData: ""
; Lists ProDFOS in Windows Settings > Default apps, so it can be chosen there too.
Root: HKCU; Subkey: "Software\ProDFOS\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "ProDFOS"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\ProDFOS\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "PDF reader, forms, scan and edit"
Root: HKCU; Subkey: "Software\ProDFOS\Capabilities\FileAssociations"; ValueType: string; ValueName: ".pdf"; ValueData: "ProDFOS.pdf"
Root: HKCU; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "ProDFOS"; ValueData: "Software\ProDFOS\Capabilities"; Flags: uninsdeletevalue

[Run]
; Also after a silent update, so ProDFOS comes back by itself.
Filename: "{app}\prodfos.exe"; Description: "{cm:LaunchProgram,ProDFOS}"; Flags: nowait postinstall
