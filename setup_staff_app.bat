@echo off
echo =======================================================
echo Gonstead Chiropractic Clinic - Staff App Setup Script
echo =======================================================
echo.
echo [1/4] Creating Flutter project gct_staff...
call flutter create --org com.gonsteadchiropractic --project-name gct_staff gct_staff

echo [2/4] Copying Google Services configuration...
if exist android\app\google-services.json (
    if not exist gct_staff\android\app (
        mkdir gct_staff\android\app
    )
    copy android\app\google-services.json gct_staff\android\app\google-services.json /Y
    echo Google Services configuration copied successfully.
) else (
    echo WARNING: android\app\google-services.json not found. You will need to add it manually to enable Firebase.
)

echo [3/4] Copying Staff App source code and assets...
xcopy /E /Y /I staff_app_template gct_staff

echo [4/4] Fetching dependencies...
cd gct_staff
call flutter pub get

echo.
echo =======================================================
echo Staff App Setup Complete! 🚀
echo.
echo To run the Staff App:
echo   cd gct_staff
echo   flutter run
echo =======================================================
pause
