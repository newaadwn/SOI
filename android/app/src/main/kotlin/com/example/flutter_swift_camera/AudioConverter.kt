package com.example.flutter_swift_camera

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread

class AudioConverter : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.app.audio_converter")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "convertAudioToAAC" -> {
                val inputPath = call.argument<String>("inputPath")
                if (inputPath == null) {
                    result.error("INVALID_ARGUMENTS", "Input path is required", null)
                    return
                }
                
                thread {
                    try {
                        val outputPath = convertAudioToAAC(inputPath)
                        if (outputPath != null) {
                            // UI 스레드에서 결과 반환
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.success(outputPath)
                            }
                        } else {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("CONVERSION_FAILED", "Audio conversion failed", null)
                            }
                        }
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("CONVERSION_ERROR", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    @Throws(IOException::class)
    private fun convertAudioToAAC(inputPath: String): String? {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)
        
        // 오디오 트랙 찾기
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                audioTrackIndex = i
                break
            }
        }
        
        if (audioTrackIndex == -1) {
            extractor.release()
            return null // 오디오 트랙을 찾지 못함
        }
        
        // 오디오 트랙 선택
        extractor.selectTrack(audioTrackIndex)
        val format = extractor.getTrackFormat(audioTrackIndex)
        
        // 출력 파일 생성 (m4a 확장자 사용)
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val outputFile = File(context.cacheDir, "audio_$timestamp.m4a")
        val outputPath = outputFile.absolutePath
        
        // MediaMuxer와 코덱 설정 (AAC 포맷으로 출력)
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        
        val mime = format.getString(MediaFormat.KEY_MIME)
        val decoder = MediaCodec.createDecoderByType(mime ?: "audio/mp4a-latm")
        decoder.configure(format, null, null, 0)
        decoder.start()
        
        // 출력 포맷 설정 (AAC 사용)
        val outputFormat = MediaFormat.createAudioFormat("audio/mp4a-latm", 
            format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
            format.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
        outputFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, 2) // AAC LC
        outputFormat.setInteger(MediaFormat.KEY_BIT_RATE, 128000) // 128kbps
        
        val encoder = MediaCodec.createEncoderByType("audio/mp4a-latm")
        encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        
        // 출력 트랙 추가
        val outputTrackIndex = muxer.addTrack(outputFormat)
        muxer.start()
        
        // 버퍼 처리
        val bufferInfo = MediaCodec.BufferInfo()
        val timeout = 10000L // 10초 타임아웃
        
        var inputDone = false
        var outputDone = false
        
        // 디코딩 및 인코딩 루프
        while (!outputDone) {
            // 타임아웃 설정
            if (!inputDone) {
                val inputBufferId = decoder.dequeueInputBuffer(timeout)
                if (inputBufferId >= 0) {
                    val inputBuffer = decoder.getInputBuffer(inputBufferId)
                    val sampleSize = extractor.readSampleData(inputBuffer!!, 0)
                    
                    if (sampleSize < 0) {
                        // 입력 종료
                        decoder.queueInputBuffer(inputBufferId, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        val presentationTime = extractor.sampleTime
                        decoder.queueInputBuffer(inputBufferId, 0, sampleSize, presentationTime, 0)
                        extractor.advance()
                    }
                }
            }
            
            // 출력 버퍼 처리
            var decoderOutputAvailable = true
            while (decoderOutputAvailable) {
                val outputBufferId = decoder.dequeueOutputBuffer(bufferInfo, timeout)
                if (outputBufferId == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    decoderOutputAvailable = false
                } else if (outputBufferId >= 0) {
                    val outputBuffer = decoder.getOutputBuffer(outputBufferId)
                    
                    // 인코더에 입력
                    val encoderInputBufferId = encoder.dequeueInputBuffer(timeout)
                    if (encoderInputBufferId >= 0) {
                        val encoderInputBuffer = encoder.getInputBuffer(encoderInputBufferId)
                        encoderInputBuffer!!.clear()
                        encoderInputBuffer.put(outputBuffer)
                        encoder.queueInputBuffer(encoderInputBufferId, 0, bufferInfo.size, bufferInfo.presentationTimeUs, bufferInfo.flags)
                    }
                    
                    decoder.releaseOutputBuffer(outputBufferId, false)
                    
                    // 종료 확인
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
            
            // 인코더 출력 처리
            var encoderOutputAvailable = true
            while (encoderOutputAvailable) {
                val encoderOutputBufferId = encoder.dequeueOutputBuffer(bufferInfo, timeout)
                if (encoderOutputBufferId == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    encoderOutputAvailable = false
                } else if (encoderOutputBufferId >= 0) {
                    val encoderOutputBuffer = encoder.getOutputBuffer(encoderOutputBufferId)
                    
                    // Muxer에 쓰기
                    muxer.writeSampleData(outputTrackIndex, encoderOutputBuffer!!, bufferInfo)
                    
                    encoder.releaseOutputBuffer(encoderOutputBufferId, false)
                }
            }
        }
        
        // 리소스 해제
        extractor.release()
        decoder.stop()
        decoder.release()
        encoder.stop()
        encoder.release()
        muxer.stop()
        muxer.release()
        
        return outputPath
    }
}