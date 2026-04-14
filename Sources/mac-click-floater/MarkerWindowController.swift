import SwiftUI
import AppKit

@MainActor
final class MarkerWindowController: NSObject, NSWindowDelegate {
    private let id: UUID
    private let onMove: (UUID, CGPoint) -> Void
    private let size = CGSize(width: 52, height: 52)
    let window: NSPanel

    init(point: ClickPoint, onMove: @escaping (UUID, CGPoint) -> Void) {
        self.id = point.id
        self.onMove = onMove
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
