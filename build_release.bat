@echo off
setlocal

cd /d "%~dp0"

echo [1/2] Cleaning previous build artifacts...
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist

echo [2/2] Building FlashCapsule with PyInstaller...
pyinstaller --noconfirm --clean flash_capsule.spec

if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

if not exist "dist\FlashCapsule\_internal\vosk\libvosk.dll" (
  if not exist "dist\FlashCapsule\vosk\libvosk.dll" (
    echo WARNING: libvosk.dll not found in dist output.
  )
)

if not exist "dist\FlashCapsule\vosk\vosk-model-small-cn-0.22" (
  echo WARNING: Vosk model directory not found in dist output.
)

echo Build succeeded. Output: dist\FlashCapsule\FlashCapsule.exe
exit /b 0
