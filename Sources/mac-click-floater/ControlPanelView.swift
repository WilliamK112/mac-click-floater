import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject private var store: ClickPointStore
    @State private var showDebugTools = ProcessInfo.processInfo.environment["CLICK_FLOATER_SHOW_DEBUG"] == "1" || ProcessInfo.processInfo.environment["CLICK_FLOATER_SELF_TEST"] == "1"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Click Floater")
                        .font(.title3.weight(.bold))
                    Text("收起时是悬浮球，点开后再显示控制面板。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.setCollapsed(true)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("收起到悬浮球")
            }

            HStack(spacing: 10) {
                Button {
                    store.addPoint()
                } label: {
                    Label("新增点击点", systemImage: "plus.circle.fill")
                }

                Button {
                    store.refreshPermissions(prompt: true)
                } label: {
                    Label(store.accessibilityGranted ? "权限已就绪" : "检查权限", systemImage: store.accessibilityGranted ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    store.isRunning ? store.stopAllPoints() : store.startAllPoints()
                } label: {
                    Label(store.isRunning ? "停止全部" : "开始全部", systemImage: store.isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if !store.points.isEmpty {
                    Text("共 \(store.points.count) 个点")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if showDebugTools {
                DebugClickPad()
            }

            ScrollView {
                VStack(spacing: 10) {
                    if store.points.isEmpty {
                        EmptyStateView()
                    } else {
                        ForEach(Array(store.points.enumerated()), id: \.element.id) { index, point in
                            PointEditorRow(
                                index: index + 1,
                                point: binding(for: point.id),
                                isRunning: store.isPointRunning(point.id),
                                isSelected: store.selectedPointID == point.id,
                                onToggleRun: {
                                    store.togglePointRunning(id: point.id)
                                }
                            ) {
                                store.removePoint(id: point.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)

            HStack {
                Button(showDebugTools ? "隐藏测试区" : "显示测试区") {
                    showDebugTools.toggle()
                }
                .buttonStyle(.borderless)
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(store.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("提示：运行中红点会穿透到底下内容，按 Esc 可立刻停止。")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(minWidth: 340, minHeight: 420)
    }

    private func binding(for id: UUID) -> Binding<ClickPoint> {
        Binding {
            store.points.first(where: { $0.id == id }) ?? ClickPoint(name: "", x: 0, y: 0, interval: 5, isEnabled: true)
        } set: { updated in
            store.updatePoint(updated)
        }
    }
}

struct FloatingOrbView: View {
    @EnvironmentObject private var store: ClickPointStore

    var body: some View {
        Button {
            store.setCollapsed(false)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: store.isRunning
                                ? [Color.orange, Color.red.opacity(0.9)]
                                : [Color.red, Color.pink.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: store.isRunning ? "pause.fill" : "circle.grid.2x1.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            .overlay(
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            .overlay(alignment: .bottomTrailing) {
                if store.isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: -2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .help("点击展开控制面板")
    }
}

private struct PointEditorRow: View {
    let index: Int
    @Binding var point: ClickPoint
    let isRunning: Bool
    let isSelected: Bool
    let onToggleRun: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("点 \(index)")
                    .font(.headline)
                if isRunning {
                    Text("运行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                Spacer()
                Toggle("启用", isOn: $point.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            TextField("名字", text: $point.name)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("间隔（秒）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("5", value: $point.interval, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(point.displayPosition)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(point.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("运行时长（0 = 一直运行）")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    DurationField(title: "时", value: $point.durationHours)
                    DurationField(title: "分", value: $point.durationMinutes)
                    DurationField(title: "秒", value: $point.durationSeconds)
                    Spacer()
                }
            }

            Button(action: onToggleRun) {
                Label(isRunning ? "停止此点" : "启动此点", systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .accentColor)
            .disabled(!point.isEnabled && !isRunning)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct DurationField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("0", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
        }
    }
}

private struct DebugClickPad: View {
    @EnvironmentObject private var store: ClickPointStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("自测点击区")
                    .font(.headline)
                Spacer()
                Text("命中 \(store.debugClickCount) 次")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("把第一个点对准测试区") {
                    store.moveFirstPointToDebugTarget()
                }
                .buttonStyle(.bordered)

                Button("清零") {
                    store.resetDebugClickCount()
                }
                .buttonStyle(.bordered)
            }

            Button {
                store.incrementDebugClickCount()
            } label: {
                Text("点击这里做命中测试")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.borderedProminent)
            .background(
                ScreenFrameReader { rect in
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    store.registerDebugTarget(center: center)
                }
            )

            Text("这里只给我自己调试用，默认可以隐藏。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ScreenFrameReader: NSViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            reportFrame(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            reportFrame(for: nsView)
        }
    }

    private func reportFrame(for view: NSView) {
        guard let window = view.window else { return }
        let localRect = view.convert(view.bounds, to: nil)
        let screenRect = window.convertToScreen(localRect)
        onChange(screenRect)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow.motionlines.click")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("还没有点击点")
                .font(.headline)
            Text("点“新增点击点”后，屏幕中间会出现一个红色圆点。把红点拖到你想自动点击的位置，再设定间隔和运行时长。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
