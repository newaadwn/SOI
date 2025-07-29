// MARK: - 네이티브 오디오 녹음 클래스
class NativeAudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordingSession: AVAudioSession?
    
    func requestPermission(result: @escaping FlutterResult) {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            // ✅ iOS: 카메라와 호환되는 오디오 세션 설정
            try recordingSession?.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try recordingSession?.setActive(true)
            
            recordingSession?.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    result(allowed)
                }
            }
        } catch {
            result(FlutterError(code: "PERMISSION_ERROR", message: "Failed to request permission", details: error.localizedDescription))
        }
    }
    
    func startRecording(filePath: String, result: @escaping FlutterResult) {
        let audioURL = URL(fileURLWithPath: filePath)
        
        // ✅ iOS: 카메라 촬영과 충돌하지 않도록 오디오 세션 재설정
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try recordingSession?.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ iOS AudioRecorder: 오디오 세션 설정 실패: \(error.localizedDescription)")
        }
        
        // 🎯 고품질 오디오 설정 (현재 Flutter 설정보다 향상)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,  // CD 품질 (기존 Flutter: 44100)
            AVNumberOfChannelsKey: 1,  // 모노 (음성 녹음에 적합)
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 192000,  // 192kbps (기존 Flutter: 128kbps)
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            if success {
                recordingStartTime = Date()
                result(true)
            } else {
                result(FlutterError(code: "RECORDING_ERROR", message: "Failed to start recording", details: nil))
            }
        } catch {
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to create recorder", details: error.localizedDescription))
        }
    }
            }
        } catch {
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to create recorder", details: error.localizedDescription))
        }
    }
    
    func stopRecording(result: @escaping FlutterResult) {
        audioRecorder?.stop()
        let filePath = audioRecorder?.url.path
        audioRecorder = nil
        recordingStartTime = nil
        
        // ✅ iOS: 녹음 종료 후 오디오 세션을 다른 앱들이 사용할 수 있도록 정리
        do {
            try recordingSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ iOS AudioRecorder: 오디오 세션 비활성화 실패: \(error.localizedDescription)")
        }
        
        result(filePath)
    }
    
    func isRecording(result: @escaping FlutterResult) {
        result(audioRecorder?.isRecording ?? false)
    }
    
    // AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}