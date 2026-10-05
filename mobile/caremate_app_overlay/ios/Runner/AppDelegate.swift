import Flutter
import UIKit

// Flutter 3.41+ 預設用 UIScene lifecycle：
// MethodChannel 要喺 didInitializeImplicitFlutterEngine 入面註冊
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let fmBridge = FoundationModelsBridge()
  private var fmChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "caremate/foundation_models",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.fmBridge.handle(call, result: result)
    }
    fmChannel = channel
  }
}
