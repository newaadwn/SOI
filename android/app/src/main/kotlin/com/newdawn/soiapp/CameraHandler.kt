package com.newdawn.soiapp

import android.content.Context
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import android.net.Uri
import java.util.concurrent.Executor
import android.view.Surface
import android.view.WindowManager

class CameraHandler(private val lifecycleOwner: LifecycleOwner) {
    private val TAG = "CameraHandler"
    
    // Context 변수 추가
    private val context = lifecycleOwner as? Context ?: throw IllegalArgumentException("LifecycleOwner must also be a Context")
    
    // 카메라 관련 변수
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageCapture: ImageCapture? = null
    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainExecutor: Executor = ContextCompat.getMainExecutor(context)
    
    // 카메라 설정 관련 변수
    private var lensFacing = CameraSelector.LENS_FACING_BACK
    private var flashMode = ImageCapture.FLASH_MODE_OFF
    
    // 세션 상태 관리
    private var isSessionActive = false
    private var surfaceProvider: Preview.SurfaceProvider? = null
    
    // 카메라 초기화
    fun initCamera(callback: (Boolean, String?) -> Unit) {
        Log.d(TAG, "initCamera 시작")
        
        try {
            // 화면 회전 방지 설정
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val rotation = windowManager.defaultDisplay.rotation
            Log.d(TAG, "현재 화면 회전: $rotation")
            
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            Log.d(TAG, "ProcessCameraProvider 인스턴스 요청")
            
            cameraProviderFuture.addListener({
                try {
                    // 기존 바인딩 해제
                    cameraProvider?.unbindAll()
                    isSessionActive = false
                    
                    // 카메라 제공자 가져오기
                    cameraProvider = cameraProviderFuture.get()
                    Log.d(TAG, "CameraProvider 획득 성공")
                    
                    // 카메라 설정
                    val cameraSelector = CameraSelector.Builder()
                        .requireLensFacing(lensFacing)
                        .build()
                    Log.d(TAG, "카메라 선택기 설정 완료: ${if (lensFacing == CameraSelector.LENS_FACING_BACK) "후면" else "전면"}")
                    
                    // 미리보기 설정 - 중요: 새 인스턴스 생성
                    preview = Preview.Builder()
                        .setTargetRotation(rotation)
                        .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                        .build()
                    Log.d(TAG, "미리보기 설정 완료")
                    
                    // 이미지 캡처 설정 - 지연 모드로 설정하여 프리뷰 중단 방지
                    imageCapture = ImageCapture.Builder()
                        .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                        .setTargetRotation(rotation)
                        .setFlashMode(flashMode)
                        .build()
                    Log.d(TAG, "이미지 캡처 설정 완료")
                    
                    // 저장된 SurfaceProvider가 있으면 설정
                    if (surfaceProvider != null) {
                        Log.d(TAG, "저장된 SurfaceProvider 설정 시작")
                        preview?.setSurfaceProvider(null) // 기존 연결 해제
                        preview?.setSurfaceProvider(surfaceProvider)
                        Log.d(TAG, "SurfaceProvider 설정 완료")
                    } else {
                        Log.e(TAG, "SurfaceProvider가 null입니다. 프리뷰를 표시할 수 없습니다.")
                        callback(false, "SurfaceProvider가 null입니다.")
                        return@addListener
                    }
                    
                    // 카메라를 LifecycleOwner에 바인딩
                    try {
                        // 먼저 미리보기만 바인딩하여 프리뷰가 제대로 표시되는지 확인
                        camera = cameraProvider?.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview
                        )
                        Log.d(TAG, "카메라 미리보기 바인딩 성공")
                        
                        // 이미지 캡처 추가
                        camera = cameraProvider?.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview,
                            imageCapture
                        )
                        Log.d(TAG, "카메라 이미지 캡처 바인딩 성공")
                        
                        // 자동 초점 설정
                        camera?.cameraControl?.enableTorch(flashMode == ImageCapture.FLASH_MODE_ON)
                        
                        isSessionActive = true
                        Log.d(TAG, "카메라 초기화 완료 (LifecycleOwner 사용)")
                        callback(true, null)
                    } catch (e: Exception) {
                        Log.e(TAG, "카메라 바인딩 실패: ${e.message}", e)
                        callback(false, "카메라 바인딩 실패: ${e.message}")
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "카메라 초기화 실패: ${e.message}", e)
                    callback(false, e.message)
                }
            }, mainExecutor)
            
        } catch (e: Exception) {
            Log.e(TAG, "카메라 초기화 실패: ${e.message}", e)
            callback(false, e.message)
        }
    }
    
    // 사진 촬영
    fun takePicture(callback: (String?, String?) -> Unit) {
        val imageCapture = imageCapture ?: run {
            Log.e(TAG, "ImageCapture이 초기화되지 않았습니다.")
            callback(null, "카메라가 초기화되지 않았습니다.")
            return
        }
        
        // 저장할 파일 생성
        val photoFile = File(
            context.externalCacheDir,
            SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())
                .format(System.currentTimeMillis()) + ".jpg"
        )
        
        // 출력 옵션 설정
        val outputOptions = ImageCapture.OutputFileOptions.Builder(photoFile).build()
        
        // 사진 촬영
        imageCapture.takePicture(
            outputOptions,
            mainExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    val savedUri = outputFileResults.savedUri ?: Uri.fromFile(photoFile)
                    Log.d(TAG, "사진 저장 성공: $savedUri")
                    callback(photoFile.absolutePath, null)
                }
                
                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "사진 촬영 실패: ${exception.message}", exception)
                    callback(null, exception.message)
                }
            }
        )
    }
    
    // 카메라 전환 (전면/후면)
    fun switchCamera(callback: (Boolean, String?) -> Unit) {
        try {
            lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK) {
                CameraSelector.LENS_FACING_FRONT
            } else {
                CameraSelector.LENS_FACING_BACK
            }
            
            // 카메라 다시 초기화
            initCamera(callback)
            
        } catch (e: Exception) {
            Log.e(TAG, "카메라 전환 실패: ${e.message}", e)
            callback(false, e.message)
        }
    }
    
    // 플래시 설정
    fun setFlash(isOn: Boolean, callback: (Boolean, String?) -> Unit) {
        try {
            flashMode = if (isOn) {
                ImageCapture.FLASH_MODE_ON
            } else {
                ImageCapture.FLASH_MODE_OFF
            }
            
            imageCapture?.flashMode = flashMode
            camera?.cameraControl?.enableTorch(isOn)
            
            callback(true, null)
            
        } catch (e: Exception) {
            Log.e(TAG, "플래시 설정 실패: ${e.message}", e)
            callback(false, e.message)
        }
    }
    
    // 카메라 일시 중지
    fun pauseCamera() {
        try {
            if (isSessionActive) {
                cameraProvider?.unbindAll()
                isSessionActive = false
                Log.d(TAG, "카메라 세션 일시 중지")
            }
        } catch (e: Exception) {
            Log.e(TAG, "카메라 일시 중지 실패: ${e.message}", e)
        }
    }
    
    // 카메라 재개
    fun resumeCamera() {
        try {
            if (!isSessionActive) {
                initCamera { success, error ->
                    if (success) {
                        Log.d(TAG, "카메라 세션 재개")
                    } else {
                        Log.e(TAG, "카메라 세션 재개 실패: $error")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "카메라 재개 실패: ${e.message}", e)
        }
    }
    
    // 카메라 리소스 해제
    fun disposeCamera() {
        try {
            cameraProvider?.unbindAll()
            cameraExecutor.shutdown()
            isSessionActive = false
            surfaceProvider = null
            Log.d(TAG, "카메라 리소스 해제 완료")
        } catch (e: Exception) {
            Log.e(TAG, "카메라 리소스 해제 실패: ${e.message}", e)
        }
    }
    
    // 카메라 최적화 설정
    fun optimizeCamera(autoFocus: Boolean, highQuality: Boolean, stabilization: Boolean) {
        try {
            Log.d(TAG, "카메라 최적화 설정 시작")
            
            // 카메라가 이미 초기화되어 있는지 확인
            if (!isSessionActive) {
                Log.w(TAG, "카메라가 아직 초기화되지 않았습니다. 최적화를 건너뜁니다.")
                return
            }
            
            // 현재 카메라 바인딩 해제
            cameraProvider?.unbindAll()
            
            // 이미지 캡처 설정 업데이트
            val builder = ImageCapture.Builder()
                .setFlashMode(flashMode)
            
            // 자동 초점 설정
            if (autoFocus) {
                builder.setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            } else {
                builder.setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
            }
            
            // 고품질 설정
            if (highQuality) {
                builder.setJpegQuality(95)
            }
            
            imageCapture = builder.build()
            
            // 카메라 다시 초기화 (이미 활성화된 상태에서만)
            if (isSessionActive) {
                initCamera { _, _ -> }
            }
            
            Log.d(TAG, "카메라 최적화 설정 완료")
        } catch (e: Exception) {
            Log.e(TAG, "카메라 최적화 설정 실패: ${e.message}", e)
        }
    }
    
    // 세션 상태 확인 (Flutter에서 호출 가능)
    fun isSessionActive(): Boolean {
        return isSessionActive
    }
    
    // Surface 제공자 설정 (NativeCameraView에서 호출)
    fun setSurfaceProvider(provider: Preview.SurfaceProvider) {
        Log.d(TAG, "setSurfaceProvider 호출")
        
        // SurfaceProvider 저장
        surfaceProvider = provider
        
        // Preview가 이미 초기화되었으면 SurfaceProvider 설정
        if (preview != null) {
            preview?.setSurfaceProvider(null) // 기존 연결 해제
            preview?.setSurfaceProvider(provider)
            Log.d(TAG, "SurfaceProvider 설정 성공")
        } else {
            Log.d(TAG, "Preview가 null입니다. SurfaceProvider는 저장되었고 초기화 시 사용됩니다.")
        }
    }
}
