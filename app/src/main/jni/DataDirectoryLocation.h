// DataDirectoryLocation.h

#ifdef __ANDROID__
	// Apps under Android API 23(Marshmallow) are only allowed to read/write to
	// their named package directory. Make sure the directory name here matches
	// the package name in AndroidManifest.xml and all over the Android Studio project.
	#define APP_DATA_DIRECTORY "/sdcard/Android/data/com.android.flickercladding/"
#endif
// Desktop version has the APP_DATA_DIRECTORY define set by CMake.
