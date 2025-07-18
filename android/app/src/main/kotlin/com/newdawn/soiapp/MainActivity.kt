package com.newdawn.soiapp

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soi.camera"
    private val AUDIO_CHANNEL = "native_recorder"
    private lateinit var cameraHandler: CameraHandler
    
    private val CAMERA_PERMISSION_REQUEST_CODE = 1002
    private val TAG = "MainActivity"
    
    // 네이티브 오디오 녹음 관련 변수
    private var mediaRecorder: MediaRecorder? = null
    private var recordingStartTime: Long = 0
    private var isRecording = false
    private var currentFilePath: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 카메라 권한 확인 및 요청
        checkAndRequestCameraPermission()
        
        // 카메라 핸들러 초기화
        cameraHandler = CameraHandler(this)
        
        // 카메라 네이티브 뷰 등록
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.soi.camera/native_camera_view",
            NativeCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
        // 카메라 메서드 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSessionActive" -> {
                    // 카메라 세션 상태 확인
                    try {
                        val isActive = cameraHandler.isSessionActive()
                        Log.d(TAG, "isSessionActive 호출: $isActive")
                        result.success(isActive)
                    } catch (e: Exception) {
                        Log.e(TAG, "isSessionActive 오류: ${e.message}", e)
                        result.error("CAMERA_ERROR", "카메라 세션 상태 확인 실패: ${e.message}", null)
                    }
                }
                "checkCameraPermission" -> {
                    // 카메라 권한 확인
                    val hasPermission = hasCameraPermission()
                    result.success(hasPermission)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 오디오 메서드 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        startRecording(filePath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "파일 경로가 제공되지 않았습니다.", null)
                    }
                }
                "stopRecording" -> {
                    stopRecording(result)
                }
                "isRecording" -> {
                    result.success(isRecording)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    // 카메라 권한 확인 메서드
    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    // 카메라 권한 요청 메서드
    private fun checkAndRequestCameraPermission() {
        if (!hasCameraPermission()) {
            Log.d(TAG, "카메라 권한 요청 중...")
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                CAMERA_PERMISSION_REQUEST_CODE
            )
        } else {
            Log.d(TAG, "카메라 권한이 이미 부여되어 있습니다.")
        }
    }
    
    // 권한 요청 결과 처리
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "카메라 권한이 부여되었습니다.")
            } else {
                Log.e(TAG, "카메라 권한이 거부되었습니다.")
            }
        }
    }
    
    // 녹음 시작 메서드
    private fun startRecording(filePath: String, result: MethodChannel.Result) {
        try {
            // 이미 녹음 중이면 중지
            if (isRecording) {
                stopRecording(null)
            }
            
            // MediaRecorder 초기화
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(filePath)
                prepare()
                start()
            }
            
            recordingStartTime = System.currentTimeMillis()
            isRecording = true
            currentFilePath = filePath
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "녹음 시작 실패: ${e.message}", e)
            result.error("RECORDING_ERROR", "녹음을 시작할 수 없습니다: ${e.message}", null)
        }
    }
    
    // 녹음 중지 메서드
    private fun stopRecording(result: MethodChannel.Result?) {
        if (isRecording) {
            try {
                mediaRecorder?.apply {
                    stop()
                    reset()
                    release()
                }
                
                mediaRecorder = null
                isRecording = false
                
                val duration = System.currentTimeMillis() - recordingStartTime
                
                val resultMap = mapOf(
                    "duration" to duration,
                    "filePath" to currentFilePath
                )
                
                result?.success(resultMap)
            } catch (e: Exception) {
                Log.e(TAG, "녹음 중지 실패: ${e.message}", e)
                result?.error("RECORDING_ERROR", "녹음을 중지할 수 없습니다: ${e.message}", null)
            }
        } else {
            result?.error("NOT_RECORDING", "녹음 중이 아닙니다.", null)
        }
    }
    
    // 액티비티 일시 중지 시 녹음 중지
    override fun onPause() {
        super.onPause()
        if (isRecording) {
            stopRecording(null)
        }
    }
}
