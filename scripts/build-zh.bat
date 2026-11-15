@echo off
rem Build the Chinese Nightbell DEBUG APK from a full checkout of the fork.
rem
rem This script belongs to the nightbell-zh patch set, so it expects the upstream
rem tree plus the patch applied. See README.md, section "Applying the patch".
rem
rem IMPORTANT: keep this file ASCII-only and CRLF. cmd.exe mis-parses UTF-8
rem comments and LF-only batch files, which silently breaks "cd" and every path.
rem
rem Machine paths come from the environment; nothing is hardcoded.
rem   JAVA_HOME        JDK 21 (Gradle 8.13 refuses JDK 25, which Studio bundles)
rem   ANDROID_HOME     Android SDK with platform 36 / build-tools 36.0.0
rem   GRADLE_USER_HOME optional, defaults to %USERPROFILE%\.gradle
rem   NIGHTBELL_PYTHON optional, full path to a real python.exe
chcp 65001 >nul
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if not exist "tools\gen_zh.py" (
  echo [ERROR] Project root not found. Run this from nightbell-zh\scripts inside a
  echo         fork checkout, not from the patch-set repository on its own.
  exit /b 1
)

rem ---- Android SDK ----------------------------------------------------------
if not defined ANDROID_HOME if defined ANDROID_SDK_ROOT set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
if not defined ANDROID_HOME set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
if not exist "%ANDROID_HOME%\platforms\android-36" (
  echo [ERROR] Android SDK platform 36 not found at "%ANDROID_HOME%".
  echo         Install it, or set ANDROID_HOME to the right directory.
  exit /b 1
)

rem ---- JDK 21 --------------------------------------------------------------
if not defined JAVA_HOME (
  for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk-21*") do set "JAVA_HOME=%%~fD"
)
if not defined JAVA_HOME (
  for /d %%D in ("%ProgramFiles%\Java\jdk-21*") do set "JAVA_HOME=%%~fD"
)
if not defined JAVA_HOME if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" (
  echo [WARN] No JDK 21 found, falling back to the Android Studio bundled JBR.
  echo        Gradle 8.13 fails on JBR 25; install a JDK 21 if the build errors out.
  set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
)
if not defined JAVA_HOME (
  echo [ERROR] JDK not found. Set JAVA_HOME to a JDK 21 installation.
  exit /b 1
)
set "PATH=%JAVA_HOME%\bin;%PATH%"

rem ---- Python 3, used to regenerate ui\i18n\Zh.kt from tools\zh_*.tsv ---------
rem The WindowsApps python.exe is a Microsoft Store stub: it exits 9009 and
rem prints nothing, so every candidate is probed with "import sys".
set "PYEXE="
if defined NIGHTBELL_PYTHON if exist "%NIGHTBELL_PYTHON%" set "PYEXE=%NIGHTBELL_PYTHON%"
if not defined PYEXE (
  for /f "delims=" %%P in ('where python 2^>nul') do (
    if not defined PYEXE (
      "%%~P" -c "import sys" >nul 2>nul
      if not errorlevel 1 set "PYEXE=%%~P"
    )
  )
)
if not defined PYEXE (
  for /f "delims=" %%P in ('where python3 2^>nul') do (
    if not defined PYEXE (
      "%%~P" -c "import sys" >nul 2>nul
      if not errorlevel 1 set "PYEXE=%%~P"
    )
  )
)
if not defined PYEXE (
  echo [ERROR] No usable Python 3 found.
  echo         Set NIGHTBELL_PYTHON to the full path of a real python.exe.
  exit /b 1
)

echo [1/3] Generating Zh.kt from tools\zh_*.tsv ...
echo       Python: %PYEXE%
"%PYEXE%" tools\gen_zh.py
if errorlevel 1 exit /b 1

echo [2/3] Building debug APK ...
call gradlew.bat :app:assembleDebug --console=plain
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

echo [3/3] Collecting APK ...
if not exist "app\build\outputs\apk\debug\app-debug.apk" (
  echo [ERROR] Gradle reported success but app-debug.apk is missing.
  exit /b 1
)
if not exist "dist" mkdir dist
copy /y "app\build\outputs\apk\debug\app-debug.apk" "dist\Nightbell-zh.apk" >nul
echo.
echo Done: %CD%\dist\Nightbell-zh.apk
echo NOTE: debug builds use applicationId me.river.nightbell.debug, so this APK
echo       installs alongside the official release - no uninstall needed.
endlocal
