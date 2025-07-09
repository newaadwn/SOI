import UIKit
import Flutter
import AVFoundation

// MARK: - 네이티브 오디오 녹음 클래스
class NativeAudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordingSession: AVAudioSession?
    
    func requestPermission(result: @escaping FlutterResult) {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default)
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
        print("🎤 녹음 시작 요청 - 파일 경로: \(filePath)")
        
        // 1. 오디오 세션 설정 및 활성화
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            print("✅ 오디오 세션 활성화 성공")
        } catch {
            print("❌ 오디오 세션 설정 실패: \(error.localizedDescription)")
            result(FlutterError(code: "SESSION_ERROR", message: "Audio session setup failed", details: error.localizedDescription))
            return
        }
        
        // 2. 마이크 권한 확인
        let permissionStatus = audioSession.recordPermission
        print("🔒 마이크 권한 상태: \(permissionStatus.rawValue)")
        
        if permissionStatus != .granted {
            print("❌ 마이크 권한이 없습니다")
            result(FlutterError(code: "PERMISSION_ERROR", message: "Microphone permission not granted", details: nil))
            return
        }
        
        // 3. 파일 경로 검증 및 디렉토리 생성
        let audioURL = URL(fileURLWithPath: filePath)
        let parentDirectory = audioURL.deletingLastPathComponent()
        
        print("📁 파일 URL: \(audioURL)")
        print("📁 상위 디렉토리: \(parentDirectory)")
        
        // 디렉토리가 존재하는지 확인하고 없으면 생성
        if !FileManager.default.fileExists(atPath: parentDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ 디렉토리 생성 성공: \(parentDirectory.path)")
            } catch {
                print("❌ 디렉토리 생성 실패: \(error.localizedDescription)")
                result(FlutterError(code: "DIRECTORY_ERROR", message: "Failed to create directory", details: error.localizedDescription))
                return
            }
        }
        
        // 4. 오디오 설정
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        print("🎛️ 오디오 설정: \(settings)")

        do {
            print("🎤 AVAudioRecorder 생성 시도...")
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            print("🎤 녹음 준비 중...")
            let prepareSuccess = audioRecorder?.prepareToRecord() ?? false
            print("🎤 준비 결과: \(prepareSuccess)")
            
            if !prepareSuccess {
                print("❌ 녹음 준비 실패")
                result(FlutterError(code: "RECORDING_ERROR", message: "Failed to prepare recording", details: nil))
                return
            }
            
            print("🎤 녹음 시작 시도...")
            let success = audioRecorder?.record() ?? false
            print("🎤 녹음 시작 결과: \(success)")
            
            if success {
                recordingStartTime = Date()
                print("✅ 녹음 시작 성공! 파일: \(filePath)")
                result(filePath)  // 파일 경로 반환
            } else {
                print("❌ 녹음 시작 실패")
                result(FlutterError(code: "RECORDING_ERROR", message: "Failed to start recording", details: nil))
            }
        } catch {
            print("❌ AVAudioRecorder 생성 실패: \(error.localizedDescription)")
            result(FlutterError(code: "RECORDING_ERROR", message: "Failed to create recorder", details: error.localizedDescription))
        }
    }
    
    func stopRecording(result: @escaping FlutterResult) {
        audioRecorder?.stop()
        let filePath = audioRecorder?.url.path
        audioRecorder = nil
        recordingStartTime = nil
        
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
