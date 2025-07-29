import UIKit
import Flutter
import Firebase
import FirebaseAuth
import UserNotifications
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase 초기화 먼저
    FirebaseApp.configure()
    
    // ⭐ Firebase 초기화 후 설정 정보 확인
    if let app = FirebaseApp.app() {
        let options = app.options
        print("🔥 Firebase 초기화 완료")
        print("🔥 프로젝트 ID: \(options.projectID ?? "Unknown")")
        print("🔥 Bundle ID: \(options.bundleID ?? "Unknown")")
        print("🔥 API Key: \(String(options.apiKey?.prefix(10) ?? "Unknown"))...")
    }
    
    // ⭐ Firebase Auth 설정 강화 (reCAPTCHA 우회)
    let authSettings = Auth.auth().settings
    authSettings?.isAppVerificationDisabledForTesting = false
    
    // ⭐ 추가: reCAPTCHA 우회를 위한 설정
    #if DEBUG
    // 개발 환경에서는 테스트 모드 활성화
    authSettings?.isAppVerificationDisabledForTesting = true
    print("🔧 DEBUG 모드: 앱 검증 비활성화 (테스트용)")
    #else
    print("🚀 RELEASE 모드: 실제 APNs 토큰 사용")
    #endif
    
    // 추가 설정: Silent Push를 위해 reCAPTCHA 대신 APNs 토큰 사용
    if #available(iOS 13.0, *) {
      // iOS 13 이상에서 백그라운드 refresh 활성화
      application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    // APNs 알림 권한 요청
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { (granted, error) in
          if granted {
            print("Notification permission granted")
            DispatchQueue.main.async {
              application.registerForRemoteNotifications()
            }
          } else {
            print("Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
          }
        }
      )
    }
    
    // 앱 시작 시 바로 APNs 토큰 등록
    application.registerForRemoteNotifications()
    
    // 1️⃣ SwiftCameraPlugin 먼저 등록
    SwiftCameraPlugin.register(with: self.registrar(forPlugin: "com.soi.camera")!)
    
    // SwiftAudioConverter 등록
    SwiftAudioConverter.register(with: self.registrar(forPlugin: "SwiftAudioConverter")!)
    
    // 네이티브 오디오 녹음 MethodChannel 설정
    let controller = window?.rootViewController as! FlutterViewController
    let audioChannel = FlutterMethodChannel(name: "native_recorder", binaryMessenger: controller.binaryMessenger)
    let audioRecorder = NativeAudioRecorder()
    
    audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "checkMicrophonePermission":
        audioRecorder.checkMicrophonePermission(result: result)
      case "requestMicrophonePermission":
        audioRecorder.requestMicrophonePermission(result: result)
      case "startRecording":
        if let args = call.arguments as? [String: Any],
           let filePath = args["filePath"] as? String {
          audioRecorder.startRecording(filePath: filePath, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        }
      case "stopRecording":
        audioRecorder.stopRecording(result: result)
      case "isRecording":
        audioRecorder.isRecording(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 2️⃣ 모든 플러그인 등록 (firebase_core 등)
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let firebaseAuth = Auth.auth()
      
      // ⭐ APNs 토큰 설정 강화
      let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
      print("📱 APNs Token received: \(tokenString)")
      
      // ⭐ Firebase 프로젝트 정보 확인
      if let options = FirebaseApp.app()?.options {
          print("🔥 Firebase 프로젝트 ID: \(options.projectID ?? "Unknown")")
          print("🔥 Firebase Bundle ID: \(options.bundleID ?? "Unknown")")
      }
      
      // Production/Development 환경 구분
      #if DEBUG
      firebaseAuth.setAPNSToken(deviceToken, type: AuthAPNSTokenType.sandbox)
      print("🔧 APNs Token set for SANDBOX environment")
      print("🔧 개발 환경에서는 Firebase 콘솔의 Development APNs 키가 사용됩니다.")
      #else
      firebaseAuth.setAPNSToken(deviceToken, type: AuthAPNSTokenType.prod)
      print("🚀 APNs Token set for PRODUCTION environment")
      print("🚀 운영 환경에서는 Firebase 콘솔의 Production APNs 키가 사용됩니다.")
      #endif
      
      // ⭐ APNs 설정 상태 확인
      print("✅ APNs Token이 Firebase Auth에 등록되었습니다.")
      print("💡 reCAPTCHA 없이 SMS 인증이 가능해야 합니다.")
      print("💡 만약 여전히 reCAPTCHA가 나타난다면:")
      print("   1. Firebase 콘솔에서 APNs 키 설정 확인")
      print("   2. Bundle ID 일치 여부 확인")
      print("   3. Team ID 일치 여부 확인")
      print("   4. 설정 적용까지 최대 1시간 대기")
  }
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      let firebaseAuth = Auth.auth()
      if (firebaseAuth.canHandleNotification(userInfo)){
          print(userInfo)
          completionHandler(UIBackgroundFetchResult.newData)
          return
      }
      completionHandler(UIBackgroundFetchResult.noData)
  }
  
  // Phone Auth에서 reCAPTCHA를 위한 URL 스킴 처리
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
  
  // ⭐ APNs 토큰 등록 실패 시 처리
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("❌ APNs Token 등록 실패: \(error.localizedDescription)")
      print("💡 이 경우 reCAPTCHA가 표시될 수 있습니다.")
      print("💡 해결 방법:")
      print("   1. Apple Developer Program 가입 확인")
      print("   2. Provisioning Profile 확인")
      print("   3. Firebase 콘솔에서 APNs 키 설정")
  }
}

