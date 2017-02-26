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

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.WindowManager;
import android.view.KeyEvent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;

import java.io.File;


public class FlickercladdingActivity extends Activity implements SensorEventListener {
    private SensorManager mSensorManager;
    private Sensor mAccelerometer;

    FlickercladdingView mView;

    @Override protected void onCreate(Bundle icicle) {
        super.onCreate(icicle);
        mView = new FlickercladdingView(getApplication(), false, 16, 0);
        setContentView(mView);
        mSensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        mAccelerometer = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
    }

    @Override protected void onPause() {
        super.onPause();
        mView.onPause();
        mSensorManager.unregisterListener(this);
    }

    @Override
    protected void onResume() {
        super.onResume();
        mView.onResume();
        mSensorManager.registerListener(this, mAccelerometer, SensorManager.SENSOR_DELAY_NORMAL);
    }

    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    public void onSensorChanged(SensorEvent event) {
        //Log.w("ACTIV", String.format("sensor %f %f %f\n", event.values[0], event.values[1], event.values[2]));

        // These events are rather slow to update and somewhat annoying. Leave them off for now.
        //FlickercladdingLib.onAccelerometerChange(event.values[0], event.values[1], event.values[2], event.accuracy);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        int keyaction = 1 - event.getAction(); // Down is 0, we want 1
        int keycode = event.getKeyCode();
        int keyunicode = event.getUnicodeChar(event.getMetaState() );
        char character = (char) keyunicode;
        FlickercladdingLib.onKeyEvent(keyunicode, keycode, keyaction, event.getMetaState());
        return super.dispatchKeyEvent(event);
    }
}
