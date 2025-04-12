import UIKit
import AVFoundation

// 카메라 프리뷰를 위한 UIViewController
class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var photoOutput: AVCapturePhotoOutput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupCloseButton()
    }
    
    // 카메라 세션 및 프리뷰 레이어 설정
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // 후면 카메라 선택
        guard let captureSession = captureSession,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: Unable to access back camera.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
            
            // 프리뷰 레이어 설정
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds
            if let layer = previewLayer {
                view.layer.addSublayer(layer)
            }
            
            // 캡처 세션 시작
            captureSession.startRunning()
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    // 뷰 레이아웃 변경 시 프리뷰 레이어 프레임 업데이트
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    // 닫기 버튼 추가
    func setupCloseButton() {
        let closeButton = UIButton(frame: CGRect(x: 20, y: 40, width: 60, height: 30))
        closeButton.setTitle("닫기", for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.1, alpha: 0.7)
        closeButton.layer.cornerRadius = 5
        closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        view.addSubview(closeButton)
    }
    
    // 카메라 프리뷰 닫기
    @objc func closeCamera() {
        captureSession?.stopRunning()
        dismiss(animated: true, completion: nil)
    }
    
    // 필요 시 사진 촬영 등 추가 기능 구현 가능
}
