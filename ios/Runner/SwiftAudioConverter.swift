import Foundation
import AVFoundation
import Flutter

public class SwiftAudioConverter: NSObject, FlutterPlugin {
    
    // Flutter 엔진에 플러그인을 등록하는 메서드
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.app.audio_converter", binaryMessenger: registrar.messenger())
        let instance = SwiftAudioConverter()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    // Flutter에서 호출되는 메서드 호출 처리
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "convertAudioToAAC":
            if let args = call.arguments as? [String: Any],
               let inputPath = args["inputPath"] as? String {
                convertToAAC(inputPath: inputPath, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                    message: "Invalid arguments",
                                    details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // 오디오 파일을 AAC로 변환하는 메서드
    private func convertToAAC(inputPath: String, result: @escaping FlutterResult) {
        let documentsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let outputFileName = "audio_\(Int(Date().timeIntervalSince1970)).m4a"
        let outputURL = documentsDirectory.appendingPathComponent(outputFileName)
        
        // 입력 파일의 URL 생성
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // AVAsset을 통해 오디오 파일 로드
        let asset = AVAsset(url: inputURL)
        
        // AVAssetExportSession 생성 (presetName: AVAssetExportPresetMediumQuality 사용)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            result(FlutterError(code: "EXPORT_SESSION_ERROR",
                                message: "Failed to create export session",
                                details: nil))
            return
        }
        
        // 출력 URL 및 파일 타입 지정
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // 비동기 내보내기 시작
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    result(outputURL.path)
                case .failed, .cancelled:
                    result(FlutterError(code: "EXPORT_ERROR",
                                        message: exportSession.error?.localizedDescription ?? "Unknown export error",
                                        details: nil))
                default:
                    result(FlutterError(code: "EXPORT_UNKNOWN",
                                        message: "Unknown export status",
                                        details: nil))
                }
            }
        }
    }
}
