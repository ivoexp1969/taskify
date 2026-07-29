import Flutter
import UIKit
import AppTrackingTransparency
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupWidgetChannel()
    return result
  }

  private func setupWidgetChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(name: "com.ivoexp.taskify/widget", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      let defaults = UserDefaults(suiteName: "group.com.ivoexp.taskify")
      if call.method == "syncToAppGroup", let args = call.arguments as? [String: Any],
         let tasks = args["tasks"] as? String {
        defaults?.set(tasks, forKey: "flutter.widget_tasks")
        if let lang = args["language"] as? String {
          defaults?.set(lang, forKey: "flutter.app_language")
        }
        // Локален контекст (документ/имен ден/празник) — като Android.
        if let ctx = args["context"] as? String {
          if ctx.isEmpty || ctx == "{}" {
            defaults?.removeObject(forKey: "flutter.widget_context")
          } else {
            defaults?.set(ctx, forKey: "flutter.widget_context")
          }
        }
        // Име на потребителя → по-лично приветствие в widget-а.
        if let userName = args["userName"] as? String {
          if userName.isEmpty {
            defaults?.removeObject(forKey: "flutter.widget_user_name")
          } else {
            defaults?.set(userName, forKey: "flutter.widget_user_name")
          }
        }
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      } else if call.method == "getCompletedFromWidget" {
        // Ключовете на задачите, отметнати от widget-а (AppIntent ги записа).
        let keys = defaults?.array(forKey: "flutter.widget_completed") as? [Int] ?? []
        defaults?.removeObject(forKey: "flutter.widget_completed")
        result(keys)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Искаме ATT разрешение след като UI е готов (изисква се от Apple)
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { _ in
        // Резултатът се обработва от Google Mobile Ads SDK автоматично
      }
    }
  }
}
