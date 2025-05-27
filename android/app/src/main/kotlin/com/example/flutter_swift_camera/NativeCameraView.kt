package com.example.flutter_swift_camera

import android.content.Context
import android.graphics.SurfaceTexture
import android.util.Log
import android.view.Surface
import android.view.TextureView
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class NativeCameraView(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Int
) : PlatformView, TextureView.SurfaceTextureListener {
    
    private val textureView: TextureView = TextureView(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "com.soi.camera/preview_$id")
    private var surfaceTexture: SurfaceTexture? = null
    private var surface: Surface? = null
    
    init {
        // 텍스처뷰 설정
        textureView.surfaceTextureListener = this
        
        // 메서드 채널 설정
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSurfaceSize" -> {
                    val width = call.argument<Int>("width") ?: 1280
                    val height = call.argument<Int>("height") ?: 720
                    setSurfaceSize(width, height)
                    result.success(true)
                }
                "getSurfaceTexture" -> {
                    val texture = surfaceTexture
                    if (texture != null) {
                        result.success(true)
                    } else {
                        result.error("TEXTURE_UNAVAILABLE", "서페이스 텍스처가 준비되지 않았습니다", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // 서페이스 크기 설정
    private fun setSurfaceSize(width: Int, height: Int) {
        surfaceTexture?.setDefaultBufferSize(width, height)
    }
    
    // 서페이스 텍스처가 생성될 때
    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
        Log.d("NativeCameraView", "서페이스 텍스처 생성됨: $width x $height")
        surfaceTexture = texture
        surfaceTexture?.setDefaultBufferSize(width, height)
        surface = Surface(texture)
        
        // Flutter로 이벤트 전송
        methodChannel.invokeMethod("onSurfaceTextureAvailable", mapOf(
            "width" to width,
            "height" to height
        ))
    }
    
    // 서페이스 텍스처 크기가 변경될 때
    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {
        Log.d("NativeCameraView", "서페이스 텍스처 크기 변경: $width x $height")
        surfaceTexture?.setDefaultBufferSize(width, height)
        
        // Flutter로 이벤트 전송
        methodChannel.invokeMethod("onSurfaceTextureSizeChanged", mapOf(
            "width" to width,
            "height" to height
        ))
    }
    
    // 서페이스 텍스처가 소멸될 때
    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
        Log.d("NativeCameraView", "서페이스 텍스처 소멸")
        surfaceTexture = null
        surface?.release()
        surface = null
        
        // Flutter로 이벤트 전송
        methodChannel.invokeMethod("onSurfaceTextureDestroyed", null)
        return true
    }
    
    // 서페이스 텍스처가 업데이트될 때
    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {
        // 프레임 업데이트마다 호출되므로 로그는 출력하지 않음
    }
    
    // PlatformView 인터페이스 구현
    override fun getView(): View {
        return textureView
    }
    
    override fun dispose() {
        Log.d("NativeCameraView", "dispose() 호출됨")
        surface?.release()
        surface = null
        surfaceTexture = null
    }
} 