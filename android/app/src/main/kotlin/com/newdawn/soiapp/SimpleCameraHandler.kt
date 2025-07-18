package com.newdawn.soiapp

import android.content.Context
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class SimpleCameraHandler(private val context: Context) {
    private val TAG = "SimpleCameraHandler"
    
    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    
    fun initCamera(callback: (Boolean, String?) -> Unit) {
        Log.d(TAG, "카메라 초기화 시작")
        
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            
            cameraProviderFuture.addListener({
                try {
                    cameraProvider = cameraProviderFuture.get()
                    Log.d(TAG, "CameraProvider 획득 성공")
                    
                    // 카메라 선택 (후면 카메라)
                    val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                    
                    // Preview 설정
                    preview = Preview.Builder().build()
                    
                    // ImageCapture 설정
                    imageCapture = ImageCapture.Builder()
                        .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                        .build()
                    
                    // 기존 바인딩 해제
                    cameraProvider?.unbindAll()
                    
                    // 카메라 바인딩
                    camera = cameraProvider?.bindToLifecycle(
                        ProcessLifecycleOwner.get(),
                        cameraSelector,
                        preview,
                        imageCapture
                    )
                    
                    Log.d(TAG, "카메라 초기화 완료")
                    callback(true, null)
                    
                } catch (e: Exception) {
                    Log.e(TAG, "카메라 초기화 실패: ${e.message}", e)
                    callback(false, e.message)
                }
            }, ContextCompat.getMainExecutor(context))
            
        } catch (e: Exception) {
            Log.e(TAG, "카메라 초기화 실패: ${e.message}", e)
            callback(false, e.message)
        }
    }
    
    fun setSurfaceProvider(surfaceProvider: Preview.SurfaceProvider) {
        Log.d(TAG, "SurfaceProvider 설정")
        preview?.setSurfaceProvider(surfaceProvider)
    }
    
    fun takePicture(callback: (String?, String?) -> Unit) {
        val imageCapture = imageCapture ?: run {
            callback(null, "ImageCapture가 초기화되지 않았습니다.")
            return
        }
        
        val photoFile = File(
            context.externalCacheDir,
            SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())
                .format(System.currentTimeMillis()) + ".jpg"
        )
        
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    Log.d(TAG, "사진 저장 성공: ${photoFile.absolutePath}")
                    callback(photoFile.absolutePath, null)
                }
                
                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "사진 촬영 실패: ${exception.message}", exception)
                    callback(null, exception.message)
                }
            }
        )
    }
    
    fun switchCamera() {
        Log.d(TAG, "카메라 전환")
        // 간단한 구현을 위해 현재는 후면 카메라만 사용
    }
    
    fun setFlash(isOn: Boolean) {
        Log.d(TAG, "플래시 설정: $isOn")
        // 간단한 구현을 위해 현재는 플래시 기능 생략
    }
    
    fun dispose() {
        Log.d(TAG, "카메라 리소스 해제")
        cameraProvider?.unbindAll()
    }
}