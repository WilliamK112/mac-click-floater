import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if EmergencyStopShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterEmergencyStop, object: nil)
                return nil
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if EmergencyStopShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterEmergencyStop, object: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }
}

@main
struct ClickFloaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClickPointStore()

    var body: some Scene {
        WindowGroup {
            ControlPanelView()
                .environmentObject(store)
                .background(WindowAccessor { window in
                    window.title = "Click Floater"
                    window.level = .floating
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.isMovableByWindowBackground = true
                    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                    window.standardWindowButton(.zoomButton)?.isHidden = true
                })
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 520)
    }
}
