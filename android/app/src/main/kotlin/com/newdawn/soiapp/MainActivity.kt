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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soi.camera"
    private val AUDIO_CHANNEL = "native_recorder"
    private lateinit var cameraHandler: CameraHandler
    private val CAMERA_PERMISSION_CODE = 100
    private val AUDIO_PERMISSION_CODE = 101
    
    // 네이티브 오디오 녹음 관련 변수
    private var mediaRecorder: MediaRecorder? = null
    private var recordingStartTime: Long = 0
    private var isRecording = false
    private var currentFilePath: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // AudioConverter 플러그인 등록
        flutterEngine.plugins.add(AudioConverter())
        
        // 카메라 핸들러 초기화
        cameraHandler = CameraHandler(this)
        
        // 네이티브 카메라 뷰 등록
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.soi.camera/preview",
            NativeCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
        
        // 메서드 채널 설정 (카메라)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // 권한 확인
            if (!checkCameraPermissions() && 
                (call.method == "initCamera" || 
                call.method == "takePicture" || 
                call.method == "switchCamera")) {
                requestCameraPermissions()
                result.error("PERMISSION_DENIED", "카메라 권한이 필요합니다", null)
                return@setMethodCallHandler
            }
            
            when (call.method) {
                "initCamera" -> {
                    cameraHandler.initCamera { success, error ->
                        if (success) {
                            result.success("카메라 초기화 성공")
                        } else {
                            result.error("INIT_FAILED", error ?: "카메라 초기화 실패", null)
                        }
                    }
                }
                "takePicture" -> {
                    cameraHandler.takePicture { path, error ->
                        if (path != null) {
                            result.success(path)
                        } else {
                            result.error("CAPTURE_FAILED", error ?: "사진 촬영 실패", null)
                        }
                    }
                }
                "switchCamera" -> {
                    cameraHandler.switchCamera { success, error ->
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("SWITCH_FAILED", error ?: "카메라 전환 실패", null)
                        }
                    }
                }
                "setFlash" -> {
                    val isOn = call.argument<Boolean>("isOn") ?: false
                    cameraHandler.setFlash(isOn) { success, error ->
                        if (success) {
                            result.success(true)
                        } else {
                            result.error("FLASH_FAILED", error ?: "플래시 설정 실패", null)
                        }
                    }
                }
                "pauseCamera" -> {
                    cameraHandler.pauseCamera()
                    result.success(true)
                }
                "resumeCamera" -> {
                    cameraHandler.resumeCamera()
                    result.success(true)
                }
                "disposeCamera" -> {
                    cameraHandler.disposeCamera()
                    result.success(true)
                }
                "optimizeCamera" -> {
                    val autoFocus = call.argument<Boolean>("autoFocus") ?: true
                    val highQuality = call.argument<Boolean>("highQuality") ?: true
                    val stabilization = call.argument<Boolean>("stabilization") ?: true
                    cameraHandler.optimizeCamera(autoFocus, highQuality, stabilization)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // 🎯 네이티브 오디오 녹음 메서드 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    requestAudioPermission(result)
                }
                "startRecording" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        startRecording(filePath, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Invalid file path", null)
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
    
    // 권한 체크
    private fun checkCameraPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED &&
               ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }
    
    // 권한 요청
    private fun requestCameraPermissions() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ),
            CAMERA_PERMISSION_CODE
        )
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // 권한이 부여됨, 카메라 초기화 시도
                cameraHandler.initCamera { _, _ -> }
            }
        }
        // 오디오 권한 결과는 별도 처리 (콜백 방식)
    }
    
    // 🎯 네이티브 오디오 녹음 함수들
    private fun requestAudioPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) 
            != PackageManager.PERMISSION_GRANTED) {
            
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                AUDIO_PERMISSION_CODE
            )
            result.success(false)
        } else {
            result.success(true)
        }
    }

    private fun startRecording(filePath: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_ERROR", "Audio recording permission not granted", null)
            return
        }

        try {
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(filePath)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                
                // 🎯 고품질 오디오 설정 (현재 Flutter 설정보다 향상)
                setAudioSamplingRate(44100)  // CD 품질
                setAudioChannels(1)  // 모노 (음성 녹음에 적합)
                setAudioEncodingBitRate(192000)  // 192kbps (기존 Flutter Android: 160kbps)
                
                prepare()
                start()
                
                recordingStartTime = System.currentTimeMillis()
                isRecording = true
                currentFilePath = filePath
                
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("RECORDING_ERROR", "Failed to start recording: ${e.message}", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false
            
            result.success(currentFilePath)
            currentFilePath = null
        } catch (e: Exception) {
            result.error("RECORDING_ERROR", "Failed to stop recording: ${e.message}", null)
        }
    }
}
