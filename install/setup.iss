#ifndef MyAppVersionBinary
  #define MyAppVersionBinary MyAppVersion
#endif

[Setup]
AppName=MaNet
AppId={{A388A7D5-5E82-439B-A908-1F1988B08017}
UsePreviousAppDir=no
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersionBinary}
VersionInfoProductVersion={#MyAppVersionBinary}
DefaultDirName={autopf}\MaNet
DefaultGroupName=MaNet
OutputDir=../dist-installer
OutputBaseFilename=MaNet-Setup-v{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin

[Files]
Source: "../release-temp/*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

Source: "drivers/ViGEmBus_Setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{tmp}\ViGEmBus_Setup.exe"; Parameters: "/quiet"; StatusMsg: "Installing controller driver..."; Flags: waituntilterminated

Filename: "{app}\MaNet.exe"; Description: "Launch MaNet"; Flags: nowait postinstall skipifsilent

[Icons]
Name: "{group}\MaNet"; Filename: "{app}\MaNet.exe"

Name: "{autodesktop}\MaNet"; Filename: "{app}\MaNet.exe"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    Exec(
      'netsh',
      'advfirewall firewall add rule name="MaNet Controller Server" dir=in action=allow program="' + ExpandConstant('{app}\data\flutter_assets\assets\server\manet_network_service.exe') + '" enable=yes profile=private,public',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );
  end;
end;