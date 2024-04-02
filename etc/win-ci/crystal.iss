#define MyAppName "Crystal"
#define VersionFile FileOpen("portable\src\VERSION")
#define MyAppVersion FileRead(VersionFile)
#define MyAppVersionNum StringChange(MyAppVersion, "-dev", "")
#expr FileClose(VersionFile)
#define MyAppPublisher "Manas Technology Solutions"
#define MyAppURL "https://crystal-lang.org/"
#define MyAppExeName "crystal.exe"
#define MyAppCopyright GetFileCopyright("portable\" + MyAppExeName)
#define MyAppAssocName MyAppName + " Source File"
#define MyAppAssocExt ".cr"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

#define MajorNum 0
#define MinorNum 0
#expr UnpackVersionComponents(StrToVersion(MyAppVersionNum), MajorNum, MinorNum, null, null)

[Setup]
AppId={{7C307DDF-447E-46C5-BB3B-47A6F652D7C8}
AppName={#MyAppName} x86_64-windows-msvc
AppVersion={#MyAppVersion}
AppCopyright={#MyAppCopyright}
VersionInfoVersion={#MyAppVersionNum}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={autopf}\{#MyAppName}
OutputBaseFilename=crystal-setup
LicenseFile=portable\LICENSE.txt

ChangesEnvironment=yes
ChangesAssociations=yes

DefaultGroupName={#MyAppName} {#MyAppVersion}
AllowNoIcons=yes

PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

Compression=lzma
SolidCompression=yes

WizardStyle=modern
WizardImageFile=crystal.bmp
WizardSmallImageFile=crystal_small.bmp
DisableWelcomePage=no

SetupMutex={#MyAppName}SetupMutex

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation"
Name: "minimal"; Description: "Minimal installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "main"; Description: "Crystal compiler"; Types: full minimal custom; Flags: fixed
Name: "shards"; Description: "Shards dependency manager"; Types: full
Name: "pdb"; Description: "Debug symbols"; Types: full
Name: "samples"; Description: "Sample programs"; Types: full
Name: "docs"; Description: "Offline standard library documentation"; Types: full

[Tasks]
Name: addtopath; Description: "Add Crystal's directory to the &PATH environment variable"; Flags: checkedonce
Name: association; Description: "{cm:AssocFileExtension,Crystal,.cr}"; Flags: unchecked

[Files]
Source: "portable\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "portable\lib\*"; DestDir: "{app}\lib"; Flags: ignoreversion; Components: main
Source: "portable\*.dll"; DestDir: "{app}"; Flags: ignoreversion; Components: main
Source: "portable\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: main
Source: "portable\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme; Components: main
Source: "portable\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion; Components: main

Source: "portable\shards.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: shards

Source: "portable\crystal.pdb"; DestDir: "{app}"; Flags: ignoreversion; Components: pdb

Source: "portable\examples\*"; DestDir: "{app}\examples"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: samples

Source: "portable\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: docs

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\crystal\cache"

[Registry]
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}"; ValueType: string; ValueName: "PerceivedType"; ValueData: "text"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue

Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".cr"; ValueData: ""; Flags: uninsdeletekey

[Icons]
Name: "{group}\Crystal Book"; Filename: "https://crystal-lang.org/reference/{#MajorNum}.{#MinorNum}/index.html"
Name: "{group}\Crystal Standard Library API"; Filename: "{app}\docs\index.html"; Components: docs
Name: "{group}\Crystal Standard Library API"; Filename: "https://crystal-lang.org/api/{#MyAppVersion}/index.html"; Components: not docs
Name: "{group}\Official Website"; Filename: "https://crystal-lang.org/"
Name: "{group}\GitHub Repository"; Filename: "https://github.com/crystal-lang/crystal"

[Code]
const CLSID_SetupConfiguration = '{177F0C4A-1CD3-4DE7-A32C-71DBBB9FA36D}';
const Win10SDK64 = 'SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v10.0';
const Win10SDK32 = 'SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0';

type
  ISetupInstance = interface(IUnknown) '{B41463C3-8866-43B5-BC33-2B0676F7F42E}'
    procedure GetInstanceId;
    procedure GetInstallDate;
    procedure GetInstallationName;
    function GetInstallationPath(out installationPath: WideString): HResult;
    procedure GetInstallationVersion;
    procedure GetDisplayName;
    procedure GetDescription;
    procedure ResolvePath;
  end;

  IEnumSetupInstances = interface(IUnknown) '{6380BCFF-41D3-4B2E-8B2E-BF8A6810C848}'
    function Next(celt: DWord; out rgelt: ISetupInstance; out pceltFetched: DWord): HResult;
    procedure Skip;
    procedure Reset;
    procedure Clone;
  end;

  ISetupConfiguration = interface(IUnknown) '{42843719-DB4C-46C2-8E7C-64F1816EFD5B}'
    function EnumInstances(out enumInstances: IEnumSetupInstances): HResult;
  end;

  IClassFactory = interface(IUnknown) '{00000001-0000-0000-C000-000000000046}'
    function CreateInstance(unkOuter: IUnknown; riid: TGUID; out object: IUnknown): HResult;
    procedure LockServer;
  end;

function HasMSVC: Boolean;
var
  config: ISetupConfiguration;
  enumSetup: IEnumSetupInstances;
  count: DWord;
  setup: ISetupInstance;
  setupPath: WideString;
  msvcVersion: AnsiString;
  hresult: HResult;
begin
  result := False;

  try
    config := ISetupConfiguration(CreateComObject(StringToGuid(CLSID_SetupConfiguration)));
  except
    exit;
  end;

  OleCheck(config.EnumInstances(enumSetup));
  While True do
  begin
    hresult := enumSetup.Next(1, setup, count);
    OleCheck(hresult);
    if hresult = 1 then
      Break;
    hresult := setup.GetInstallationPath(setupPath);
    if hresult <> 0 then
      Continue;
    if not LoadStringFromFile(setupPath + '\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt', msvcVersion) then
      Continue;
    if not FileExists(setupPath + '\VC\Tools\MSVC\' + TrimRight(msvcVersion) + '\bin\Hostx64\x64\cl.exe') then
      Continue;
    Log('MSVC location: ' + setupPath + '\VC\Tools\MSVC\' + TrimRight(msvcVersion));
    result := True;
    exit;
  end;
end;

function HasWinSDKAt(const rootKey: Integer; const subKey: String): Boolean;
var
  installationFolder: String;
  productVersion: String;
begin
  result := False;
  if RegQueryStringValue(rootKey, subKey, 'InstallationFolder', installationFolder) then
    if RegQueryStringValue(rootKey, subKey, 'ProductVersion', productVersion) then
      if FileExists(installationFolder + '\Include\' + productVersion + '.0\um\winsdkver.h') then
      begin
        Log('Windows SDK location: ' + installationFolder + '\Lib\' + productVersion);
        result := True;
      end;
end;

function HasWinSDK: Boolean;
begin
  result := HasWinSDKAt(HKEY_LOCAL_MACHINE, Win10SDK64) or
    HasWinSDKAt(HKEY_LOCAL_MACHINE, Win10SDK32) or
    HasWinSDKAt(HKEY_CURRENT_USER, Win10SDK64) or
    HasWinSDKAt(HKEY_CURRENT_USER, Win10SDK32);
end;

function HasVCRedist: Boolean;
var
  regValue: Cardinal;
begin
  result := False;
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', regValue) then
    if regValue <> 0 then
      result := True;
end;

{ Adopted from https://stackoverflow.com/a/46609047 }
procedure EnvAddPath(Path: string; IsSystem: Boolean);
var
  Paths: string;
  Status: Boolean;
begin
  if IsSystem then
    Status := RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Paths)
  else
    Status := RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Paths);

  if not Status then
    Paths := '';

  if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then
    exit;

  Paths := Paths + ';' + Path + ';';

  if IsSystem then
    RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Paths)
  else
    RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Paths);
end;

procedure EnvRemovePath(Path: string; IsSystem: Boolean);
var
  Paths: string;
  Status: Boolean;
  P: Integer;
begin
  if IsSystem then
    Status := RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Paths)
  else
    Status := RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Paths);

  if not Status then
    exit;

  P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
  if P = 0 then
    exit;

  Delete(Paths, P - 1, Length(Path) + 1);

  if IsSystem then
    RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', Paths)
  else
    RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', Paths);
end;

function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#emit SetupSetting("AppId")}_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  result := sUnInstallString;
end;

procedure InitializeWizard;
var
  updatingPage: TOutputMsgWizardPage;
begin
  if GetUninstallString() <> '' then
    updatingPage := CreateOutputMsgPage(
      wpSelectTasks,
      'Pre-Install Checks',
      'A previous Crystal installation already exists.',
      'Setup has detected a previous installation of Crystal; it will be uninstalled before the new version is installed. ' +
      'This ensures that requiring Crystal files will not pick up any leftover files from the previous version.'#13#13 +
      'To use multiple Crystal installations side-by-side, the portable packages for the extra versions must be downloaded manually.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  uninstallString: String;
  exitCode: Integer;
begin
  case CurStep of
  ssInstall:
    begin
      uninstallString := GetUninstallString();
      if uninstallString <> '' then
        if not Exec(RemoveQuotes(uninstallString), '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, exitCode) then
        begin
          SuppressibleMsgBox('Failed to remove the previous Crystal installation. Setup will now exit.', mbCriticalError, MB_OK, IDOK);
          Abort;
        end;
    end;
  ssPostInstall:
    begin
      if (not HasVCRedist) and (IDYES = SuppressibleTaskDialogMsgBox(
        'Install Visual C++ Redistributable',
        'Setup is unable to detect a copy of the Visual C++ 2015 Redistributable (x64) or newer on this machine. ' +
          'The runtime libraries are needed by dynamically linked executables, including the compiler itself. ' +
          'If you select "Agree", the installer will proceed to download: '#13#10#13#10 +
          'https://aka.ms/vs/17/release/vc_redist.x64.exe'#13#10#13#10 +
          'and then run:'#13#10#13#10 +
          'VC_redist.x64.exe /passive /norestart'#13#10#13#10 +
          'Would you like to install the Visual C++ Redistributable now?',
        mbInformation, MB_YESNO, ['Agree', 'Decline'], IDYES, IDYES)) then
      begin
        DownloadTemporaryFile('https://aka.ms/vs/17/release/vc_redist.x64.exe', 'VC_redist.x64.exe', '', nil);
        if not Exec(ExpandConstant('{tmp}\VC_redist.x64.exe'), '/passive /norestart', '', SW_SHOW, ewWaitUntilTerminated, exitCode) then
          SuppressibleMsgBox('Failed to install the Visual C++ Redistributable.', mbError, MB_OK, IDOK);
      end;

      if (not HasMSVC) and (IDYES = SuppressibleTaskDialogMsgBox(
        'Install MSVC Build Tools',
        'Setup is unable to detect a copy of the Build Tools for Visual Studio 2017 or newer on this machine. ' +
          'The MSVC Build Tools are required to link Crystal programs into Windows executables. ' +
          'If you select "Agree", the installer will proceed to download: '#13#10#13#10 +
          'https://aka.ms/vs/17/release/vs_BuildTools.exe'#13#10#13#10 +
          'and then run:'#13#10#13#10 +
          'vs_BuildTools.exe --passive --norestart --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64'#13#10#13#10 +
          'Would you like to install the MSVC Build Tools now? ' +
          'Note that you may modify your installation later using the Visual Studio Installer.',
        mbInformation, MB_YESNO, ['Agree', 'Decline'], IDYES, IDYES)) then
      begin
        DownloadTemporaryFile('https://aka.ms/vs/17/release/vs_BuildTools.exe', 'vs_BuildTools.exe', '', nil);
        if not Exec(
          ExpandConstant('{tmp}\vs_BuildTools.exe'),
          '--passive --norestart --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
          '', SW_SHOW, ewWaitUntilTerminated, exitCode
        ) then
          SuppressibleMsgBox('Failed to install the Build Tools for Visual Studio.', mbError, MB_OK, IDOK);
      end;

      if (not HasWinSDK) and (IDYES = SuppressibleTaskDialogMsgBox(
        'Install Windows SDK',
        'Setup is unable to detect a copy of the Windows 10 SDK or newer on this machine. ' +
          'The Crystal runtime and standard library rely on the Win32 libraries to interface with the Windows system. ' +
          'If you select "Agree", the installer will proceed to download: '#13#10#13#10 +
          'https://aka.ms/vs/17/release/vs_BuildTools.exe'#13#10#13#10 +
          'and then run:'#13#10#13#10 +
          'vs_BuildTools.exe --passive --norestart --wait --add Microsoft.VisualStudio.Component.Windows11SDK.22621'#13#10#13#10 +
          'Would you like to install the Windows SDK now? ' +
          'Note that you may modify your installation later using the Visual Studio Installer.',
        mbInformation, MB_YESNO, ['Agree', 'Decline'], IDYES, IDYES)) then
      begin
        DownloadTemporaryFile('https://aka.ms/vs/17/release/vs_BuildTools.exe', 'vs_BuildTools.exe', '', nil);
        if not Exec(
          ExpandConstant('{tmp}\vs_BuildTools.exe'),
          '--passive --norestart --wait --add Microsoft.VisualStudio.Component.Windows11SDK.22621',
          '', SW_SHOW, ewWaitUntilTerminated, exitCode
        ) then
          SuppressibleMsgBox('Failed to install the Windows SDK.', mbError, MB_OK, IDOK);
      end;

      if WizardIsTaskSelected('addtopath') then
        EnvAddPath(ExpandConstant('{app}'), IsAdminInstallMode());
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}'), IsAdminInstallMode());
end;
