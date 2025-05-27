package com.example.flutter_swift_camera

import io.flutter.app.FlutterApplication
import androidx.multidex.MultiDex
import android.content.Context

class FlutterSwiftCameraApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
} 