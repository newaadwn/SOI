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
        
        // 기본 설정으로 사진 촬영
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
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
        
        // 임시 파일로 저장
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/\(UUID().uuidString).jpg"
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try imageData.write(to: fileURL)
            photoCaptureResult?(filePath)
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
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

// 카메라 미리보기 플랫폼 뷰
class CameraPreviewView: NSObject, FlutterPlatformView {
    private var _view: PreviewView
    private var methodChannel: FlutterMethodChannel?
    private var captureSession: AVCaptureSession
    private var photoOutput: AVCapturePhotoOutput?
    private var photoCaptureResult: FlutterResult?
    
    init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
        self.captureSession = captureSession
        _view = PreviewView(frame: frame)
        super.init()
        
        // 메서드 채널 설정
        if let messenger = FlutterEngine().binaryMessenger {
            methodChannel = FlutterMethodChannel(name: "com.soi.camera/preview_\(viewIdentifier)", binaryMessenger: messenger)
            methodChannel?.setMethodCallHandler { [weak self] call, result in
                self?.handleMethodCall(call, result: result)
            }
        }
        
        // 뷰 레이어 설정
        if let previewLayer = _view.layer as? AVCaptureVideoPreviewLayer {
            previewLayer.session = captureSession
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
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
    
    // 메서드 호출 처리
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initCamera":
            result(true)
        case "isSessionActive":
            result(captureSession.isRunning)
        case "refreshPreview":
            result(true)
        case "takePicture":
            takePicture(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // 사진 촬영
    private func takePicture(result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput else {
            // PhotoOutput이 없으면 생성
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
        }
        
        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not available", details: nil))
            return
        }
        
        // 기본 설정으로 사진 촬영
        let settings = AVCapturePhotoSettings()
        photoCaptureResult = result
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func view() -> UIView {
        return _view
    }
}

// AVCapturePhotoCaptureDelegate 확장
extension CameraPreviewView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureResult?(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            return
        }
        
        // 이미지 데이터 얻기
        guard let imageData = photo.fileDataRepresentation() else {
            photoCaptureResult?(FlutterError(code: "NO_IMAGE_DATA", message: "Could not get image data", details: nil))
            return
        }
        
        // 임시 파일로 저장
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "/\(UUID().uuidString).jpg"
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try imageData.write(to: fileURL)
            photoCaptureResult?(filePath)
        } catch {
            photoCaptureResult?(FlutterError(code: "FILE_SAVE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
