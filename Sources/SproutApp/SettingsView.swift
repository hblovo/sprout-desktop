import SwiftUI
import SproutCore

@MainActor struct SettingsView: View {
    @ObservedObject var store: HealthStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 21) {
                        SectionHeading(symbol: "sun.max", title: "给身体一点间隙")
                        settingRow("起身提醒", detail: "调整后开始新一轮计时") {
                            Picker("起身间隔", selection: preference(\.focusMinutes)) {
                                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text("\($0) 分钟").tag($0) }
                            }.labelsHidden().frame(width: 120)
                        }
                        settingRow("每次休息", detail: "倒计时结束后，确认活动过才计入记录") {
                            Picker("每次休息", selection: preference(\.breakMinutes)) {
                                ForEach([1, 2, 3, 5, 10], id: \.self) { Text("\($0) 分钟").tag($0) }
                            }.labelsHidden().frame(width: 120)
                        }
                        Divider().overlay(Palette.line)
                        settingRow("智能感知离开", detail: "键鼠闲置 1 分钟暂停；闲置 2–30 分钟后返回询问") {
                            Toggle("智能感知离开", isOn: preference(\.detectIdle)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                        Text("仅读取无输入的时长，不读取键盘内容或屏幕。阅读时也可能进入暂离状态，可随时关闭。长时间离开后仍保留剩余时间，不自动增加起身次数。")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(4)
                        settingRow("安静时段", detail: "在这段时间冻结专注计时，不发送提醒") {
                            Toggle("安静时段", isOn: preference(\.quietHoursEnabled)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                        if store.preferences.quietHoursEnabled {
                            HStack(spacing: 10) {
                                Text("每天").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                hourPicker("开始时间", keyPath: \.quietStartHour)
                                Text("至").foregroundStyle(Palette.secondary)
                                hourPicker("结束时间", keyPath: \.quietEndHour)
                                Spacer()
                            }
                            if store.preferences.quietStartHour == store.preferences.quietEndHour {
                                Text("开始和结束相同，当前不限制提醒时段。").font(.system(size: 10)).foregroundStyle(Palette.orange)
                            }
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 21) {
                        SectionHeading(symbol: "drop", title: "每一杯，都刚刚好", color: Palette.orange)
                        settingRow("一杯的容量", detail: "用于一键打卡，可按自己的杯子调整") {
                            Picker("一杯容量", selection: preference(\.cupML)) {
                                ForEach([100, 150, 200, 250, 300, 350, 500], id: \.self) { Text("\($0) mL").tag($0) }
                            }.labelsHidden().frame(width: 120)
                        }
                        settingRow("每日饮水目标", detail: "这是个人习惯目标，请按自身需要调整") {
                            Picker("每日饮水目标", selection: preference(\.waterGoalML)) {
                                ForEach([500, 1000, 1500, 1800, 2000, 2500, 3000, 3500, 4000], id: \.self) { Text("\($0) mL").tag($0) }
                            }.labelsHidden().frame(width: 120)
                        }
                        settingRow("轻轻提醒喝水", detail: "启用后，每 60 分钟提醒；完成目标后停止") {
                            Toggle("提醒喝水", isOn: preference(\.waterRemindersEnabled)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 21) {
                        SectionHeading(symbol: "leaf", title: "小芽的陪伴方式")
                        settingRow("显示桌宠", detail: "拖动可移动位置，点击打开面板，右键快捷操作") {
                            Toggle("显示桌宠", isOn: preference(\.petVisible)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                        settingRow("跟随 Codex 工作", detail: "检测到本机任务运行时，小芽会敲键盘") {
                            Toggle("跟随 Codex 工作", isOn: $store.codexAnimationEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                        Text("本地读取 ~/.codex/sessions 中的任务开始和结束标记，不保存或上传对话内容。约 5 秒更新；15 分钟没有更新时恢复待机。暂不支持远程任务和自定义 Codex 数据目录。")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(4)
                        settingRow("减少动态效果", detail: "让小芽安静地待在身边") {
                            Toggle("减少动态效果", isOn: preference(\.reduceMotion)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                        settingRow("系统通知", detail: "\(store.notificationStatus) · 可选；不授权也可以收到桌宠提醒") {
                            Toggle("系统通知", isOn: Binding(get: { store.preferences.notificationsEnabled }, set: { store.setNotifications($0) }))
                                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 17) {
                        SectionHeading(symbol: "lock.shield", title: "你的数据，只在你的 Mac 上")
                        Text("无需注册，无云端上传。计时进度自动保存，退出或重启后接着走；退出期间不累计久坐时间。关闭主窗口后，菜单栏和桌宠继续运行。")
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(5)
                        HStack(spacing: 10) {
                            Button("导出记录") { store.exportData() }.buttonStyle(SoftButtonStyle())
                            Button("打开数据位置") { store.revealData() }.buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                Text("芽伴 SPROUT · 1.1.3   /   为长时间坐在屏幕前的你而做。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).padding(.vertical, 9)
            }.padding(1)
        }.scrollIndicators(.hidden)
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(get: { store.preferences[keyPath: keyPath] }, set: { newValue in
            store.updatePreferences { $0[keyPath: keyPath] = newValue }
        })
    }

    private func hourPicker(_ label: String, keyPath: WritableKeyPath<Preferences, Int>) -> some View {
        Picker(label, selection: preference(keyPath)) {
            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
        }.labelsHidden().frame(width: 98)
    }

    private func settingRow<Control: View>(_ title: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 12)
            control()
        }
    }
}
