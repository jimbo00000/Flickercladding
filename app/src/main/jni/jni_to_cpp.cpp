// jni_to_cpp.cpp
// An interface from JNI to C++ code

#include <jni.h>

#include "cpp_interface.h"

void initGL() {
    initScene();
}

void surfChanged(int w, int h) {
    surfaceChangedScene(w, h);
}

void renderFrame() {
    drawScene();
}

void singleTouch(int pointerid, int action, float x, float y) {
    onSingleTouchEvent(pointerid, action, x, y);
}

void keyEvent(int key, int codes, int action, int mods)
{
    onKeyEvent(key, codes, action, mods);
}

extern "C" {
    JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_init(JNIEnv * env, jobject obj);
    JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_surfchanged(JNIEnv * env, jobject obj,  jint width, jint height);
    JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_step(JNIEnv * env, jobject obj);
    JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_onSingleTouchEvent(JNIEnv * env, jobject obj, jint pointerid, jint action, jfloat x, jfloat y);
    JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_onKeyEvent(JNIEnv * env, jobject obj, jint key, jint scancode, jint action, jint mods);
};

JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_init(JNIEnv * env, jobject obj)
{
    initGL();
}

JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_surfchanged(JNIEnv * env, jobject obj,  jint width, jint height)
{
    surfChanged(width, height);
}

JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_step(JNIEnv * env, jobject obj)
{
    renderFrame();
}

JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_onSingleTouchEvent(JNIEnv * env, jobject obj, jint pointerid, jint action, jfloat x, jfloat y)
{
    singleTouch(pointerid, action, x, y);
}

JNIEXPORT void JNICALL Java_com_android_flickercladding_FlickercladdingLib_onKeyEvent(JNIEnv * env, jobject obj, jint key, jint scancode, jint action, jint mods)
{
    keyEvent(key, scancode, action, mods);
}
