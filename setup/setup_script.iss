; Build through scripts/Build-Release.ps1 so all inputs are matched and verified.
#ifndef BundleDir
  #error Supply /DBundleDir=<fresh prepared bundle> through Build-Release.ps1
#endif
#include "version.generated.iss"
#define MyAppName "Vegas Encoder"
#define MyAppURL "https://github.com/Kidsnd274/vegas-encoder"

[Setup]
AppId={{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}
AppName={#MyAppName}
AppVersion={#VeReleaseVersion}
VersionInfoVersion={#VeFileVersion}
AppPublisher=Kidsnd274
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Vegas Encoder
UninstallDisplayIcon={app}\VegasEncoder.exe
SetupIconFile={#BundleDir}\setup\app_icon.ico
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
PrivilegesRequired=admin
DisableProgramGroupPage=yes
DisableWelcomePage=no
OutputDir=..\dist
OutputBaseFilename=VegasEncoder-{#VeReleaseVersion}-{#VeFileVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern dark polar
CloseApplications=no
RestartApplications=no
Uninstallable=yes
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "custom"; Description: "Choose components"; Flags: iscustom

[Components]
Name: "app"; Description: "Vegas Encoder app"; Types: custom; Flags: fixed
Name: "vegas2026"; Description: "VEGAS Pro 2026 exporter plug-in (uncheck to remove an existing integration)"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BundleDir}\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BundleDir}\installer\ve-install.exe"; DestDir: "{app}\setup-support"; Flags: ignoreversion
Source: "{#BundleDir}\installer\ve-install.exe"; Flags: dontcopy
Source: "{#BundleDir}\installer\payload.json"; Flags: dontcopy
Source: "{#BundleDir}\installer\vegas-encoder.ini.in"; Flags: dontcopy
Source: "{#BundleDir}\installer\VegasEncoder-x64.fio2007-config"; Flags: dontcopy
Source: "{#BundleDir}\plugin\vegas-encoder.dll"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\Vegas Encoder"; Filename: "{app}\VegasEncoder.exe"
Name: "{autodesktop}\Vegas Encoder"; Filename: "{app}\VegasEncoder.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\VegasEncoder.exe"; Description: "Launch Vegas Encoder"; Flags: nowait postinstall skipifsilent

[Code]
#include "includes\helper.iss"
#include "includes\hosts.iss"
#include "includes\lifecycle.iss"
