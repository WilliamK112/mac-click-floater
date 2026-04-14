import SwiftUI
import AppKit

@MainActor
final class MarkerWindowController: NSObject, NSWindowDelegate {
    private let id: UUID
    private let onMove: (UUID, CGPoint) -> Void
    private let onToggleRun: (UUID) -> Void
    private let onNudgeDuration: (UUID, Int) -> Void
    private let onOpenSettings: (UUID) -> Void
    private let onRemove: (UUID) -> Void
    private let size = CGSize(width: 52, height: 52)
    private var currentPoint: ClickPoint
    private var currentIsRunning: Bool
    let window: NSPanel

    init(
        point: ClickPoint,
        isRunning: Bool,
        onMove: @escaping (UUID, CGPoint) -> Void,
        onToggleRun: @escaping (UUID) -> Void,
        onNudgeDuration: @escaping (UUID, Int) -> Void,
        onOpenSettings: @escaping (UUID) -> Void,
        onRemove: @escaping (UUID) -> Void
    ) {
        self.id = point.id
        self.currentPoint = point
        self.currentIsRunning = isRunning
        self.onMove = onMove
        self.onToggleRun = onToggleRun
        self.onNudgeDuration = onNudgeDuration
        self.onOpenSettings = onOpenSettings
        self.onRemove = onRemove
        self.window = NSPanel(
            contentRect: NSRect(x: point.x - 26, y: point.y - 26, width: 52, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: MarkerView(name: point.name, isClickThrough: false))
        window.orderFrontRegardless()
    }

    func update(point: ClickPoint, isRunning: Bool) {
        currentPoint = point
        currentIsRunning = isRunning
        let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        if window.frame.origin != origin {
            window.setFrameOrigin(origin)
        }
        window.ignoresMouseEvents = isRunning
        if let host = window.contentView as? NSHostingView<MarkerView> {
            host.rootView = MarkerView(name: point.name, isClickThrough: isRunning)
        }
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    func windowDidMove(_ notification: Notification) {
        let frame = window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        onMove(id, center)
    }

    func window(_ window: NSWindow, menuFor event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let toggleTitle = currentIsRunning ? "暂停这个点" : "启动这个点"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(handleToggleRun), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let addTime = NSMenuItem(title: "时长 +10 秒", action: #selector(handleAddTenSeconds), keyEquivalent: "")
        addTime.target = self
        menu.addItem(addTime)

        let subtractTime = NSMenuItem(title: "时长 -10 秒", action: #selector(handleMinusTenSeconds), keyEquivalent: "")
        subtractTime.target = self
        menu.addItem(subtractTime)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "打开这个点设置", action: #selector(handleOpenSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let removeItem = NSMenuItem(title: "删除这个点", action: #selector(handleRemove), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        return menu
    }

    @objc private func handleToggleRun() {
        onToggleRun(id)
    }

    @objc private func handleAddTenSeconds() {
        onNudgeDuration(id, 10)
    }

    @objc private func handleMinusTenSeconds() {
        onNudgeDuration(id, -10)
    }

    @objc private func handleOpenSettings() {
        onOpenSettings(id)
    }

    @objc private func handleRemove() {
        onRemove(id)
    }
}

private struct MarkerView: View {
    let name: String
    let isClickThrough: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isClickThrough ? Color.orange.opacity(0.55) : Color.red.opacity(0.9))
            Circle()
                .stroke(Color.white.opacity(0.95), lineWidth: 2)
            VStack(spacing: 2) {
                Image(systemName: isClickThrough ? "hand.tap" : "cursorarrow.click")
                    .font(.system(size: 16, weight: .bold))
                if !name.isEmpty {
                    Text(String(name.prefix(4)))
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
        }
        .frame(width: 52, height: 52)
        .contentShape(Circle())
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }
}
