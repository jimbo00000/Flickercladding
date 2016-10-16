/*
 * Copyright (C) 2007 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.flickercladding;

// Wrapper for native library

public class FlickercladdingLib {

     static {
         System.loadLibrary("flickercladding");
     }

    public static native void init();
    public static native void surfchanged(int width, int height);
    public static native void step();

    public static native void onSingleTouchEvent(int pointerid, int action, float x, float y);
    public static native void onKeyEvent(int key, int scancode, int action, int mods);
}
