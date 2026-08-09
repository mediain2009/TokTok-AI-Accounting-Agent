; ─────────────────────────────────────────────────────────────────────────────
; 톡톡AI,간편회계 – Inno Setup 설치 스크립트
; Inno Setup 6.x (https://jrsoftware.org/isinfo.php) 필요
; ─────────────────────────────────────────────────────────────────────────────

#define AppName      "톡톡AI,간편회계"
#define AppVersion   "1.0.0"
#define AppPublisher "톡톡AI"
#define AppExeName   "tax_invoice.exe"
#define SourceDir    "build\windows\x64\runner\Release"

[Setup]
AppId={{A3F2C1D4-8B6E-4F2A-9C3D-1E7F5A2B4C8D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisherURL=https://github.com
AppSupportURL=https://github.com
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
LicenseFile=
OutputDir=installer_output
OutputBaseFilename=TokTokAI_Setup_{#AppVersion}
SetupIconFile=
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayName={#AppName}
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕화면에 아이콘 만들기"; GroupDescription: "추가 아이콘:"; Flags: unchecked
Name: "startmenu";   Description: "시작 메뉴에 추가";       GroupDescription: "추가 아이콘:"; Flags: checkedonce

[Files]
; 메인 실행파일
Source: "{#SourceDir}\{#AppExeName}";       DestDir: "{app}"; Flags: ignoreversion

; Flutter 런타임 DLL
Source: "{#SourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll";               DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Flutter data 폴더 (assets, fonts, shaders 등)
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; 시작 메뉴
Name: "{group}\{#AppName}";         Filename: "{app}\{#AppExeName}"
Name: "{group}\{#AppName} 제거"; Filename: "{uninstallexe}"

; 바탕화면 (선택 시)
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 앱이 생성한 데이터는 삭제하지 않음 (문서 보존)
Type: filesandordirs; Name: "{app}"

[Code]
// 설치 전 기존 프로세스 종료 확인
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
