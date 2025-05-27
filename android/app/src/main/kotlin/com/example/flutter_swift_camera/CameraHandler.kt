package com.example.flutter_swift_camera

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.OutputConfiguration
import android.hardware.camera2.params.SessionConfiguration
import android.media.ImageReader
import android.media.MediaRecorder
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import android.view.Surface
import android.view.TextureView
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.Executors

class CameraHandler(private val activity: FlutterActivity) {
    companion object {
        private const val TAG = "CameraHandler"
    }

    // 카메라 상태
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    
    // 카메라 설정
    private val cameraManager: CameraManager = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private var cameraId = "0" // 기본 후면 카메라
    private var flashMode = CameraMetadata.FLASH_MODE_OFF
    
    // 스레드 및 핸들러
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    
    // 카메라 미리보기용 텍스처뷰
    private var textureView: TextureView? = null
    
    // 임시 출력 파일
    private var outputFile: File? = null

    // 스레드 시작
    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").apply {
            start()
            backgroundHandler = Handler(looper)
        }
    }

    // 스레드 중지
    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "스레드 종료 중 오류: ${e.message}")
        }
    }

    // 카메라 초기화
    @SuppressLint("MissingPermission")
    fun initCamera(callback: (Boolean, String?) -> Unit) {
        try {
            // 백그라운드 스레드 시작
            startBackgroundThread()
            
            // 출력 디렉토리 생성
            createOutputDirectory()
            
            // 카메라 준비
            val cameraIds = cameraManager.cameraIdList
            if (cameraIds.isEmpty()) {
                callback(false, "사용 가능한 카메라가 없습니다.")
                return
            }
            
            // 후면 카메라 ID 찾기
            cameraId = cameraIds[0] // 기본값 (보통 후면 카메라)
            for (id in cameraIds) {
                val characteristics = cameraManager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id
                    break
                }
            }
            
            // 이미지 리더 설정 (고해상도 사진 캡처용)
            setupImageReader()
            
            // 카메라 열기
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    // 카메라가 열리면 텍스처뷰 생성 및 미리보기 시작
                    createPreviewSession()
                    callback(true, null)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                    callback(false, "카메라 연결 해제")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    callback(false, "카메라 오류 코드: $error")
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            Log.e(TAG, "카메라 초기화 오류: ${e.message}")
            callback(false, "카메라 초기화 중 오류: ${e.message}")
        }
    }
    
    // 이미지 리더 설정
    private fun setupImageReader() {
        try {
            // 가능한 최대 해상도 찾기
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val streamConfigurationMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val sizes = streamConfigurationMap?.getOutputSizes(ImageFormat.JPEG) ?: arrayOf()
            
            // 적절한 해상도 선택 (높지만 너무 과도하지 않게)
            var width = 1920
            var height = 1080
            
            if (sizes.isNotEmpty()) {
                // 4K 또는 그 이하의 최고 해상도 선택
                for (size in sizes) {
                    if (size.width <= 3840 && size.height <= 2160 && 
                        size.width * size.height > width * height) {
                        width = size.width
                        height = size.height
                    }
                }
            }
            
            // 이미지 리더 생성
            imageReader = ImageReader.newInstance(width, height, ImageFormat.JPEG, 2).apply {
                setOnImageAvailableListener({ reader ->
                    val image = reader.acquireLatestImage()
                    backgroundHandler?.post {
                        saveImage(image)
                    }
                }, backgroundHandler)
            }
        } catch (e: Exception) {
            Log.e(TAG, "이미지 리더 설정 오류: ${e.message}")
        }
    }
    
    // 이미지 저장
    private fun saveImage(image: android.media.Image?) {
        var tempFile: File? = null
        try {
            image?.use {
                val buffer = it.planes[0].buffer
                val bytes = ByteArray(buffer.capacity())
                buffer.get(bytes)
                
                // 저장할 파일 생성
                tempFile = createImageFile()
                
                FileOutputStream(tempFile).use { output ->
                    output.write(bytes)
                }
                
                Log.d(TAG, "이미지 저장 완료: ${tempFile?.absolutePath}")
                
                // 저장된 경로 저장
                outputFile = tempFile
            }
        } catch (e: Exception) {
            Log.e(TAG, "이미지 저장 오류: ${e.message}")
            tempFile?.delete()
        }
    }
    
    // 미리보기 세션 생성
    private fun createPreviewSession() {
        try {
            // 텍스처뷰가 없으면 더미 서페이스 생성
            val dummyTexture = SurfaceTexture(0)
            dummyTexture.setDefaultBufferSize(1280, 720)
            val dummySurface = Surface(dummyTexture)
            
            // 프리뷰 요청 생성
            val captureRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureRequestBuilder?.addTarget(dummySurface)
            
            // 플래시 모드 설정
            captureRequestBuilder?.set(CaptureRequest.FLASH_MODE, flashMode)
            
            // 자동 초점 설정
            captureRequestBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            
            // 세션 생성 API 레벨에 따라 다르게 처리
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                // API 28 이상
                val sessionConfiguration = SessionConfiguration(
                    SessionConfiguration.SESSION_REGULAR,
                    listOf(OutputConfiguration(dummySurface)),
                    Executors.newSingleThreadExecutor(),
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            captureSession = session
                            try {
                                // 미리보기 반복 요청
                                captureRequestBuilder?.build()?.let { request ->
                                    session.setRepeatingRequest(request, null, backgroundHandler)
                                }
                            } catch (e: CameraAccessException) {
                                Log.e(TAG, "미리보기 설정 오류: ${e.message}")
                            }
                        }

                        override fun onConfigureFailed(session: CameraCaptureSession) {
                            Log.e(TAG, "카메라 세션 구성 실패")
                        }
                    }
                )
                cameraDevice?.createCaptureSession(sessionConfiguration)
            } else {
                // API 28 미만
                cameraDevice?.createCaptureSession(
                    listOf(dummySurface),
                    object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(session: CameraCaptureSession) {
                            captureSession = session
                            try {
                                // 미리보기 반복 요청
                                captureRequestBuilder?.build()?.let { request ->
                                    session.setRepeatingRequest(request, null, backgroundHandler)
                                }
                            } catch (e: CameraAccessException) {
                                Log.e(TAG, "미리보기 설정 오류: ${e.message}")
                            }
                        }

                        override fun onConfigureFailed(session: CameraCaptureSession) {
                            Log.e(TAG, "카메라 세션 구성 실패")
                        }
                    },
                    backgroundHandler
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "미리보기 세션 생성 오류: ${e.message}")
        }
    }
    
    // 사진 촬영
    fun takePicture(callback: (String?, String?) -> Unit) {
        try {
            val captureRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            
            // 이미지 리더 타겟 추가
            imageReader?.surface?.let { surface ->
                captureRequestBuilder?.addTarget(surface)
            } ?: run {
                callback(null, "이미지 리더가 준비되지 않았습니다.")
                return
            }
            
            // 플래시 모드 설정
            captureRequestBuilder?.set(CaptureRequest.FLASH_MODE, flashMode)
            
            // 자동 초점 설정
            captureRequestBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            
            // 이미지 회전 처리
            val rotation = activity.windowManager.defaultDisplay.rotation
            captureRequestBuilder?.set(CaptureRequest.JPEG_ORIENTATION, getOrientation(rotation))
            
            // 고품질 이미지 설정
            captureRequestBuilder?.set(CaptureRequest.JPEG_QUALITY, 100.toByte())
            
            // 캡처 요청
            val captureCallback = object : CameraCaptureSession.CaptureCallback() {
                override fun onCaptureCompleted(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    result: TotalCaptureResult
                ) {
                    super.onCaptureCompleted(session, request, result)
                    
                    // 이미지가 저장될 때까지 약간의 지연
                    backgroundHandler?.postDelayed({
                        if (outputFile != null && outputFile!!.exists()) {
                            callback(outputFile!!.absolutePath, null)
                        } else {
                            callback(null, "이미지 파일이 생성되지 않았습니다.")
                        }
                    }, 300)
                }
                
                override fun onCaptureFailed(
                    session: CameraCaptureSession,
                    request: CaptureRequest,
                    failure: CaptureFailure
                ) {
                    super.onCaptureFailed(session, request, failure)
                    callback(null, "사진 촬영 실패: ${failure.reason}")
                }
            }
            
            captureSession?.stopRepeating()
            captureSession?.abortCaptures()
            captureSession?.capture(captureRequestBuilder!!.build(), captureCallback, backgroundHandler)
        } catch (e: Exception) {
            Log.e(TAG, "사진 촬영 오류: ${e.message}")
            callback(null, "사진 촬영 중 오류: ${e.message}")
        }
    }
    
    // 카메라 전환
    fun switchCamera(callback: (Boolean, String?) -> Unit) {
        try {
            // 현재 카메라 세션 및 장치 닫기
            closeCamera()
            
            // 현재 카메라 ID에 따라 전환할 카메라 ID 결정
            val cameraIds = cameraManager.cameraIdList
            var newCameraId = "0"
            
            for (id in cameraIds) {
                if (id != cameraId) {
                    newCameraId = id
                    break
                }
            }
            
            cameraId = newCameraId
            
            // 새 카메라로 초기화
            initCamera { success, error ->
                callback(success, error)
            }
        } catch (e: Exception) {
            Log.e(TAG, "카메라 전환 오류: ${e.message}")
            callback(false, "카메라 전환 중 오류: ${e.message}")
        }
    }
    
    // 플래시 설정
    fun setFlash(isOn: Boolean, callback: (Boolean, String?) -> Unit) {
        try {
            flashMode = if (isOn) CameraMetadata.FLASH_MODE_TORCH else CameraMetadata.FLASH_MODE_OFF
            
            // 현재 세션이 활성화되어 있으면 플래시 모드 업데이트
            captureSession?.let { session ->
                // 프리뷰 요청 생성
                val captureRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                
                // 더미 서페이스 생성
                val dummyTexture = SurfaceTexture(0)
                dummyTexture.setDefaultBufferSize(1280, 720)
                val dummySurface = Surface(dummyTexture)
                
                captureRequestBuilder?.addTarget(dummySurface)
                captureRequestBuilder?.set(CaptureRequest.FLASH_MODE, flashMode)
                
                try {
                    session.stopRepeating()
                    session.setRepeatingRequest(captureRequestBuilder!!.build(), null, backgroundHandler)
                    callback(true, null)
                } catch (e: CameraAccessException) {
                    Log.e(TAG, "플래시 모드 설정 오류: ${e.message}")
                    callback(false, "플래시 모드 설정 오류: ${e.message}")
                }
            } ?: run {
                // 세션이 없으면 성공으로 처리하고 다음에 세션 생성 시 적용됨
                callback(true, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "플래시 설정 오류: ${e.message}")
            callback(false, "플래시 설정 중 오류: ${e.message}")
        }
    }
    
    // 카메라 일시 중지
    fun pauseCamera() {
        try {
            captureSession?.stopRepeating()
        } catch (e: Exception) {
            Log.e(TAG, "카메라 일시 중지 오류: ${e.message}")
        }
    }
    
    // 카메라 재개
    fun resumeCamera() {
        try {
            createPreviewSession()
        } catch (e: Exception) {
            Log.e(TAG, "카메라 재개 오류: ${e.message}")
        }
    }
    
    // 카메라 자원 해제
    fun disposeCamera() {
        closeCamera()
        stopBackgroundThread()
    }
    
    // 카메라 최적화 설정
    fun optimizeCamera(autoFocus: Boolean, highQuality: Boolean, stabilization: Boolean) {
        try {
            captureSession?.let { session ->
                val captureRequestBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                
                // 더미 서페이스 생성
                val dummyTexture = SurfaceTexture(0)
                dummyTexture.setDefaultBufferSize(1280, 720)
                val dummySurface = Surface(dummyTexture)
                
                captureRequestBuilder?.addTarget(dummySurface)
                
                // 자동 초점 설정
                if (autoFocus) {
                    captureRequestBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                }
                
                // 이미지 안정화 설정
                if (stabilization) {
                    captureRequestBuilder?.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE_ON)
                    captureRequestBuilder?.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE_ON)
                }
                
                // 이미지 품질 설정
                if (highQuality) {
                    captureRequestBuilder?.set(CaptureRequest.NOISE_REDUCTION_MODE, CaptureRequest.NOISE_REDUCTION_MODE_HIGH_QUALITY)
                    captureRequestBuilder?.set(CaptureRequest.COLOR_CORRECTION_ABERRATION_MODE, CaptureRequest.COLOR_CORRECTION_ABERRATION_MODE_HIGH_QUALITY)
                    captureRequestBuilder?.set(CaptureRequest.EDGE_MODE, CaptureRequest.EDGE_MODE_HIGH_QUALITY)
                }
                
                try {
                    session.stopRepeating()
                    session.setRepeatingRequest(captureRequestBuilder!!.build(), null, backgroundHandler)
                } catch (e: CameraAccessException) {
                    Log.e(TAG, "카메라 최적화 설정 오류: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "카메라 최적화 오류: ${e.message}")
        }
    }
    
    // 카메라 및 관련 자원 닫기
    private fun closeCamera() {
        try {
            captureSession?.close()
            captureSession = null
            
            cameraDevice?.close()
            cameraDevice = null
            
            imageReader?.close()
            imageReader = null
            
            mediaRecorder?.release()
            mediaRecorder = null
        } catch (e: Exception) {
            Log.e(TAG, "카메라 리소스 정리 오류: ${e.message}")
        }
    }
    
    // 임시 사진 파일 생성
    @Throws(IOException::class)
    private fun createImageFile(): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFileName = "JPEG_$timestamp"
        val storageDir = activity.getExternalFilesDir(null)
        return File.createTempFile(imageFileName, ".jpg", storageDir)
    }
    
    // 출력 디렉토리 생성
    private fun createOutputDirectory() {
        val mediaDir = activity.getExternalFilesDir(null)
        if (mediaDir != null && !mediaDir.exists()) {
            mediaDir.mkdirs()
        }
    }
    
    // 이미지 회전 계산
    private fun getOrientation(rotation: Int): Int {
        return when (rotation) {
            Surface.ROTATION_0 -> 90
            Surface.ROTATION_90 -> 0
            Surface.ROTATION_180 -> 270
            Surface.ROTATION_270 -> 180
            else -> 0
        }
    }
} 