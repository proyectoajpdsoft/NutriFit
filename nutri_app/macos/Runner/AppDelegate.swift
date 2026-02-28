import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let externalUrlChannel = FlutterMethodChannel(
        name: "nutri_app/external_url",
        binaryMessenger: flutterViewController.engine.binaryMessenger
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

        NSWorkspace.shared.open(url)
        result(true)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
