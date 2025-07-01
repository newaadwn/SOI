package com.newdawn.soiapp

import android.content.Context
import android.view.View
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.common.BinaryMessenger

class NativeCameraView(
    context: Context,
    id: Int,
    creationParams: Any?,
    messenger: BinaryMessenger
) : PlatformView {
    
    private val textView: TextView = TextView(context)
    
    init {
        textView.text = "Camera Preview"
        textView.textSize = 20f
    }

    override fun getView(): View {
        return textView
    }

    override fun dispose() {
        // Clean up resources
    }
}
