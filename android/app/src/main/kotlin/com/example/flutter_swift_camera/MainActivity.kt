package com.example.flutter_swift_camera

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // AudioConverter 플러그인 등록
        flutterEngine.plugins.add(AudioConverter())
    }
}
