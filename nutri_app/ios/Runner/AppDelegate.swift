import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let screenAwakeChannel = FlutterMethodChannel(
        name: "nutri_app/screen_awake",
        binaryMessenger: controller.binaryMessenger
      )

      screenAwakeChannel.setMethodCallHandler { call, result in
        guard call.method == "setScreenAwake" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let enabled = args["enabled"] as? Bool
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing 'enabled' bool",
              details: nil
            )
          )
          return
        }

        DispatchQueue.main.async {
          UIApplication.shared.isIdleTimerDisabled = enabled
          result(true)
        }
      }

      let externalUrlChannel = FlutterMethodChannel(
        name: "nutri_app/external_url",
        binaryMessenger: controller.binaryMessenger
      )

      externalUrlChannel.setMethodCallHandler { call, result in
        guard call.method == "openUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let rawUrl = args["url"] as? String,
          let url = URL(string: rawUrl)
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing or invalid 'url'",
              details: nil
            )
          )
          return
        }

        DispatchQueue.main.async {
          UIApplication.shared.open(url, options: [:]) { success in
            if success {
              result(true)
            } else {
              result(
                FlutterError(
                  code: "OPEN_URL_FAILED",
                  message: "Could not open URL",
                  details: rawUrl
                )
              )
            }
          }
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
