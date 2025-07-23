package com.newdawn.soiapp

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File

class AudioRecorder(private val context: Context) {
    companion object {
        private const val TAG = "AudioRecorder"
    }
    
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var recordingStartTime: Long = 0
    private var currentFilePath: String? = null
    
    /**
     * 녹음 시작
     */
    fun startRecording(filePath: String): Boolean {
        return try {
            // 기존 녹음이 있다면 중지
            if (isRecording) {
                stopRecording()
            }
            
            Log.d(TAG, "🎙️ 녹음 시작: $filePath")
            
            // 출력 디렉토리 생성
            val file = File(filePath)
            file.parentFile?.mkdirs()
            
            // MediaRecorder 초기화
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                // 오디오 소스 설정
                setAudioSource(MediaRecorder.AudioSource.MIC)
                
                // 출력 포맷 설정
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                
                // 오디오 인코더 설정
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                
                // 품질 설정
                setAudioEncodingBitRate(128000) // 128kbps
                setAudioSamplingRate(44100)    // 44.1kHz
                
                // 출력 파일 설정
                setOutputFile(filePath)
                
                try {
                    // 준비 및 시작
                    prepare()
                    start()
                    
                    recordingStartTime = System.currentTimeMillis()
                    isRecording = true
                    currentFilePath = filePath
                    
                    Log.d(TAG, "✅ 녹음 시작 성공")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "❌ 녹음 시작 실패 (prepare/start)", e)
                    release()
                    return false
                }
            }
            
            false
        } catch (e: Exception) {
            Log.e(TAG, "❌ 녹음 시작 오류", e)
            cleanup()
            false
        }
    }
    
    /**
     * 녹음 중지
     */
    fun stopRecording(): RecordingResult? {
        return if (isRecording) {
            try {
                Log.d(TAG, "🛑 녹음 중지 시도...")
                
                mediaRecorder?.apply {
                    stop()
                    reset()
                    release()
                }
                
                val duration = System.currentTimeMillis() - recordingStartTime
                val filePath = currentFilePath
                
                // 상태 초기화
                mediaRecorder = null
                isRecording = false
                currentFilePath = null
                
                Log.d(TAG, "✅ 녹음 중지 성공, 길이: ${duration}ms")
                
                RecordingResult(
                    duration = duration,
                    filePath = filePath ?: "",
                    success = true
                )
            } catch (e: Exception) {
                Log.e(TAG, "❌ 녹음 중지 실패", e)
                cleanup()
                RecordingResult(
                    duration = 0,
                    filePath = "",
                    success = false
                )
            }
        } else {
            Log.w(TAG, "⚠️ 녹음 중이 아님")
            null
        }
    }
    
    /**
     * 녹음 상태 확인
     */
    fun isRecording(): Boolean {
        Log.d(TAG, "🔍 녹음 상태 확인: $isRecording")
        return isRecording
    }
    
    /**
     * 현재 녹음 길이 (밀리초)
     */
    fun getCurrentDuration(): Long {
        return if (isRecording) {
            System.currentTimeMillis() - recordingStartTime
        } else {
            0
        }
    }
    
    /**
     * 녹음 일시정지 (API 24+)
     */
    fun pauseRecording(): Boolean {
        return try {
            if (isRecording && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.pause()
                Log.d(TAG, "⏸️ 녹음 일시정지")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 녹음 일시정지 실패", e)
            false
        }
    }
    
    /**
     * 녹음 재개 (API 24+)
     */
    fun resumeRecording(): Boolean {
        return try {
            if (isRecording && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                mediaRecorder?.resume()
                Log.d(TAG, "▶️ 녹음 재개")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 녹음 재개 실패", e)
            false
        }
    }
    
    /**
     * 리소스 정리
     */
    private fun cleanup() {
        try {
            mediaRecorder?.apply {
                if (isRecording) {
                    try {
                        stop()
                    } catch (e: Exception) {
                        Log.w(TAG, "stop() 실패 (이미 중지된 상태일 수 있음)")
                    }
                }
                reset()
                release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "cleanup 오류", e)
        } finally {
            mediaRecorder = null
            isRecording = false
            currentFilePath = null
        }
    }
    
    /**
     * AudioRecorder 해제
     */
    fun release() {
        Log.d(TAG, "🔄 AudioRecorder 리소스 해제")
        cleanup()
    }
    
    /**
     * 출력 디렉토리 가져오기
     */
    fun getOutputDirectory(): File {
        val mediaDir = context.externalMediaDirs.firstOrNull()?.let {
            File(it, "SOI_Audio").apply { mkdirs() }
        }
        return if (mediaDir != null && mediaDir.exists()) mediaDir else context.filesDir
    }
}

/**
 * 녹음 결과 데이터 클래스
 */
data class RecordingResult(
    val duration: Long,
    val filePath: String,
    val success: Boolean
)
