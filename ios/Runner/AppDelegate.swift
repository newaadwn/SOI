import UIKit
import Flutter
import Firebase
import FirebaseAuth
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase 초기화 먼저
    FirebaseApp.configure()
    
    // Firebase Auth 설정
    Auth.auth().settings?.isAppVerificationDisabledForTesting = false
    
    // APNs 알림 권한 요청
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: {_, _ in })
    }
    
    application.registerForRemoteNotifications()
    
    // 1️⃣ SwiftCameraPlugin 먼저 등록
    SwiftCameraPlugin.register(with: self.registrar(forPlugin: "SwiftCameraPlugin")!)
    
    // SwiftAudioConverter 등록
    SwiftAudioConverter.register(with: self.registrar(forPlugin: "SwiftAudioConverter")!)
    
    // 2️⃣ 모든 플러그인 등록 (firebase_core 등)
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let firebaseAuth = Auth.auth()
      // Production 환경에서는 .prod, 개발 환경에서는 .sandbox 또는 .unknown 사용
      #if DEBUG
      firebaseAuth.setAPNSToken(deviceToken, type: AuthAPNSTokenType.sandbox)
      #else
      firebaseAuth.setAPNSToken(deviceToken, type: AuthAPNSTokenType.prod)
      #endif
      print("APNS Token set successfully")
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
}