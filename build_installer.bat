@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   TokTokAI - Windows Build Script
echo ============================================
echo.

:: ── Step 1: Flutter Release Build ────────────────────────────────
echo [1/3] Flutter build windows --release ...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Flutter build failed.
    pause
    exit /b 1
)
echo [OK] Flutter build complete.
echo.

:: ── Step 2: Check output ─────────────────────────────────────────
set RELEASE_DIR=build\windows\x64\runner\Release
if not exist "%RELEASE_DIR%\tax_invoice.exe" (
    echo [ERROR] Cannot find: %RELEASE_DIR%\tax_invoice.exe
    pause
    exit /b 1
)
echo [OK] Release binary found.
echo.

:: ── Step 3: Find Inno Setup ──────────────────────────────────────
echo [2/3] Looking for Inno Setup ...
set ISCC=

if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    goto FOUND_ISCC
)
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
    goto FOUND_ISCC
)
if exist "C:\Program Files (x86)\Inno Setup 5\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
    goto FOUND_ISCC
)

echo [WARN] Inno Setup not found. Creating ZIP package instead.
echo        To create .exe installer, install Inno Setup from:
echo        https://jrsoftware.org/isdl.php
echo.
goto MAKE_ZIP

:FOUND_ISCC
echo [OK] Inno Setup found: %ISCC%
echo.

:: ── Step 4: Build installer ──────────────────────────────────────
echo [3/3] Building installer ...
if not exist installer_output mkdir installer_output

"%ISCC%" installer.iss
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Inno Setup failed.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   SUCCESS: installer_output\TokTokAI_Setup_1.0.0.exe
echo ============================================
explorer installer_output
pause
exit /b 0

:: ── ZIP fallback ─────────────────────────────────────────────────
:MAKE_ZIP
echo [3/3] Creating ZIP package ...
if not exist installer_output mkdir installer_output

set "ZIP_OUT=installer_output\TokTokAI_v1.0.0_Windows.zip"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%ZIP_OUT%' -Force"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ZIP creation failed.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   SUCCESS: %ZIP_OUT%
echo   Usage: unzip and run tax_invoice_flutter.exe
echo ============================================
explorer installer_output
pause
exit /b 0
