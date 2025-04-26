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
            if let photoOutput = photoOutput {
                // iOS 11 이상에서 고해상도 캡처 허용
                if #available(iOS 11.0, *) {
                    photoOutput.isHighResolutionCaptureEnabled = true
                }
                // 출력 추가
                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                }
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
        case "optimizeCamera":
            optimizeCamera(result: result)
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
        
        // 수정된 이미지 설정 - 컬러 스페이스와 포맷 설정 추가
        let settings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: AVVideoCodecType.jpeg
        ])
        
        // HEIF 대신 JPEG 사용 (iOS 11 이상)
        if #available(iOS 11.0, *) {
            settings.previewPhotoFormat = nil // 불필요한 프리뷰 설정 제거
            
            // 고품질 이미지 설정
            settings.isHighResolutionPhotoEnabled = true
            
            // 자동 이미지 처리 설정
            if #available(iOS 13.0, *) {
                // 최대 허용 우선순위를 넘지 않도록 설정
                let maxPriority = photoOutput.maxPhotoQualityPrioritization
                if maxPriority.rawValue >= AVCapturePhotoOutput.QualityPrioritization.quality.rawValue {
                    settings.photoQualityPrioritization = .quality
                } else {
                    settings.photoQualityPrioritization = maxPriority
                }
            }
        }
        
        // 플래시 설정
        if currentDevice?.hasFlash == true {
            settings.flashMode = flashMode
        }
        
        // 디바이스 자동 설정 적용
        if let currentDevice = currentDevice {
            do {
                try currentDevice.lockForConfiguration()
                
                // 자동 화이트 밸런스 설정
                if currentDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    currentDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                
                // 자동 노출 설정
                if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                    currentDevice.exposureMode = .continuousAutoExposure
                }
                
                // 자동 초점 설정
                if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                    currentDevice.focusMode = .continuousAutoFocus
                }
                
                currentDevice.unlockForConfiguration()
            } catch {
                print("카메라 설정 실패: \(error)")
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
        
        // 색상 처리가 개선된 이미지 데이터 획득 방식
        var imageData: Data?
        
        if #available(iOS 11.0, *) {
            // 수정: sRGB 색상 공간으로 변환된 이미지 데이터 생성
            if let cgImage = photo.cgImageRepresentation() {
                // 이미지 방향 수정: 전면 카메라의 경우 좌우 반전 적용
                let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
                
                // 색상 처리 방식 변경
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                
                // RGB 색상 채널 균형 조정
                let ciImage = CIImage(cgImage: cgImage)
                let filter = CIFilter(name: "CIColorControls")
                filter?.setValue(ciImage, forKey: kCIInputImageKey)
                filter?.setValue(1.0, forKey: kCIInputSaturationKey) // 색상 포화도 정상화
                filter?.setValue(0.0, forKey: kCIInputBrightnessKey) // 밝기 조정 없음
                
                if let outputImage = filter?.outputImage {
                    let context = CIContext()
                    if let processedCGImage = context.createCGImage(outputImage, from: outputImage.extent) {
                        let processedUIImage = UIImage(cgImage: processedCGImage, scale: 1.0, orientation: orientation)
                        imageData = processedUIImage.jpegData(compressionQuality: 1.0)
                    }
                } else {
                    imageData = uiImage.jpegData(compressionQuality: 1.0)
                }
            } else {
                // 기본 JPEG 데이터 사용 (fallback)
                imageData = photo.fileDataRepresentation()
            }
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
    
    // ✅ 추가: 카메라 최적화 메서드
    func optimizeCamera(result: @escaping FlutterResult) {
        guard let currentDevice = currentDevice else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }
        
        do {
            try currentDevice.lockForConfiguration()
            
            // 자동 화이트 밸런스 설정
            if currentDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                currentDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // 자동 노출 설정
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
                
                // 노출 보정 설정 (약간 밝게)
                if currentDevice.isExposurePointOfInterestSupported {
                    currentDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                    
                    if currentDevice.exposureMode == .continuousAutoExposure || 
                       currentDevice.exposureMode == .autoExpose {
                        // 약간 밝게 조정 (0.0이 기본값, 양수는 밝게, 음수는 어둡게)
                        currentDevice.setExposureTargetBias(0.3, completionHandler: nil)
                    }
                }
            }
            
            // 자동 초점 설정
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                currentDevice.focusMode = .continuousAutoFocus
                if currentDevice.isFocusPointOfInterestSupported {
                    currentDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
            }
            
            // 성능 향상 설정: iOS 15 이상에서 고품질 사진 포맷 선택
            if #available(iOS 15.0, *) {
                let formats = currentDevice.formats
                if let bestFormat = formats.first(where: { format in
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video &&
                           dimensions.width >= 1920 && dimensions.height >= 1080 &&
                           format.isHighPhotoQualitySupported
                }) {
                    currentDevice.activeFormat = bestFormat
                }
            } else {
                // iOS 12~14: 해상도 기준으로 포맷 선택
                let formats = currentDevice.formats
                if let fallbackFormat = formats.first(where: { format in
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return CMFormatDescriptionGetMediaType(format.formatDescription) == kCMMediaType_Video &&
                           dimensions.width >= 1920 && dimensions.height >= 1080
                }) {
                    currentDevice.activeFormat = fallbackFormat
                }
            }
            
            // 캡처 품질 우선 설정
            currentDevice.unlockForConfiguration()
            result("Camera optimized")
        } catch {
            result(FlutterError(code: "OPTIMIZATION_ERROR", message: error.localizedDescription, details: nil))
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
    if let layer = layer as? AVCaptureVideoPreviewLayer {
      layer.videoGravity = .resizeAspectFill
      layer.connection?.videoOrientation = .portrait
      
      // 개선된 품질 설정 추가
      layer.contentsScale = UIScreen.main.scale  // 디스플레이 스케일에 맞추기
      layer.minificationFilter = .trilinear       // 품질 향상을 위한 필터 적용
      layer.magnificationFilter = .trilinear      // 품질 향상을 위한 필터 적용
    }
  }
  
  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
}

class CameraPreviewView: NSObject, FlutterPlatformView {
  private var _view: PreviewView
  private var previewLayer: AVCaptureVideoPreviewLayer?

  init(frame: CGRect, viewIdentifier: Int64, arguments args: Any?, captureSession: AVCaptureSession) {
    _view = PreviewView(frame: frame)
    super.init()
    
    // 매개변수 확인
    var useSRGBColorSpace = false
    if let argsDict = args as? [String: Any], let colorSpace = argsDict["useSRGBColorSpace"] as? Bool {
      useSRGBColorSpace = colorSpace
    }
    
    // 캡처 세션 품질 설정 개선
    if captureSession.sessionPreset != .photo {
        captureSession.sessionPreset = .photo
    }
    
    previewLayer = _view.layer as? AVCaptureVideoPreviewLayer
    previewLayer?.session = captureSession
    previewLayer?.videoGravity = .resizeAspectFill
    previewLayer?.connection?.videoOrientation = .portrait
    
    // 미리보기 품질 향상 설정
    previewLayer?.contentsScale = UIScreen.main.scale * 2  // 고해상도 설정
    previewLayer?.minificationFilter = .trilinear
    previewLayer?.magnificationFilter = .trilinear
    
    _view.frame = frame
    _view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    if !captureSession.isRunning {
      DispatchQueue.global(qos: .userInitiated).async { captureSession.startRunning() }
    }
  }

  func view() -> UIView { _view }
}
