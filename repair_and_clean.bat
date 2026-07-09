@echo off
echo =======================================================
echo Gonstead Chiropractic Clinic - Project Repair & Clean
echo =======================================================
echo.

echo [1/3] Cleaning main app build cache...
call flutter clean
echo.

echo [2/3] Cleaning Android Gradle build cache...
cd android
call gradlew clean
cd ..
echo.

echo [3/3] Getting main app dependencies...
call flutter pub get
echo.

echo =======================================================
echo Repair & Clean Complete! 🚀
echo.
echo WARNING: If you see "not enough space on the disk (errno = 112)",
echo please free up at least 3-5 GB on your C: drive.
echo.
echo Quick tips to free space on Windows:
echo   1. Run: Disk Cleanup (cleanmgr.exe)
echo   2. Delete temp files from: C:\Users\Lenovo\AppData\Local\Temp
echo   3. Stop stale Gradle processes: cd android && gradlew --stop
echo =======================================================
pause
