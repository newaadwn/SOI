package com.newdawn.soiapp

import android.content.Context
import android.util.Log
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class SimpleNativeCameraView(
    private val context: Context,
    id: Int,
    creationParams: Any?,
    messenger: BinaryMessenger
) : PlatformView {
    
    private val TAG = "SimpleNativeCameraView"
    private val previewView: PreviewView
    private val cameraHandler: SimpleCameraHandler
    private val methodChannel: MethodChannel
    
    init {
        Log.i(TAG, "SimpleNativeCameraView 초기화 시작: $id")
        
        // PreviewView 초기화
        previewView = PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.PERFORMANCE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
        
        // 카메라 핸들러 초기화
        cameraHandler = SimpleCameraHandler(context)
        
        // 메서드 채널 설정
        methodChannel = MethodChannel(messenger, "com.soi.camera/simple_$id")
        
        // 카메라 초기화
        initCamera()
        
        Log.i(TAG, "SimpleNativeCameraView 생성 완료: $id")
    }
    
    private fun initCamera() {
        Log.d(TAG, "카메라 초기화 시작")
        
        cameraHandler.initCamera { success, error ->
            if (success) {
                Log.d(TAG, "카메라 초기화 성공")
                cameraHandler.setSurfaceProvider(previewView.surfaceProvider)
                Log.d(TAG, "SurfaceProvider 설정 완료")
            } else {
                Log.e(TAG, "카메라 초기화 실패: $error")
            }
        }
    }
    
    override fun getView(): View {
        return previewView
    }
    
    override fun dispose() {
        Log.d(TAG, "리소스 정리")
        cameraHandler.dispose()
        methodChannel.setMethodCallHandler(null)
    }
}