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
        // 출력 파일 형식을 m4a로 변경
        let outputFileName = "audio_\(Int(Date().timeIntervalSince1970)).m4a"
        let outputURL = documentsDirectory.appendingPathComponent(outputFileName)
        
        // 입력 파일이 존재하는지 확인
        if !FileManager.default.fileExists(atPath: inputPath) {
            result(FlutterError(code: "FILE_NOT_FOUND",
                                message: "Input file not found: \(inputPath)",
                                details: nil))
            return
        }
        
        // 입력 파일의 URL 생성
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // 기존 출력 파일 삭제
        try? FileManager.default.removeItem(at: outputURL)
        
        // AVAsset을 통해 오디오 파일 로드
        let asset = AVAsset(url: inputURL)
        
        // AVAssetExportSession 생성 (presetName 변경)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            result(FlutterError(code: "EXPORT_SESSION_ERROR",
                                message: "Failed to create export session",
                                details: nil))
            return
        }
        
        // 출력 URL 및 파일 타입 지정
        exportSession.outputURL = outputURL
        
        // m4a 파일 타입 사용 - 넓리 지원되는 안전한 옵션
        exportSession.outputFileType = AVFileType.m4a
        
        // 오류 확인 및 디버깅
        // print("Input file exists: \(FileManager.default.fileExists(atPath: inputPath))")
        // print("Input file path: \(inputPath)")
        // print("Output file path: \(outputURL.path)")
        
        // 비동기 내보내기 시작
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                if let error = exportSession.error {
                    // print("Export error: \(error.localizedDescription)")
                }
                
                switch exportSession.status {
                case .completed:
                    // print("Export completed successfully: \(outputURL.path)")
                    result(outputURL.path)
                case .failed:
                    let errorMsg = exportSession.error?.localizedDescription ?? "Export failed without error"
                    // print("Export failed: \(errorMsg)")
                    result(FlutterError(code: "EXPORT_ERROR",
                                        message: errorMsg,
                                        details: nil))
                case .cancelled:
                    result(FlutterError(code: "EXPORT_CANCELLED",
                                        message: "Export was cancelled",
                                        details: nil))
                default:
                    let statusStr = "\(exportSession.status.rawValue)"
                    // print("Unknown export status: \(statusStr)")
                    result(FlutterError(code: "EXPORT_UNKNOWN",
                                        message: "Unknown export status: \(statusStr)",
                                        details: nil))
                }
            }
        }
    }
}
