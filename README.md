Hello GL3
=========
A cross-platform framework for OpenGLES 3 programming.

The string 'GL2' is all over the place in this project, but really it's intended to be GLES 3.1.


Motivation
-----------
Have the same GL code running on both desktop(Windows) and embedded/tablet(Android) platforms to allow the *much* easier development that the Windows/Visual Studio platform provides. Use CMake to free the source from unneeded dependency on IDE or toolchain.


Pre-requisites
--------------
- Python [2.7.10](https://www.python.org/downloads/)

Android:  | Desktop OS:
----------|------------
- [Android Studio 1.4+](http://developer.android.com/sdk/index.html)  | - CMake [2.8 or newer](https://cmake.org/download/)
- [NDK](https://developer.android.com/ndk/) bundle                    | - glfw [32-bit 3.1.2](http://www.glfw.org/download.html)


Setup the Build Machine
-----------------------
See the [System Preparation](doc/SystemPreparation.md) document under doc/.


Build
-----------------------
See the [Build Instructions](doc/BuildInstructions.md) document under doc/.
