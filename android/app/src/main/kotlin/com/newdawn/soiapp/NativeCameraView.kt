package com.newdawn.soiapp

import android.content.Context
import android.util.Log
import android.view.View
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.Lifecycle
import android.os.Handler
import android.os.Looper

class NativeCameraView(
    private val context: Context,
    id: Int,
    creationParams: Any?,
    messenger: BinaryMessenger
) : PlatformView, LifecycleOwner {
    
    private val TAG = "NativeCameraView"
    private val previewView: PreviewView
    private val cameraHandler: CameraHandler
    private val methodChannel: MethodChannel
    private val handler = Handler(Looper.getMainLooper())
    
    // LifecycleOwner 구현을 위한 레지스트리
    private val lifecycleRegistry = LifecycleRegistry(this)
    
    // LifecycleOwner 인터페이스 구현
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    
    init {
        Log.i(TAG, "NativeCameraView 초기화 시작: $id")
        
        // LifecycleRegistry를 활성 상태로 설정
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        
        // PreviewView 초기화 - 설정 개선
        previewView = PreviewView(context).apply {
            Log.d(TAG, "PreviewView 생성")
            
            // 성능 최적화 모드 (PERFORMANCE는 프레임 드롭이 적음)
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            Log.d(TAG, "PreviewView 구현 모드: COMPATIBLE")
            
            // 화면 비율 설정 (FILL_CENTER로 변경하여 화면에 맞게 조정)
            scaleType = PreviewView.ScaleType.FILL_CENTER
            Log.d(TAG, "PreviewView 스케일 타입: FILL_CENTER")
            
            // 초기 크기를 명시적으로 설정하여 1x1 문제 해결
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
            Log.d(TAG, "PreviewView 레이아웃 파라미터 설정: MATCH_PARENT x MATCH_PARENT")
        }
        
        // 카메라 핸들러 초기화 - this를 LifecycleOwner로 전달
        Log.d(TAG, "CameraHandler 초기화 시작")
        cameraHandler = CameraHandler(this)
        Log.d(TAG, "CameraHandler 초기화 완료")
        
        // 메서드 채널 설정
        methodChannel = MethodChannel(messenger, "com.soi.camera/preview_$id")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initCamera" -> {
                    initCamera(result)
                }
                "isSessionActive" -> {
                    result.success(cameraHandler.isSessionActive())
                }
                "refreshPreview" -> {
                    refreshPreview()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 카메라 초기화를 약간 지연시켜 안정성 향상
        handler.postDelayed({
            Log.d(TAG, "지연된 카메라 초기화 시작")
            
            // SurfaceProvider 설정 확인
            if (previewView.surfaceProvider == null) {
                Log.e(TAG, "SurfaceProvider가 null입니다. 이는 비정상적인 상태입니다.")
            }
            
            initCamera(null)
        }, 500) // 500ms 지연
        
        Log.i(TAG, "안드로이드 카메라 뷰 생성됨: $id")
    }
    
    private fun initCamera(result: MethodChannel.Result?) {
        Log.d(TAG, "initCamera 호출됨")
        
        try {
            // 미리 SurfaceProvider 설정
            Log.d(TAG, "SurfaceProvider 설정 시도")
            val surfaceProvider = previewView.surfaceProvider
            if (surfaceProvider == null) {
                Log.e(TAG, "SurfaceProvider가 null입니다. 카메라를 초기화할 수 없습니다.")
                result?.error("CAMERA_INIT_ERROR", "SurfaceProvider가 null입니다", null)
                return
            }
            
            // SurfaceProvider 설정
            cameraHandler.setSurfaceProvider(surfaceProvider)
            
            // PreviewView가 화면에 그려진 후 카메라 초기화
            cameraHandler.initCamera { success, error ->
                if (success) {
                    Log.d(TAG, "카메라 초기화 성공")
                    
                    // 프리뷰 강제 갱신
                    handler.post {
                        refreshPreview()
                    }
                    
                    Log.d(TAG, "카메라 최적화 완료")
                    result?.success(true)
                } else {
                    Log.e(TAG, "카메라 초기화 실패: $error")
                    result?.error("CAMERA_INIT_ERROR", error, null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "카메라 초기화 중 예외 발생: ${e.message}")
            result?.error("CAMERA_INIT_EXCEPTION", e.message, null)
        }
    }
    
    // 프리뷰 강제 갱신 메서드
    private fun refreshPreview() {
        try {
            Log.d(TAG, "프리뷰 갱신 시작")
            
            // 프리뷰 뷰 강제 갱신
            previewView.invalidate()
            
            // 레이아웃 갱신 요청
            previewView.requestLayout()
            
            // 추가 갱신 시도
            handler.postDelayed({
                previewView.invalidate()
            }, 100)
            
            Log.d(TAG, "프리뷰 강제 갱신 완료")
        } catch (e: Exception) {
            Log.e(TAG, "프리뷰 갱신 중 오류: ${e.message}")
        }
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        Log.d(TAG, "NativeCameraView dispose 호출됨")
        
        try {
            // 생명주기 이벤트 처리
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
            lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
            
            // 메서드 채널 정리
            methodChannel.setMethodCallHandler(null)
            
            // 카메라 리소스 정리
            cameraHandler.disposeCamera()
            
            // 핸들러 콜백 제거
            handler.removeCallbacksAndMessages(null)
            
            Log.d(TAG, "NativeCameraView 리소스 정리 완료")
        } catch (e: Exception) {
            Log.e(TAG, "NativeCameraView dispose 중 오류: ${e.message}")
        }
    }
}
