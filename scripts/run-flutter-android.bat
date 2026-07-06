@echo off
setlocal

set "GRADLE_USER_HOME=E:\.gradle"
if not exist "E:\.gradle" mkdir "E:\.gradle"
if not exist "E:\temp" mkdir "E:\temp"

set "TEMP=E:\temp"
set "TMP=E:\temp"
set "ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"

set "FLUTTER_BIN=E:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER_BIN%" (
    echo Flutter SDK not found at %FLUTTER_BIN%
    exit /b 1
)

call "%FLUTTER_BIN%" %*
exit /b %ERRORLEVEL%
