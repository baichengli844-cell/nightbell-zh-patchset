@echo off
rem Build a SIGNED RELEASE APK of the Chinese Nightbell fork.
rem
rem Signing material is never part of this repository. Create
rem keystore\keystore.properties in your clone with:
rem
rem   storeFile=keystore\your-release.jks
rem   storePassword=...
rem   keyAlias=...
rem   keyPassword=...
rem
rem and add the .jks next to it. Both are git-ignored. Keep that key safe: every
rem future update of the same applicationId must be signed with it.
rem
rem Machine paths come from the environment:
rem   JAVA_HOME            JDK 21
rem   ANDROID_HOME         Android SDK (platform 36, build-tools 36.0.0)
rem   GRADLE_USER_HOME     optional
rem   NIGHTBELL_PYTHON     optional, full path to a real python.exe
chcp 65001 >nul
setlocal enabledelayedexpansion

cd /d "%~dp0.."
if not exist "tools\gen_zh.py" (
  echo [ERROR] Project root not found. Run this from nightbell-zh\scripts inside a
  echo         fork checkout, not from the patch-set repository on its own.
  exit /b 1
)

if not defined ANDROID_HOME if defined ANDROID_SDK_ROOT set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
if not defined ANDROID_HOME set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
if not exist "%ANDROID_HOME%\platforms\android-36" (
  echo [ERROR] Android SDK platform 36 not found at "%ANDROID_HOME%".
  exit /b 1
)

if not defined JAVA_HOME (
  for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk-21*") do set "JAVA_HOME=%%~fD"
)
if not defined JAVA_HOME (
  for /d %%D in ("%ProgramFiles%\Java\jdk-21*") do set "JAVA_HOME=%%~fD"
)
if not defined JAVA_HOME (
  echo [ERROR] JDK not found. Set JAVA_HOME to a JDK 21 installation.
  exit /b 1
)
set "PATH=%JAVA_HOME%\bin;%PATH%"

if not exist "keystore\keystore.properties" (
  echo [ERROR] keystore\keystore.properties is missing.
  echo         Without it Gradle produces an UNSIGNED release APK that cannot install.
  exit /b 1
)

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
  echo [ERROR] No usable Python 3 found. Set NIGHTBELL_PYTHON and retry.
  exit /b 1
)

echo [1/3] Generating Zh.kt from tools\zh_*.tsv ...
echo       Python: %PYEXE%
"%PYEXE%" tools\gen_zh.py
if errorlevel 1 exit /b 1

echo [2/3] Building SIGNED RELEASE APK (R8 minify + resource shrink) ...
call gradlew.bat :app:assembleRelease --console=plain
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

echo [3/3] Collecting APK ...
if not exist "app\build\outputs\apk\release\app-release.apk" (
  echo [ERROR] Gradle reported success but app-release.apk is missing.
  echo         Check whether the release signing config was applied.
  exit /b 1
)
if not exist "dist" mkdir dist
copy /y "app\build\outputs\apk\release\app-release.apk" "dist\Nightbell-zh-release.apk" >nul
echo.
echo Done: %CD%\dist\Nightbell-zh-release.apk
echo NOTE: the release package is me.river.nightbell (no .debug suffix), the same
echo       id as the official app. Installing it next to the official build fails
echo       on the signature check - uninstall the official app first.
endlocal
