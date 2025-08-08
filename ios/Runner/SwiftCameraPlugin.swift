import Flutter
import UIKit
import AVFoundation

// 간단한 카메라 플러그인 구현
public class SwiftCameraPlugin: NSObject, FlutterPlugin, AVCapturePhotoCaptureDelegate {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var currentDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var isUsingFrontCamera: Bool = false
    var photoCaptureResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 플랫폼 채널 등록 및 핸들러 설정
        let channel = FlutterMethodChannel(name: "com.soi.camera", binaryMessenger: registrar.messenger())
        let instance = SwiftCameraPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // 카메라 초기화
        instance.setupCamera()
        
        // 플랫폼 뷰 등록 - nil 체크 추가
        guard let captureSession = instance.captureSession else {
            print("경고: 카메라 세션이 초기화되지 않았습니다")
            return
        }
        
        // 플랫폼 뷰 팩토리 등록
        registrar.register(
            CameraPreviewFactory(captureSession: captureSession),
            withId: "com.soi.camera/preview"
        )
    }
    
    // 기본 카메라 설정
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // 기본 후면 카메라 설정
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            currentDevice = device
            beginSession()
        }
    }
    
    // 카메라 세션 시작
    func beginSession() {
        guard let session = captureSession, let device = currentDevice else { return }
        
        do {
            // 카메라 입력 설정
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            // 사진 출력 설정
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                // 사진 출력 연결에는 미러링 적용하지 않음 (원본 이미지 유지)
                if let connection = photoOutput.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false  // 사진은 미러링 없이
                        print("🔧 사진 출력 연결 미러링 비활성화 (원본 이미지 보존)")
                    }
                }
            }
            
            // 세션 시작
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                
                // 세션 시작 후 미러링 적용
                DispatchQueue.main.async {
                    self.applyMirroringToAllConnections()
                }
            }
        } catch {
            print("카메라 세션 설정 오류: \(error)")
        }
    }
    
    // 플랫폼 채널 메서드 처리
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            initCamera(result: result)
        case "takePicture":
            takePicture(result: result)    
        case "switchCamera":
            switchCamera(result: result)
        case "setFlash":
            setFlash(call: call, result: result)
        case "pauseCamera":
            pauseCamera(result: result)
        case "resumeCamera":
            resumeCamera(result: result)
        case "disposeCamera":
            disposeCamera(result: result)
        case "optimizeCamera":
            optimizeCamera(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // 카메라 초기화
    func initCamera(result: @escaping FlutterResult) {
        if captureSession == nil {
            setupCamera()
        }
        result("Camera initialized")
    }
    
    // 사진 촬영
    func takePicture(result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not available", details: nil))
            return
        }
        
        // 사진 촬영 설정
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        // 전면 카메라인 경우 특별한 설정 추가
        if currentDevice?.position == .front {
            print("🔧 전면 카메라 설정 적용")
            // 필요시 전면 카메라 전용 설정 추가
        }
        
        print("📸 사진 촬영 시작 - 출력 미러링 비활성화 상태")
        photoCaptureResult = result
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // 사진 촬영 완료 처리
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureResult?(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        
        // 이미지 데이터 얻기
        guard let imageData = photo.fileDataRepresentation() else {
            photoCaptureResult?(FlutterError(code: "NO_IMAGE_DATA", message: "Could not get image data", details: nil))
            return
        }
        
        // 현재 카메라 위치 직접 확인
        let isFrontCamera = currentDevice?.position == .front
        print("🔍 현재 카메라 위치: \(isFrontCamera ? "전면" : "후면")")
        
        // UIImage로 변환
        guard let originalImage = UIImage(data: imageData) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_CONVERSION_ERROR", message: "Could not convert image data to UIImage", details: nil))
            return
        }
        
        print("📸 원본 이미지 크기: \(originalImage.size)")
        print("📸 원본 이미지 orientation: \(originalImage.imageOrientation.rawValue)")
        
        // 이미지 방향 및 반전 처리
        var finalImage: UIImage = originalImage
        
        // 모든 카메라에서 원본 이미지 그대로 사용 (좌우반전 해제)
        print("📸 \(isFrontCamera ? "전면" : "후면") 카메라: 원본 이미지 사용 (좌우반전 해제)")
        
        // 처리된 이미지를 JPEG 데이터로 변환
        guard let processedImageData = finalImage.jpegData(compressionQuality: 0.9) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_PROCESSING_ERROR", message: "Could not convert processed image to JPEG", details: nil))
            return
        }
        
        // 임시 파일로 저장
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/\(UUID().uuidString).jpg"
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try processedImageData.write(to: fileURL)
            photoCaptureResult?(filePath)
            print("✅ 이미지 저장 완료: \(filePath)")
        } catch {
            photoCaptureResult?(FlutterError(code: "FILE_SAVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // 이미지 좌우반전 처리 - 최종 개선 버전
    func flipImageHorizontally(_ image: UIImage) -> UIImage {
        // 1. UIImage orientation 방법 시도
        if let cgImage = image.cgImage {
            let flippedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: .upMirrored)
            print("✅ 이미지 좌우반전 완료 (UIImage orientation 방법)")
            return flippedImage
        }
        
        // 2. Core Graphics 방법으로 폴백
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = image.cgImage else {
            print("⚠️ 좌우반전 실패 - 원본 이미지 반환")
            return image
        }
        
        // 좌우반전 변환 적용
        context.translateBy(x: image.size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        
        // 이미지 그리기
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        
        guard let flippedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("⚠️ Core Graphics 좌우반전 실패 - 원본 이미지 반환")
            return image
        }
        
        print("✅ 이미지 좌우반전 완료 (Core Graphics 방법)")
        return flippedImage
    }
    
    // 후면 카메라 방향 수정 (상하 반전 해결)
    func fixBackCameraOrientation(_ image: UIImage) -> UIImage {
        // 원본 이미지의 방향 확인
        let originalOrientation = image.imageOrientation
        print("📸 후면 카메라 원본 방향: \(originalOrientation.rawValue)")
        
        guard let cgImage = image.cgImage else {
            print("⚠️ 후면 카메라 방향 수정 실패 - 원본 이미지 반환")
            return image
        }
        
        // 이미 올바른 방향이면 그대로 반환
        if originalOrientation == .up {
            print("✅ 후면 카메라 이미 올바른 방향")
            return image
        }
        
        // Core Graphics를 사용하여 이미지를 올바른 방향으로 그리기
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        guard let correctedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("⚠️ 후면 카메라 방향 수정 실패 - 원본 이미지 반환")
            return image
        }
        
        print("✅ 후면 카메라 방향 수정 완료")
        return correctedImage
    }
    
    // 프리뷰 연결에만 미러링 적용 (사진 출력 제외)
    func applyMirroringToAllConnections() {
        guard let captureSession = captureSession else { return }
        
        // 현재 카메라 타입 확인
        let isFrontCamera = currentDevice?.position == .front
        
        // 모든 출력의 연결을 확인하고 적절히 미러링 적용
        for output in captureSession.outputs {
            // 사진 출력은 항상 미러링 비활성화 (원본 이미지 유지)
            if output is AVCapturePhotoOutput {
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                        print("🔧 사진 출력 연결 미러링 비활성화")
                    }
                }
            } else {
                // 프리뷰 출력은 전면 카메라에서만 미러링 활성화
                for connection in output.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = isFrontCamera
                        print("🔧 프리뷰 출력 연결 미러링: \(isFrontCamera ? "전면 카메라 - 활성화" : "후면 카메라 - 비활성화")")
                    }
                }
            }
        }
    }
    
    // 카메라 전환
    func switchCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession,
              let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            result(FlutterError(code: "NO_CAMERA", message: "No current camera", details: nil))
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        // 전/후면 카메라 전환
        isUsingFrontCamera.toggle()
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) {
            currentDevice = newDevice
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                }
            } catch {
                result(FlutterError(code: "SWITCH_ERROR", message: error.localizedDescription, details: nil))
                captureSession.commitConfiguration()
                return
            }
        }
        
        captureSession.commitConfiguration()
        
        // 카메라 전환 후 미러링 설정 다시 적용
        applyMirroringToAllConnections()
        
        result("Camera switched")
    }
    
    // 플래시 설정
    func setFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let isOn = args["isOn"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing or invalid isOn parameter", details: nil))
            return
        }
        
        flashMode = isOn ? .on : .off
        result("Flash set to \(isOn ? "on" : "off")")
    }
    
    // 카메라 세션 일시 중지
    func pauseCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        result("Camera paused")
    }
    
    // 카메라 세션 재개
    func resumeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
        
        result("Camera resumed")
    }
    
    // 카메라 리소스 해제
    func disposeCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "SESSION_ERROR", message: "Camera session is not initialized", details: nil))
            return
        }
        
        captureSession.stopRunning()
        result("Camera disposed")
    }
    
    // 카메라 최적화 - 간단한 구현
    func optimizeCamera(result: @escaping FlutterResult) {
        guard let currentDevice = currentDevice else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        
        do {
            try currentDevice.lockForConfiguration()
            
            // 자동 초점 설정
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                currentDevice.focusMode = .continuousAutoFocus
            }
            
            // 자동 노출 설정
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
            }
            
            currentDevice.unlockForConfiguration()
            result("Camera optimized")
        } catch {
            result(FlutterError(code: "OPTIMIZATION_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - 이미지 처리 헬퍼 메서드
}

// 카메라 미리보기를 위한 플랫폼 뷰 팩토리
class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let captureSession: AVCaptureSession
    
    init(captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraPreviewView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            captureSession: captureSession
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// 미리보기 뷰 레이어 클래스
class PreviewView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer as? AVCaptureVideoPreviewLayer {
            layer.videoGravity = .resizeAspectFill
            layer.connection?.videoOrientation = .portrait
            
            // 카메라 타입에 따른 미러링 설정
            if let connection = layer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                
                // 전면 카메라에서만 좌우반전 활성화
                if let session = layer.session {
                    var isFrontCamera = false
                    for input in session.inputs {
                        if let deviceInput = input as? AVCaptureDeviceInput {
                            isFrontCamera = deviceInput.device.position == .front
                            break
                        }
                    }
                    connection.isVideoMirrored = isFrontCamera
                    print("🔧 PreviewView 미러링: \(isFrontCamera ? "전면 카메라 - 활성화" : "후면 카메라 - 비활성화")")
                }
            }
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

// 카메라 미리보기 플랫폼 뷰
class CameraPreviewView: NSObject, FlutterPlatformView {
    private var _view: PreviewView
    
    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
        _view = PreviewView(frame: frame)
        super.init()
        
        // 뷰 레이어 설정
        if let previewLayer = _view.layer as? AVCaptureVideoPreviewLayer {
            previewLayer.session = captureSession
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            
            // 카메라 타입에 따른 미러링 설정
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                
                // 현재 입력된 카메라 타입 확인
                var isFrontCamera = false
                for input in captureSession.inputs {
                    if let deviceInput = input as? AVCaptureDeviceInput {
                        isFrontCamera = deviceInput.device.position == .front
                        break
                    }
                }
                
                // 전면 카메라에서만 미러링 활성화
                connection.isVideoMirrored = isFrontCamera
                print("🔧 CameraPreviewView 미러링: \(isFrontCamera ? "전면 카메라 - 활성화" : "후면 카메라 - 비활성화")")
            }
        }
        
        _view.frame = frame
        _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 세션이 실행 중이 아니면 시작
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    func view() -> UIView {
        return _view
    }
}
