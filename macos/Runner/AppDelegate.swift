import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var quitChannel: FlutterMethodChannel?
  private var terminationPreApproved = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Note: deliberately doesn't call super here — FlutterAppDelegate doesn't
  // implement this method, so `super.applicationDidFinishLaunching(_:)`
  // raises "unrecognized selector" at runtime (only surfaces once this
  // notification actually fires, so it isn't caught by a normal build).
  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard
      let controller = NSApp.windows.first?.contentViewController
        as? FlutterViewController
    else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "projector_grid/quit",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "markTerminationApproved" {
        self?.terminationPreApproved = true
      }
      result(nil)
    }
    quitChannel = channel
  }

  // The system "Quit" menu item (and its Cmd+Q key equivalent when no
  // Flutter view has focus to intercept it first) calls -terminate: directly,
  // which never consults NSWindowDelegate.windowShouldClose — the callback
  // window_manager's setPreventClose relies on to ask Flutter about unsaved
  // changes before closing. Defer termination and ask Flutter the same
  // question over a dedicated channel instead of quitting blind.
  //
  // Flutter's own quit paths (Cmd+Q shortcut, the window's close button)
  // already run that confirmation before calling windowManager.destroy() —
  // which itself calls NSApp.terminate(nil), re-entering this method. Those
  // paths flag the upcoming termination as pre-approved first so it isn't
  // asked about twice.
  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    if terminationPreApproved {
      terminationPreApproved = false
      return .terminateNow
    }

    guard let channel = quitChannel else {
      return .terminateNow
    }
    channel.invokeMethod("confirmQuit", arguments: nil) { result in
      let shouldQuit = (result as? Bool) ?? true
      sender.reply(toApplicationShouldTerminate: shouldQuit)
    }
    return .terminateLater
  }
}
