# android_build.sh
# Use this script to build LuaJIT for Android:
# Run it from the LuaJIT direcory.

# http://luajit.org/install.html
# https://gist.github.com/zhaozg/52734577acc996544ef6970b688ab874

# Android/ARM, armeabi-v7a (ARMv7 VFP), Android 4.0+ (ICS)
NDK=~/Android/Sdk/ndk-bundle/
NDKABI=23
NDKVER=$NDK/toolchains/arm-linux-androideabi-4.9
NDKP=$NDKVER/prebuilt/linux-x86_64/bin/arm-linux-androideabi-
NDKF="--sysroot $NDK/platforms/android-$NDKABI/arch-arm"
NDKARCH="-march=armv7-a -mfloat-abi=softfp -Wl,--fix-cortex-a8"
make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_FLAGS="$NDKF $NDKARCH"
