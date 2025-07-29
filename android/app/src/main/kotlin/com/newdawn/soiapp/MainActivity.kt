package com.newdawn.soiapp

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    companion object {
        private const val CAMERA_CHANNEL = "com.soi.camera"
        private const val AUDIO_CHANNEL = "com.soi.audio"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 1001
        private const val AUDIO_PERMISSION_REQUEST_CODE = 1002
        private const val TAG = "MainActivity"
    }
    
    private lateinit var cameraHandler: CameraHandler
    private lateinit var audioRecorder: AudioRecorder
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 핸들러 초기화
        cameraHandler = CameraHandler(this)
        audioRecorder = AudioRecorder(this)
        
        // 권한 확인
        checkAndRequestPermissions()
        
        // 카메라 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleCameraCall(call, result)
            }
        
        // 오디오 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleAudioCall(call, result)
            }
        
        // native_recorder 채널도 오디오 핸들러로 연결
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "native_recorder")
            .setMethodCallHandler { call, result ->
                handleAudioCall(call, result)
            }
        
        Log.d(TAG, "✅ Flutter Engine 설정 완료")
    }
    
    /**
     * 카메라 메서드 처리
     */
    private fun handleCameraCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initCamera" -> {
                try {
                    if (hasCameraPermission()) {
                        val success = cameraHandler.initCamera()
                        result.success(success)
                    } else {
                        result.error("PERMISSION_DENIED", "카메라 권한이 없습니다", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "카메라 초기화 오류", e)
                    result.error("CAMERA_ERROR", "카메라 초기화 실패: ${e.message}", null)
                }
            }
            "takePicture" -> {
                try {
                    if (hasCameraPermission()) {
                        val outputDir = cameraHandler.getOutputDirectory()
                        val photoPath = cameraHandler.takePicture(outputDir)
                        if (photoPath.isNotEmpty()) {
                            result.success(photoPath)
                        } else {
                            result.error("CAPTURE_FAILED", "사진 촬영에 실패했습니다", null)
                        }
                    } else {
                        result.error("PERMISSION_DENIED", "카메라 권한이 없습니다", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "사진 촬영 오류", e)
                    result.error("CAMERA_ERROR", "사진 촬영 실패: ${e.message}", null)
                }
            }
            "isSessionActive" -> {
                try {
                    val isActive = cameraHandler.isSessionActive()
                    result.success(isActive)
                } catch (e: Exception) {
                    Log.e(TAG, "세션 상태 확인 오류", e)
                    result.error("CAMERA_ERROR", "세션 상태 확인 실패: ${e.message}", null)
                }
            }
            "switchCamera" -> {
                try {
                    val success = cameraHandler.switchCamera()
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "카메라 전환 오류", e)
                    result.error("CAMERA_ERROR", "카메라 전환 실패: ${e.message}", null)
                }
            }
            "hasCameraPermission" -> {
                val hasPermission = hasCameraPermission()
                result.success(hasPermission)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 오디오 메서드 처리
     */
    private fun handleAudioCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> {
                try {
                    if (hasAudioPermission()) {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null) {
                            val success = audioRecorder.startRecording(filePath)
                            result.success(success)
                        } else {
                            // 기본 파일 경로 생성
                            val outputDir = audioRecorder.getOutputDirectory()
                            val defaultPath = "${outputDir}/SOI_${System.currentTimeMillis()}.m4a"
                            val success = audioRecorder.startRecording(defaultPath)
                            if (success) {
                                result.success(mapOf("success" to true, "filePath" to defaultPath))
                            } else {
                                result.error("RECORDING_FAILED", "녹음 시작에 실패했습니다", null)
                            }
                        }
                    } else {
                        result.error("PERMISSION_DENIED", "오디오 권한이 없습니다", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 시작 오류", e)
                    result.error("AUDIO_ERROR", "녹음 시작 실패: ${e.message}", null)
                }
            }
            "stopRecording" -> {
                try {
                    val recordingResult = audioRecorder.stopRecording()
                    if (recordingResult != null) {
                        val resultMap = mapOf(
                            "duration" to recordingResult.duration,
                            "filePath" to recordingResult.filePath,
                            "success" to recordingResult.success
                        )
                        result.success(resultMap)
                    } else {
                        result.error("NOT_RECORDING", "녹음 중이 아닙니다", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 중지 오류", e)
                    result.error("AUDIO_ERROR", "녹음 중지 실패: ${e.message}", null)
                }
            }
            "isRecording" -> {
                try {
                    val recording = audioRecorder.isRecording()
                    result.success(recording)
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 상태 확인 오류", e)
                    result.error("AUDIO_ERROR", "녹음 상태 확인 실패: ${e.message}", null)
                }
            }
            "getCurrentDuration" -> {
                try {
                    val duration = audioRecorder.getCurrentDuration()
                    result.success(duration)
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 시간 확인 오류", e)
                    result.error("AUDIO_ERROR", "녹음 시간 확인 실패: ${e.message}", null)
                }
            }
            "pauseRecording" -> {
                try {
                    val success = audioRecorder.pauseRecording()
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 일시정지 오류", e)
                    result.error("AUDIO_ERROR", "녹음 일시정지 실패: ${e.message}", null)
                }
            }
            "resumeRecording" -> {
                try {
                    val success = audioRecorder.resumeRecording()
                    result.success(success)
                } catch (e: Exception) {
                    Log.e(TAG, "녹음 재개 오류", e)
                    result.error("AUDIO_ERROR", "녹음 재개 실패: ${e.message}", null)
                }
            }
            "hasAudioPermission" -> {
                val hasPermission = hasAudioPermission()
                result.success(hasPermission)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 권한 확인 메서드들
     */
    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun hasStoragePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    /**
     * 권한 요청
     */
    private fun checkAndRequestPermissions() {
        val permissionsNeeded = mutableListOf<String>()
        
        if (!hasCameraPermission()) {
            permissionsNeeded.add(Manifest.permission.CAMERA)
        }
        
        if (!hasAudioPermission()) {
            permissionsNeeded.add(Manifest.permission.RECORD_AUDIO)
        }
        
        // API 29 이하에서만 WRITE_EXTERNAL_STORAGE 권한 필요
        if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.Q && !hasStoragePermission()) {
            permissionsNeeded.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        
        if (permissionsNeeded.isNotEmpty()) {
            Log.d(TAG, "권한 요청: $permissionsNeeded")
            ActivityCompat.requestPermissions(
                this,
                permissionsNeeded.toTypedArray(),
                CAMERA_PERMISSION_REQUEST_CODE
            )
        } else {
            Log.d(TAG, "모든 권한이 이미 부여되어 있습니다")
        }
    }
    
    /**
     * 권한 요청 결과 처리
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            CAMERA_PERMISSION_REQUEST_CODE -> {
                val grantedPermissions = mutableListOf<String>()
                val deniedPermissions = mutableListOf<String>()
                
                for (i in permissions.indices) {
                    if (grantResults[i] == PackageManager.PERMISSION_GRANTED) {
                        grantedPermissions.add(permissions[i])
                    } else {
                        deniedPermissions.add(permissions[i])
                    }
                }
                
                if (grantedPermissions.isNotEmpty()) {
                    Log.d(TAG, "권한 부여됨: $grantedPermissions")
                }
                
                if (deniedPermissions.isNotEmpty()) {
                    Log.w(TAG, "권한 거부됨: $deniedPermissions")
                }
            }
        }
    }
    
    /**
     * 액티비티 종료 시 리소스 해제
     */
    override fun onDestroy() {
        super.onDestroy()
        try {
            cameraHandler.release()
            audioRecorder.release()
            Log.d(TAG, "✅ 리소스 해제 완료")
        } catch (e: Exception) {
            Log.e(TAG, "리소스 해제 오류", e)
        }
    }
}
