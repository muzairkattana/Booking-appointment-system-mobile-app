@echo off
echo =======================================================
echo Gonstead Chiropractic Clinic - Project Repair & Clean
echo =======================================================
echo.

echo [1/2] Cleaning main app build cache...
call flutter clean
echo.

echo [2/2] Getting main app dependencies...
call flutter pub get
echo.

echo =======================================================
echo Repair & Clean Complete! 🚀
echo.
echo You can now run:
echo   - Main App:  flutter run
echo =======================================================
pause
