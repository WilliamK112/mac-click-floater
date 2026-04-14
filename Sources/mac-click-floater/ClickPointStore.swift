import SwiftUI
import AppKit
import ApplicationServices

@MainActor
final class ClickPointStore: ObservableObject {
    @Published var points: [ClickPoint] = [] {
        didSet {
            persist()
            if isRunning {
                restartTimers()
            }
        }
    }

    @Published var accessibilityGranted = AccessibilityPermission.isGranted()
    @Published var statusMessage = "先点一次“检查权限”，允许辅助功能后再开始。"
    @Published var debugClickCount = 0
    @Published var windowState = FloaterWindowState() {
        didSet {
            persistWindowState()
        }
    }
    @Published private(set) var runningPointIDs: Set<UUID> = []
    @Published var selectedPointID: UUID?

    var isRunning: Bool {
        !runningPointIDs.isEmpty
    }

    private var debugTargetCenter: CGPoint?
    private var didStartAutomatedSelfTest = false

    private var markerWindows: [UUID: MarkerWindowController] = [:]
    private var timers: [UUID: DispatchSourceTimer] = [:]
    private var stopWorkItems: [UUID: DispatchWorkItem] = [:]

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleRunShortcutNotification),
            name: .clickFloaterToggleRunShortcut,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleFloaterShortcutNotification),
            name: .clickFloaterToggleFloaterShortcut,
            object: nil
        )

        load()
        syncMarkerWindows()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshPermissions(prompt: Bool = false) {
        accessibilityGranted = prompt ? AccessibilityPermission.requestPrompt() : AccessibilityPermission.isGranted()
        statusMessage = accessibilityGranted
            ? "辅助功能权限已就绪，可以开始自动点击。"
            : "还没拿到辅助功能权限，点击开始时系统会弹权限提示。"
    }

    func addPoint() {
        let screenFrame = preferredPlacementScreen().visibleFrame
        let point = ClickPoint(
            name: "P\(points.count + 1)",
            x: screenFrame.midX,
            y: screenFrame.midY,
            interval: 5,
            isEnabled: true,
            durationHours: 0,
            durationMinutes: 0,
            durationSeconds: 0
        )
        points.append(sanitize(point))
        syncMarkerWindows()
        statusMessage = "已生成一个点击点，把红点拖到你想点的位置就行。"
    }

    func removePoint(id: UUID) {
        if let controller = markerWindows.removeValue(forKey: id) {
            controller.close()
        }
        if let timer = timers.removeValue(forKey: id) {
            timer.cancel()
        }
        if let workItem = stopWorkItems.removeValue(forKey: id) {
            workItem.cancel()
        }
        runningPointIDs.remove(id)
        points.removeAll { $0.id == id }
        statusMessage = "点击点已删除。"
    }

    func updatePoint(_ updated: ClickPoint) {
        guard let index = points.firstIndex(where: { $0.id == updated.id }) else { return }
        let sanitized = sanitize(updated)
        points[index] = sanitized
        if runningPointIDs.contains(updated.id) {
            scheduleStopForPoint(sanitized)
        }
        syncMarkerWindows()
    }

    func movePoint(id: UUID, to position: CGPoint) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        points[index].x = position.x
        points[index].y = position.y
    }

    func registerDebugTarget(center: CGPoint) {
        debugTargetCenter = center
        maybeRunAutomatedSelfTest()
    }

    func incrementDebugClickCount() {
        debugClickCount += 1
        print("debugClickCount=\(debugClickCount)")
        persistSelfTestResultIfNeeded(stage: "hit")
    }

    func moveFirstPointToDebugTarget() {
        guard let target = debugTargetCenter else {
            statusMessage = "还没拿到测试区坐标。"
            return
        }
        guard let first = points.first else {
            statusMessage = "先新增一个点击点。"
            return
        }

        var updated = first
        updated.x = target.x
        updated.y = target.y
        updatePoint(updated)
        statusMessage = "已把第一个点击点对准测试区。"
    }

    func resetDebugClickCount() {
        debugClickCount = 0
    }

    private func ensurePermissionReady() -> Bool {
        refreshPermissions(prompt: false)
        guard accessibilityGranted else {
            _ = AccessibilityPermission.requestPrompt()
            accessibilityGranted = AccessibilityPermission.isGranted()
            statusMessage = "请到 系统设置 > 隐私与安全性 > 辅助功能 里允许 Click Floater，然后再点开始。"
            return false
        }
        return true
    }

    private func maybeRunAutomatedSelfTest() {
        guard ProcessInfo.processInfo.environment["CLICK_FLOATER_SELF_TEST"] == "1" else { return }
        guard !didStartAutomatedSelfTest else { return }
        guard let target = debugTargetCenter else { return }

        didStartAutomatedSelfTest = true
        debugClickCount = 0
        stopClicking()
        points = [ClickPoint(name: "SelfTest", x: target.x, y: target.y, interval: 0.5, isEnabled: true)]
        syncMarkerWindows()
        statusMessage = "正在运行自动自测..."
        print("self-test: target=\(target.x),\(target.y)")
        persistSelfTestResultIfNeeded(stage: "started")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.startClicking()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            guard let self else { return }
            self.stopClicking()
            self.statusMessage = self.debugClickCount > 0
                ? "自动自测通过，已命中 \(self.debugClickCount) 次。"
                : "自动自测失败，没有命中测试区。"
            self.persistSelfTestResultIfNeeded(stage: "finished")
            print("self-test finished: count=\(self.debugClickCount)")
        }
    }

    @objc private func handleToggleRunShortcutNotification() {
        toggleRunFromShortcut()
    }

    @objc private func handleToggleFloaterShortcutNotification() {
        toggleFloaterVisibilityFromShortcut()
    }

    func toggleRunFromShortcut() {
        if isRunning {
            stopClicking()
            statusMessage = "已暂停。快捷键: Command + . 可重新开始, Command + / 显示或隐藏悬浮球。"
        } else {
            startAllPoints()
        }
    }

    func toggleFloaterVisibilityFromShortcut() {
        if windowState.isCollapsed {
            windowState.isCollapsed = false
        } else {
            windowState.isCollapsed = true
        }
    }

    func isPointRunning(_ id: UUID) -> Bool {
        runningPointIDs.contains(id)
    }

    func startClicking() {
        startAllPoints()
    }

    func stopClicking() {
        stopAllPoints()
    }

    func startAllPoints() {
        guard ensurePermissionReady() else { return }

        let runnablePoints = points.filter { $0.isEnabled }
        guard !runnablePoints.isEmpty else {
            statusMessage = "先至少保留一个启用中的点击点。"
            return
        }

        runningPointIDs = Set(runnablePoints.map(\.id))
        for point in runnablePoints {
            scheduleStopForPoint(point)
        }
        syncMarkerWindows()
        restartTimers()
        statusMessage = "全部点击点已开始。快捷键: Command + . 暂停或开始, Command + / 显示或隐藏悬浮球。"
    }

    func stopAllPoints() {
        runningPointIDs.removeAll()
        for timer in timers.values {
            timer.cancel()
        }
        timers.removeAll()
        for workItem in stopWorkItems.values {
            workItem.cancel()
        }
        stopWorkItems.removeAll()
        syncMarkerWindows()
        statusMessage = "自动点击已停止。快捷键: Command + . 可重新开始, Command + / 显示或隐藏悬浮球。"
    }

    func startPoint(id: UUID) {
        guard ensurePermissionReady() else { return }
        guard let point = points.first(where: { $0.id == id }) else { return }
        guard point.isEnabled else {
            statusMessage = "这个点当前被禁用，先打开开关再启动。"
            return
        }

        runningPointIDs.insert(id)
        scheduleStopForPoint(point)
        syncMarkerWindows()
        restartTimers()
        statusMessage = "已启动 \(point.name.isEmpty ? "该点" : point.name)。"
    }

    func stopPoint(id: UUID) {
        guard let point = points.first(where: { $0.id == id }) else { return }
        runningPointIDs.remove(id)
        if let timer = timers.removeValue(forKey: id) {
            timer.cancel()
        }
        if let workItem = stopWorkItems.removeValue(forKey: id) {
            workItem.cancel()
        }
        restartTimers()
        syncMarkerWindows()
        statusMessage = "已停止 \(point.name.isEmpty ? "该点" : point.name)。"
    }

    func togglePointRunning(id: UUID) {
        if isPointRunning(id) {
            stopPoint(id: id)
        } else {
            startPoint(id: id)
        }
    }

    func nudgeDuration(id: UUID, deltaSeconds: Int) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        var point = points[index]
        let current = Int(point.durationTimeInterval)
        let next = max(0, current + deltaSeconds)
        point.durationHours = next / 3600
        point.durationMinutes = (next % 3600) / 60
        point.durationSeconds = next % 60
        updatePoint(point)
        statusMessage = "已调整 \(point.name.isEmpty ? "该点" : point.name) 的运行时长为 \(point.durationDescription)。"
    }

    func focusPointInPanel(id: UUID) {
        selectedPointID = id
        windowState.isCollapsed = false
        statusMessage = "已打开 \(points.first(where: { $0.id == id })?.name ?? "该点") 的设置。"
    }

    private func scheduleStopForPoint(_ point: ClickPoint) {
        if let existing = stopWorkItems.removeValue(forKey: point.id) {
            existing.cancel()
        }

        let duration = point.durationTimeInterval
        guard duration > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.runningPointIDs.contains(point.id) {
                self.stopPoint(id: point.id)
            }
        }

        stopWorkItems[point.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func restartTimers() {
        for timer in timers.values {
            timer.cancel()
        }
        timers.removeAll()

        for point in points where point.isEnabled && runningPointIDs.contains(point.id) {
            let pointID = point.id
            let interval = max(point.interval, 0.2)
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + interval, repeating: interval)
            timer.setEventHandler { [weak self] in
                guard let self, self.runningPointIDs.contains(pointID) else { return }
                guard let latestPoint = self.points.first(where: { $0.id == pointID && $0.isEnabled }) else { return }

                ClickEngine.leftClick(at: latestPoint.cgPoint)
                let displayName = latestPoint.name.isEmpty ? "该点" : latestPoint.name
                self.statusMessage = "正在点击 \(displayName) · 每 \(String(format: "%.1f", interval)) 秒一次"
            }
            timers[pointID] = timer
            timer.resume()
        }
    }

    private func syncMarkerWindows() {
        let currentIDs = Set(points.map(\.id))

        for (id, controller) in markerWindows where !currentIDs.contains(id) {
            controller.close()
            markerWindows.removeValue(forKey: id)
        }

        for point in points {
            let pointIsRunning = runningPointIDs.contains(point.id)
            if let controller = markerWindows[point.id] {
                controller.update(point: point, isRunning: pointIsRunning)
            } else {
                let controller = MarkerWindowController(
                    point: point,
                    isRunning: pointIsRunning,
                    onMove: { [weak self] id, newPosition in
                        Task { @MainActor [weak self] in
                            self?.movePoint(id: id, to: newPosition)
                        }
                    },
                    onToggleRun: { [weak self] id in
                        Task { @MainActor [weak self] in
                            self?.togglePointRunning(id: id)
                        }
                    },
                    onNudgeDuration: { [weak self] id, deltaSeconds in
                        Task { @MainActor [weak self] in
                            self?.nudgeDuration(id: id, deltaSeconds: deltaSeconds)
                        }
                    },
                    onOpenSettings: { [weak self] id in
                        Task { @MainActor [weak self] in
                            self?.focusPointInPanel(id: id)
                        }
                    },
                    onRemove: { [weak self] id in
                        Task { @MainActor [weak self] in
                            self?.removePoint(id: id)
                        }
                    }
                )
                controller.update(point: point, isRunning: pointIsRunning)
                markerWindows[point.id] = controller
            }
        }
    }

    private func baseSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appending(path: "ClickFloater", directoryHint: .isDirectory)
    }

    private func persistenceURL() -> URL {
        baseSupportDirectory().appending(path: "points.json")
    }

    private func selfTestResultURL() -> URL {
        baseSupportDirectory().appending(path: "self-test.json")
    }

    private func windowStateURL() -> URL {
        baseSupportDirectory().appending(path: "window-state.json")
    }

    private func persist() {
        let url = persistenceURL()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(points)
            try data.write(to: url)
        } catch {
            statusMessage = "保存点击点失败: \(error.localizedDescription)"
        }
    }

    func setCollapsed(_ collapsed: Bool) {
        windowState.isCollapsed = collapsed
    }

    func updateOrbCenter(_ center: CGPoint) {
        windowState.orbCenterX = center.x
        windowState.orbCenterY = center.y
    }

    func persistExpandedSize(_ size: CGSize) {
        windowState.expandedWidth = max(300, size.width)
        windowState.expandedHeight = max(360, size.height)
    }

    func preferredOrbCenter() -> CGPoint {
        if let x = windowState.orbCenterX, let y = windowState.orbCenterY {
            let point = CGPoint(x: x, y: y)
            if NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: 24, dy: 24).contains(point) }) {
                return point
            }
        }

        let screen = preferredPlacementScreen().visibleFrame
        return CGPoint(x: screen.maxX - 34, y: screen.midY)
    }

    private func persistWindowState() {
        let url = windowStateURL()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(windowState)
            try data.write(to: url)
        } catch {
            statusMessage = "保存窗口状态失败: \(error.localizedDescription)"
        }
    }

    private func persistSelfTestResultIfNeeded(stage: String) {
        guard ProcessInfo.processInfo.environment["CLICK_FLOATER_SELF_TEST"] == "1" else { return }
        let url = selfTestResultURL()
        let payload: [String: Any] = [
            "stage": stage,
            "debugClickCount": debugClickCount,
            "isRunning": isRunning,
            "statusMessage": statusMessage
        ]
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: url)
        } catch {
            print("self-test persist failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        let url = persistenceURL()
        if let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([ClickPoint].self, from: data) {
            points = decoded.map { sanitize($0) }
        } else {
            points = []
        }

        let stateURL = windowStateURL()
        if let data = try? Data(contentsOf: stateURL), let decoded = try? JSONDecoder().decode(FloaterWindowState.self, from: data) {
            windowState = decoded
        }
    }

    private func preferredPlacementScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        if let underMouse = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return underMouse
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen.screens[0]
    }

    private func sanitize(_ point: ClickPoint) -> ClickPoint {
        if NSScreen.screens.contains(where: { $0.visibleFrame.contains(point.cgPoint) }) {
            return point
        }

        let screen = preferredPlacementScreen().visibleFrame.insetBy(dx: 40, dy: 40)
        var fixed = point
        fixed.x = min(max(point.x, screen.minX), screen.maxX)
        fixed.y = min(max(point.y, screen.minY), screen.maxY)
        fixed.durationHours = max(0, point.durationHours)
        fixed.durationMinutes = max(0, point.durationMinutes)
        fixed.durationSeconds = max(0, point.durationSeconds)
        return fixed
    }
}

@MainActor
enum AccessibilityPermission {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestPrompt() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

enum ClickEngine {
    @MainActor
    static func leftClick(at point: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let originalLocation = CGEvent(source: nil)?.location ?? point
        let quartzPoint = quartzPoint(fromAppKitPoint: point)

        let moveToTarget = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: quartzPoint, mouseButton: .left)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: quartzPoint, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: quartzPoint, mouseButton: .left)
        let moveBack = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: originalLocation, mouseButton: .left)

        moveToTarget?.post(tap: .cghidEventTap)
        usleep(8_000)
        down?.post(tap: .cghidEventTap)
        usleep(12_000)
        up?.post(tap: .cghidEventTap)
        usleep(8_000)
        moveBack?.post(tap: .cghidEventTap)
    }

    @MainActor
    private static func quartzPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let displayID = CGDirectDisplayID(screenNumber?.uint32Value ?? CGMainDisplayID())
        let cgBounds = CGDisplayBounds(displayID)

        let localY = point.y - screen.frame.minY
        let quartzY = cgBounds.minY + (screen.frame.height - localY)
        return CGPoint(x: point.x, y: quartzY)
    }
}
