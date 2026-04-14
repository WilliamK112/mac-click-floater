import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if ToggleRunShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterToggleRunShortcut, object: nil)
                return nil
            }
            if ToggleFloaterShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterToggleFloaterShortcut, object: nil)
                return nil
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if ToggleRunShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterToggleRunShortcut, object: nil)
            } else if ToggleFloaterShortcut.matches(event) {
                NotificationCenter.default.post(name: .clickFloaterToggleFloaterShortcut, object: nil)
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
            RootFloaterView()
                .environmentObject(store)
                .background(WindowAccessor { window in
                    FloaterWindowCoordinator.shared.attach(window: window, store: store)
                })
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 360, height: 520)
    }
}

struct RootFloaterView: View {
    @EnvironmentObject private var store: ClickPointStore

    var body: some View {
        Group {
            if store.windowState.isCollapsed {
                FloatingOrbView()
            } else {
                ControlPanelView()
            }
        }
    }
}

@MainActor
final class FloaterWindowCoordinator {
    static let shared = FloaterWindowCoordinator()

    private weak var window: NSWindow?
    private weak var store: ClickPointStore?
    private var hasConfiguredWindow = false
    private let collapsedSize = CGSize(width: 64, height: 64)

    func attach(window: NSWindow, store: ClickPointStore) {
        self.window = window
        self.store = store

        if !hasConfiguredWindow {
            configureBaseWindow(window)
            hasConfiguredWindow = true
        }

        applyCurrentLayout(animated: false)
    }

    func toggleCollapsed() {
        guard let store else { return }
        store.setCollapsed(!store.windowState.isCollapsed)
        applyCurrentLayout(animated: true)
    }

    func persistOrbCenter(_ center: CGPoint) {
        guard let store else { return }
        store.updateOrbCenter(center)
    }

    func handleManualWindowMove() {
        guard let window, let store, store.windowState.isCollapsed else { return }
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        store.updateOrbCenter(center)
    }

    func applyCurrentLayout(animated: Bool) {
        guard let window, let store else { return }

        if store.windowState.isCollapsed {
            let center = store.preferredOrbCenter()
            store.updateOrbCenter(center)
            let frame = NSRect(
                x: center.x - collapsedSize.width / 2,
                y: center.y - collapsedSize.height / 2,
                width: collapsedSize.width,
                height: collapsedSize.height
            )

            window.title = "Click Floater"
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.styleMask = [.borderless, .nonactivatingPanel]
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.setFrame(frame, display: true, animate: animated)
        } else {
            let width = max(340, store.windowState.expandedWidth)
            let height = max(420, store.windowState.expandedHeight)
            let orbCenter = store.preferredOrbCenter()
            let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(orbCenter) }) ?? NSScreen.main ?? NSScreen.screens[0]
            let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)

            var originX = orbCenter.x - 40
            var originY = orbCenter.y - (height / 2)
            originX = min(max(originX, visible.minX), visible.maxX - width)
            originY = min(max(originY, visible.minY), visible.maxY - height)
            let frame = NSRect(x: originX, y: originY, width: width, height: height)

            window.title = "Click Floater"
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .windowBackgroundColor
            window.hasShadow = true
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.setFrame(frame, display: true, animate: animated)
            store.persistExpandedSize(frame.size)
        }

        window.orderFrontRegardless()
    }

    private func configureBaseWindow(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = true
        window.ignoresMouseEvents = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handleManualWindowMove()
        }
    }
}
