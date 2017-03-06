:: Retrieve data files from Android device using ADB
:: Grab only the shaders/ directory, where edited shaders are stored.

echo off
:: Guess the default installation location
set ANDROID_HOME=%LOCALAPPDATA%\Android
set ANDROID_SDK=%ANDROID_HOME%\sdk
set ADB=%ANDROID_SDK%\platform-tools\adb
::echo %ADB%

set SHADERS_PATH=data/shaders/
set APP_PATH=/sdcard/Android/data/com.android.flickercladding/
set REMOTE_PATH=%APP_PATH%/%SHADERS_PATH%
set LOCAL_PATH=deploy/data/.

%ADB% -d pull %REMOTE_PATH% %LOCAL_PATH%
