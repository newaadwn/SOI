package com.newdawn.soiapp

import android.content.Context
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class CameraHandler(private val context: Context) {
    companion object {
        private const val TAG = "CameraHandler"
    }
    
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    
    // 카메라 세션 상태
    private var isSessionActive = false
    
    /**
     * 카메라 초기화
     */
    fun initCamera(): Boolean {
        return try {
            Log.d(TAG, "카메라 초기화 시작...")
            
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                try {
                    cameraProvider = cameraProviderFuture.get()
                    setupCameraUseCases()
                    isSessionActive = true
                    Log.d(TAG, "✅ 카메라 초기화 성공")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ 카메라 초기화 실패", e)
                    isSessionActive = false
                }
            }, ContextCompat.getMainExecutor(context))
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ 카메라 초기화 오류", e)
            isSessionActive = false
            false
        }
    }
    
    /**
     * 카메라 Use Cases 설정
     */
    private fun setupCameraUseCases() {
        try {
            // Preview 설정
            preview = Preview.Builder()
                .build()
            
            // ImageCapture 설정
            imageCapture = ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()
            
            // 카메라 선택 (후면 카메라)
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            // 기존 바인딩 해제
            cameraProvider?.unbindAll()
            
            // 새로운 바인딩
            camera = cameraProvider?.bindToLifecycle(
                context as LifecycleOwner,
                cameraSelector,
                preview,
                imageCapture
            )
            
            Log.d(TAG, "✅ 카메라 Use Cases 설정 완료")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 카메라 Use Cases 설정 실패", e)
            throw e
        }
    }
    
    /**
     * 사진 촬영
     */
    fun takePicture(outputDirectory: File): String {
        val imageCapture = this.imageCapture ?: run {
            Log.e(TAG, "❌ ImageCapture가 초기화되지 않음")
            return ""
        }
        
        try {
            // 파일 이름 생성
            val photoFile = File(
                outputDirectory,
                "SOI_${System.currentTimeMillis()}.jpg"
            )
            
            // 출력 옵션 설정
            val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile)
                .build()
            
            Log.d(TAG, "📸 사진 촬영 시작: ${photoFile.name}")
            
            // 동기 방식으로 사진 촬영 (MethodChannel 호환)
            var result = ""
            val countDownLatch = java.util.concurrent.CountDownLatch(1)
            
            imageCapture.takePicture(
                outputOptions,
                cameraExecutor,
                object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                        result = photoFile.absolutePath
                        Log.d(TAG, "✅ 사진 저장 성공: $result")
                        countDownLatch.countDown()
                    }
                    
                    override fun onError(exception: ImageCaptureException) {
                        Log.e(TAG, "❌ 사진 촬영 실패", exception)
                        result = ""
                        countDownLatch.countDown()
                    }
                }
            )
            
            // 결과 대기 (최대 5초)
            countDownLatch.await(5, java.util.concurrent.TimeUnit.SECONDS)
            return result
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 사진 촬영 오류", e)
            return ""
        }
    }
    
    /**
     * 카메라 세션 상태 확인
     */
    fun isSessionActive(): Boolean {
        val active = isSessionActive && cameraProvider != null && camera != null
        Log.d(TAG, "🔍 세션 상태 확인: $active")
        return active
    }
    
    /**
     * 카메라 전환 (전면/후면)
     */
    fun switchCamera(): Boolean {
        return try {
            val currentSelector = if (camera?.cameraInfo?.lensFacing == CameraSelector.LENS_FACING_BACK) {
                CameraSelector.DEFAULT_FRONT_CAMERA
            } else {
                CameraSelector.DEFAULT_BACK_CAMERA
            }
            
            cameraProvider?.unbindAll()
            camera = cameraProvider?.bindToLifecycle(
                context as LifecycleOwner,
                currentSelector,
                preview,
                imageCapture
            )
            
            Log.d(TAG, "✅ 카메라 전환 성공")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ 카메라 전환 실패", e)
            false
        }
    }
    
    /**
     * 카메라 해제
     */
    fun release() {
        try {
            cameraProvider?.unbindAll()
            cameraExecutor.shutdown()
            isSessionActive = false
            Log.d(TAG, "✅ 카메라 리소스 해제 완료")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 카메라 해제 오류", e)
        }
    }
    
    /**
     * 출력 디렉토리 가져오기
     */
    fun getOutputDirectory(): File {
        val mediaDir = context.externalMediaDirs.firstOrNull()?.let {
            File(it, "SOI_Photos").apply { mkdirs() }
        }
        return if (mediaDir != null && mediaDir.exists()) mediaDir else context.filesDir
    }
}
