@echo off
chcp 65001 >nul
title Flutter 세금계산서 앱 셋업

echo ============================================
echo   Flutter 세금계산서 관리 앱 셋업
echo ============================================
echo.

:: Flutter 확인
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [오류] Flutter가 설치되어 있지 않거나 PATH에 없습니다.
    echo.
    echo  설치 방법:
    echo  1. https://docs.flutter.dev/get-started/install/windows 접속
    echo  2. Flutter SDK 다운로드 후 C:\flutter 에 압축 해제
    echo  3. 시스템 환경변수 PATH에 C:\flutter\bin 추가
    echo  4. 새 터미널 창에서 이 파일 다시 실행
    pause
    exit /b 1
)

echo [1/4] Windows 데스크탑 지원 활성화...
flutter config --enable-windows-desktop >nul 2>&1

echo [2/4] Flutter 프로젝트 생성 중...
set PROJ_DIR=%~dp0tax_invoice_app
if exist "%PROJ_DIR%" (
    echo  - 기존 프로젝트 폴더 발견, 건너뜀
) else (
    flutter create --platforms=windows --org com.taxinvoice tax_invoice_app
)

echo [3/4] 소스 파일 복사 중...
xcopy /E /Y /I "%~dp0lib" "%PROJ_DIR%\lib\" >nul
copy /Y "%~dp0pubspec.yaml" "%PROJ_DIR%\pubspec.yaml" >nul

echo [4/4] 패키지 설치 중...
cd "%PROJ_DIR%"
flutter pub get

echo.
echo ============================================
echo   셋업 완료!
echo ============================================
echo.
echo  실행하려면:
echo    cd tax_invoice_app
echo    flutter run -d windows
echo.
echo  배포용 빌드:
echo    flutter build windows
echo    실행파일: build\windows\x64\runner\Release\tax_invoice.exe
echo.
pause
