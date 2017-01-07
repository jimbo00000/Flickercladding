:: Deploy data files to Android device using ADB

echo off
:: Guess the default installation location
set ANDROID_HOME=%LOCALAPPDATA%\Android
set ANDROID_SDK=%ANDROID_HOME%\sdk
set ADB=%ANDROID_SDK%\platform-tools\adb
::echo %ADB%

set SOURCE_PATH=deploy/.
set DESTINATION_PATH=/sdcard/Android/data/com.android.flickercladding/

%ADB% -d push %SOURCE_PATH% %DESTINATION_PATH%
