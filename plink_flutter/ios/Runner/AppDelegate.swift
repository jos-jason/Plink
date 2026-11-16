import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The share extension and the app exchange files in the App Group
    // container; Dart asks for its path here (lib/data/share_inbox.dart).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlinkAppGroup") {
      let channel = FlutterMethodChannel(
        name: "plink/app_group", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "containerPath" else {
          return result(FlutterMethodNotImplemented)
        }
        let url = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: "group.Babymechanical.Plink")
        result(url?.path)
      }
    }
  }
}
