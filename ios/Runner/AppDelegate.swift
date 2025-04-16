import UIKit
import Flutter
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // 1️⃣ SwiftCameraPlugin 먼저 등록
    SwiftCameraPlugin.register(with: self.registrar(forPlugin: "SwiftCameraPlugin")!)
    
    // SwiftAudioConverter 등록
    SwiftAudioConverter.register(with: self.registrar(forPlugin: "SwiftAudioConverter")!)
    
    // 2️⃣ 모든 플러그인 등록 (firebase_core 등)
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}


