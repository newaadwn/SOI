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
            }
            
            // 세션 시작
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
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
        
        // 현재 카메라 위치 직접 확인 (상태 변수 대신)
        let isFrontCamera = currentDevice?.position == .front
        print("🔍 현재 카메라 위치: \(currentDevice?.position == .front ? "전면" : "후면")")
        print("🔍 isUsingFrontCamera 변수: \(isUsingFrontCamera)")
        print("🔍 실제 디바이스 position: \(currentDevice?.position.rawValue ?? -1)")
        
        // UIImage로 변환
        guard let originalImage = UIImage(data: imageData) else {
            photoCaptureResult?(FlutterError(code: "IMAGE_CONVERSION_ERROR", message: "Could not convert image data to UIImage", details: nil))
            return
        }
        
        // 모든 카메라에서 원본 이미지 그대로 사용 (좌우반전 처리 안함)
        let finalImage: UIImage = originalImage
        
        if isFrontCamera {
            print("📸 전면 카메라 촬영 - 원본 이미지 사용 (좌우반전 없음)")
        } else {
            print("📸 후면 카메라 촬영 - 원본 이미지 사용")
        }
        
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
    
    /// 이미지를 좌우반전시키는 메서드 (전면 카메라 미리보기와 일치시키기 위함)
    private func flipImageHorizontally(_ image: UIImage) -> UIImage {
        // Core Graphics를 사용한 이미지 좌우반전
        guard let cgImage = image.cgImage else {
            print("⚠️ CGImage 변환 실패 - 원본 이미지 반환")
            return image
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // 색상 공간 및 비트맵 컨텍스트 생성
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("⚠️ CGContext 생성 실패 - 원본 이미지 반환")
            return image
        }
        
        // 좌우반전 변환 적용
        context.scaleBy(x: -1.0, y: 1.0)
        context.translateBy(x: -CGFloat(width), y: 0)
        
        // 이미지 그리기
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 새로운 CGImage 생성
        guard let flippedCGImage = context.makeImage() else {
            print("⚠️ 좌우반전된 CGImage 생성 실패 - 원본 이미지 반환")
            return image
        }
        
        // UIImage로 변환하여 반환
        let flippedImage = UIImage(
            cgImage: flippedCGImage,
            scale: image.scale,
            orientation: image.imageOrientation
        )
        
        print("✅ 이미지 좌우반전 처리 완료 - 미리보기와 일치")
        return flippedImage
    }
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
            
            // 전면 카메라일 때 거울 모드 설정
            if let connection = layer.connection {
                // 전면 카메라일 때 거울 모드 활성화 (자연스러운 셀피 미리보기)
                if connection.isVideoMirroringSupported {
                    // 자동 거울 모드를 먼저 비활성화
                    if connection.automaticallyAdjustsVideoMirroring {
                        connection.automaticallyAdjustsVideoMirroring = false
                    }
                    
                    // 카메라 위치 확인
                    if let inputs = (layer.session?.inputs as? [AVCaptureDeviceInput]) {
                        let isFront = inputs.first?.device.position == .front
                        connection.isVideoMirrored = isFront
                        print("🔧 미리보기 거울 모드: \(isFront ? "활성화" : "비활성화")")
                    }
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
            
            // 전면 카메라일 때 거울 모드 활성화
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                // 자동 거울 모드를 먼저 비활성화
                if connection.automaticallyAdjustsVideoMirroring {
                    connection.automaticallyAdjustsVideoMirroring = false
                }
                
                // 카메라 위치 확인 후 거울 모드 설정
                if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                    let isFront = inputs.first?.device.position == .front
                    connection.isVideoMirrored = isFront
                    print("🔧 카메라 미리보기 거울 모드: \(isFront ? "활성화" : "비활성화")")
                }
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
