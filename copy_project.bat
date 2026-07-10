@echo off
echo =======================================================
echo Gonstead Chiropractic Clinic - Copy Project to E:\GCT
echo =======================================================
echo.

set SOURCE_DIR=c:\Users\Lenovo\StudioProjects\gct
set DEST_DIR=E:\GCT

echo Source: %SOURCE_DIR%
echo Destination: %DEST_DIR%
echo.

:: Check if destination directory exists, if not create it
if not exist "%DEST_DIR%" (
    echo Creating destination directory: %DEST_DIR%
    mkdir "%DEST_DIR%"
)

echo.
echo Copying files using robocopy...
echo (Excluding large build cache directories like .dart_tool and build to save space and speed up the copy)
echo.

robocopy "%SOURCE_DIR%" "%DEST_DIR%" /E /XD .dart_tool build /R:3 /W:5

echo.
echo =======================================================
echo Copy Complete! 🚀
echo Please check %DEST_DIR% to verify your files are there.
echo.
echo Next steps:
echo 1. Open the project at the new location: E:\GCT
echo 2. Run "flutter pub get" to restore packages and build dependencies.
echo =======================================================
pause
