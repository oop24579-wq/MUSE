import UIKit
import Flutter
import flutter_local_notifications
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    registerContentProtectionChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Round 5 (item 3): `herodrama/content_protection` channel.
  ///
  /// iOS has no FLAG_SECURE equivalent and screenshots cannot be
  /// blocked. Instead the app is told when the screen is being
  /// captured (recording / mirroring) via UIScreen.isCaptured changes
  /// and when a screenshot was taken, so Dart can cover the video
  /// with a privacy overlay and show a notice.
  private func registerContentProtectionChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "herodrama/content_protection",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setSecure":
        // Nothing to set on iOS — report success so the Dart-side
        // protection state machine stays platform-agnostic.
        result(true)
      case "isCaptured":
        result(UIScreen.main.isCaptured)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      channel.invokeMethod("captureChanged", arguments: ["captured": UIScreen.main.isCaptured])
    }
    NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { _ in
      channel.invokeMethod("screenshotTaken", arguments: nil)
    }
  }
}
