import Flutter
import UIKit
import AVFoundation

// MARK: - Plugin Main Class
public class SwiftCameraPlugin: NSObject, FlutterPlugin, AVCapturePhotoCaptureDelegate {
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var currentDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var isUsingFrontCamera: Bool = false
    var photoCaptureResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // 플랫폼 채널 생성 및 Flutter와 통신 준비
        let channel = FlutterMethodChannel(name: "com.soi.camera", binaryMessenger: registrar.messenger())
        let instance = SwiftCameraPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
       // ✅ 수정: 먼저 카메라 세션을 확실히 초기화
        instance.setupCamera()
    
    // ✅ 수정: nil 체크 추가 및 등록 확인
        guard let captureSession = instance.captureSession else {
            print("⚠️ 에러: captureSession이 nil입니다! PlatformView를 등록할 수 없습니다.")
            return
        }
        
        // ✅ 추가: PlatformView 등록 - UiKitView에서 사용할 뷰 팩토리 등록
        registrar.register(
            CameraPreviewFactory(captureSession: instance.captureSession!),
            withId: "com.soi.camera/preview"
        )
    }
    
    // 카메라 세션 구성
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // 기본 카메라 (후면) 선택
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            currentDevice = device
            beginSession()
        }
    }
    
    // 캡처 세션 시작
    func beginSession() {
        guard let captureSession = captureSession, let device = currentDevice else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            captureSession.startRunning()
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }
    
    // 플랫폼 채널 호출 처리
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "takePicture":
            takePicture(result: result)
        case "switchCamera":
            switchCamera(result: result)
        case "toggleFlash":
            toggleFlash(result: result)
        case "openCameraPreview":
            // 모달 방식으로 카메라 프리뷰 띄우기
            openCameraPreview(result: result)
        case "initCamera":
            initCamera(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ✅ 추가: 카메라 초기화 메서드
    func initCamera(result: @escaping FlutterResult) {
        // 이미 setupCamera에서 초기화되었으므로 성공 반환
        if captureSession == nil {
            setupCamera()
        }
        result("Camera initialized")
    }   
    
    // 촬영 기능
    func takePicture(result: @escaping FlutterResult) {
        guard let photoOutput = self.photoOutput else {
            result(FlutterError(code: "NO_PHOTO_OUTPUT", message: "Photo output not available", details: nil))
            return
        }
        
        // 수정된 이미지 설정
        let settings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: AVVideoCodecType.jpeg,
            AVVideoCompressionPropertiesKey: [
                AVVideoQualityKey: 0.9
            ]
        ])
        
        // HEIF 대신 JPEG 사용 (iOS 11 이상)
        if #available(iOS 11.0, *) {
            // ✅ 수정: 중복 키 제거 (kCVPixelBufferPixelFormatTypeKey와 "PixelFormatType"이 동일함)
            settings.previewPhotoFormat = [
                "Width" as String: 1280,
                "Height" as String: 720,
                "PixelFormatType" as String: kCVPixelFormatType_32BGRA
            ]
        }
        
        if currentDevice?.hasFlash == true {
            settings.flashMode = flashMode
        }
        
        // 자동 화이트 밸런스 설정
        if let currentDevice = currentDevice, currentDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            do {
                try currentDevice.lockForConfiguration()
                currentDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                currentDevice.unlockForConfiguration()
            } catch {
                print("화이트 밸런스 설정 실패: \(error)")
            }
        }
        
        photoCaptureResult = result
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // 촬영 완료 후 델리게이트 메서드
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if let error = error {
        photoCaptureResult?(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
        return
    }
    
    // 단순화된 이미지 처리 방식 사용
    var imageData: Data?
    
    if #available(iOS 11.0, *) {
        // 직접 JPEG 데이터 사용
        imageData = photo.fileDataRepresentation()
    } else {
        imageData = photo.fileDataRepresentation()
    }
    
    guard let imageData = imageData else {
        photoCaptureResult?(FlutterError(code: "NO_IMAGE_DATA", message: "Could not get image data", details: nil))
        return
    }
    
    // 임시 디렉토리에 이미지 저장
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
    
    // 카메라 전환 기능 (후면 <-> 전면)
    func switchCamera(result: @escaping FlutterResult) {
        guard let captureSession = captureSession,
              let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            result(FlutterError(code: "NO_CAMERA", message: "No current camera", details: nil))
            return
        }
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
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
    
    // 플래시 토글 기능 (on/off)
    func toggleFlash(result: @escaping FlutterResult) {
        flashMode = (flashMode == .off) ? .on : .off
        result("Flash toggled")
    }
    
    // 모달 방식으로 카메라 프리뷰를 띄우는 메서드
    func openCameraPreview(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            // 루트 뷰 컨트롤러 가져오기
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                // CameraViewController 인스턴스 생성 (아래의 CameraViewController.swift 참고)
                let cameraVC = CameraViewController()
                cameraVC.modalPresentationStyle = .fullScreen // 전체 화면으로 표시
                rootVC.present(cameraVC, animated: true) {
                    result("Camera preview opened")
                }
            } else {
                result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller available", details: nil))
            }
        }
    }
}

// MARK: - Platform View 구현

// ✅ 추가: 카메라 프리뷰를 위한 플랫폼 뷰 팩토리
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

// ➊ PreviewView 정의
class PreviewView: UIView {
  override func layoutSubviews() {
    super.layoutSubviews()
    (layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = bounds
  }
}

class CameraPreviewView: NSObject, FlutterPlatformView {
  private var _view: PreviewView
  private var previewLayer: AVCaptureVideoPreviewLayer?

  init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
    _view = PreviewView(frame: frame)
    super.init()

    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer?.videoGravity = .resizeAspectFill
    previewLayer?.frame = _view.bounds
    if let layer = previewLayer { _view.layer.addSublayer(layer) }

    if !captureSession.isRunning {
      DispatchQueue.global(qos: .userInitiated).async { captureSession.startRunning() }
    }
    _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  func view() -> UIView { _view }
}
