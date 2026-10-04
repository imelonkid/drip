import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var model: CaffeineModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("保持唤醒")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { model.isActive }, set: { model.setActive($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            SectionDivider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("时长")
                    Spacer()
                    RemainingText()
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

                DurationPicker()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            SectionDivider()

            MenuRow(title: "设置", trailing: showSettings ? "chevron.down" : "chevron.right") {
                withAnimation(.easeInOut(duration: 0.15)) { showSettings.toggle() }
            }
            if showSettings {
                SettingsSection()
            }

            SectionDivider()

            MenuRow(title: "关于 Drip") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            MenuRow(title: "退出") { NSApp.terminate(nil) }
        }
        .padding(.vertical, 5)
        .frame(width: 290)
    }
}

// MARK: - 时长

private struct DurationPicker: View {
    @EnvironmentObject private var model: CaffeineModel

    var body: some View {
        HStack(spacing: 4) {
            chip(0) { Image(systemName: "infinity").font(.system(size: 11, weight: .bold)) }
            dot
            ForEach(CaffeineModel.minuteOptions, id: \.self) { m in
                chip(m) { Text("\(m)") }
            }
            dot
            ForEach(CaffeineModel.hourOptions, id: \.self) { m in
                chip(m) { Text("\(m / 60)h") }
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
    }

    private var dot: some View {
        Circle().fill(.tertiary).frame(width: 3, height: 3)
    }

    private func chip<Label: View>(_ minutes: Int, @ViewBuilder label: () -> Label) -> some View {
        let selected = model.isActive && model.selectedMinutes == minutes
        return Button { model.select(minutes: minutes) } label: {
            label()
                .frame(width: 26, height: 26)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(Circle().fill(selected ? Color.accentColor : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(minutes == 0 ? "无限期" : minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时")
    }
}

private struct RemainingText: View {
    @EnvironmentObject private var model: CaffeineModel

    var body: some View {
        if let end = model.endDate {
            // 只在面板打开时渲染，关闭后不消耗任何刷新
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text("剩余 " + format(end.timeIntervalSince(ctx.date)))
                    .monospacedDigit()
            }
        } else if model.isActive {
            Text("无限期")
        } else {
            Text("未开启")
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded()))
        let h = s / 3600, m = s % 3600 / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - 设置

private struct SettingsSection: View {
    @EnvironmentObject private var model: CaffeineModel

    var body: some View {
        VStack(spacing: 8) {
            SettingToggle(title: "屏幕保持常亮", isOn: $model.keepDisplayOn)
            SettingToggle(title: "启动时自动开启", isOn: $model.activateOnLaunch)
            SettingToggle(
                title: "登录时启动",
                isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

private struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

// MARK: - 通用组件

private struct SectionDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 10).padding(.vertical, 3)
    }
}

private struct MenuRow: View {
    let title: String
    var trailing: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 13))
                Spacer()
                if let trailing {
                    Image(systemName: trailing)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.primary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .onHover { hovering = $0 }
    }
}
