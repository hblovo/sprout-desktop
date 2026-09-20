import SwiftUI
import SproutCore

@MainActor struct RootView: View {
    @ObservedObject var store: HealthStore

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 206)
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 24) {
                header
                if let issue = store.storageIssue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(issue).font(.system(size: 11))
                        Spacer()
                        Button("查看文件") { store.revealData() }.buttonStyle(.plain)
                    }.foregroundStyle(Palette.orange).padding(12).background(Palette.peach, in: RoundedRectangle(cornerRadius: 10))
                }
                Group {
                    switch store.selectedPage {
                    case .today: DashboardView(store: store)
                    case .history: HistoryView(store: store)
                    case .settings: SettingsView(store: store)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                footer
            }.padding(.horizontal, 34).padding(.top, 48).padding(.bottom, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
        }
        .font(.system(size: 13))
        .foregroundStyle(Palette.ink)
        .tint(Palette.green)
        .background(Palette.background)
        .preferredColorScheme(.light)
        .ignoresSafeArea()
        .frame(minWidth: 1010, minHeight: 740)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "leaf.fill").font(.system(size: 23)).foregroundStyle(Palette.green)
                Text("芽伴").font(.system(size: 24, weight: .semibold, design: .rounded)).tracking(2)
            }.padding(.top, 55)
            Text("SPROUT · YOUR DESK BUDDY").font(.system(size: 8, weight: .medium)).tracking(1.15)
                .foregroundStyle(Palette.secondary).padding(.top, 10)
            Text("日常陪伴").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                .padding(.top, 44).padding(.bottom, 13).padding(.leading, 12)
            VStack(spacing: 7) {
                ForEach(HealthStore.Page.allCases, id: \.self) { page in
                    Button { store.selectedPage = page } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.symbol).font(.system(size: 15)).frame(width: 18)
                            Text(page.rawValue).font(.system(size: 13, weight: store.selectedPage == page ? .semibold : .regular))
                            Spacer()
                            if store.selectedPage == page { Circle().fill(Palette.green).frame(width: 5, height: 5) }
                        }.foregroundStyle(store.selectedPage == page ? Palette.green : Palette.secondary)
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(store.selectedPage == page ? Color.white.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("nav-\(page)")
                }
            }
            Spacer(minLength: 20)
            VStack(spacing: 6) {
                Mascot(size: 81, resting: store.engine.isPaused, animate: !store.preferences.reduceMotion)
                    .padding(.top, 10)
                Text("慢慢来，也很好").font(.system(size: 12, weight: .medium))
                Text("让小芽陪你过好每一天").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                Button {
                    store.updatePreferences { $0.petVisible.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(store.preferences.petVisible ? Palette.green : Palette.secondary).frame(width: 5, height: 5)
                        Text(store.preferences.petVisible ? "桌宠已开启" : "开启桌宠")
                        Image(systemName: store.preferences.petVisible ? "checkmark" : "plus").font(.system(size: 8, weight: .semibold))
                    }.font(.system(size: 10)).foregroundStyle(Palette.green).padding(.horizontal, 13).padding(.vertical, 8)
                        .background(.white.opacity(0.75), in: Capsule())
                }.buttonStyle(.plain).padding(.top, 9).padding(.bottom, 17)
                    .help("桌宠可以拖动；点击打开主面板，右键显示快捷操作")
            }.frame(maxWidth: .infinity).background(Palette.greenLight.opacity(0.62), in: RoundedRectangle(cornerRadius: 18))
            HStack(spacing: 5) {
                Image(systemName: "lock.shield").font(.system(size: 10))
                Text("只属于你的健康小角落").font(.system(size: 9))
            }.foregroundStyle(Palette.secondary).frame(maxWidth: .infinity).padding(.top, 21).padding(.bottom, 24)
        }.padding(.horizontal, 19).background(Palette.sidebar)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 11) {
                Text(store.selectedPage == .today ? dateHeading : (store.selectedPage == .history ? "LITTLE STEPS, EVERY DAY" : "MAKE YOURSELF AT HOME"))
                    .font(.system(size: 10, weight: .medium)).tracking(1.1).foregroundStyle(Palette.secondary)
                Text(store.selectedPage == .today ? "好好工作，也好好休息。" : (store.selectedPage == .history ? "每一点照顾，都有迹可循。" : "按你的节奏，陪伴你。"))
                    .font(.system(size: 26, weight: .semibold)).tracking(0.3)
                Text(store.selectedPage == .today ? "小小的暂停，是为了走得更远。" : (store.selectedPage == .history ? "不必追求完美，今天多关心自己一点就好。" : "少一点打扰，多一点刚刚好的关心。"))
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle().fill(store.remindersMuted ? Palette.orange : Palette.green).frame(width: 6, height: 6)
                Text(store.statusText).font(.system(size: 11, weight: .medium))
            }.foregroundStyle(Palette.green).padding(.horizontal, 13).padding(.vertical, 8)
                .background(Palette.greenLight, in: Capsule()).padding(.top, 24)
        }
    }

    private var dateHeading: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 · EEEE"
        return "TODAY  /  \(formatter.string(from: store.now))" + (store.isDemo ? " · 示例预览" : "")
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: store.toast == nil ? "heart" : "checkmark.circle.fill")
                Text(store.toast ?? "照顾自己，从一个小习惯开始。")
            }.font(.system(size: 11)).foregroundStyle(store.toast == nil ? Palette.secondary : Palette.green)
                .animation(.easeInOut(duration: 0.2), value: store.toast)
            Spacer()
            Text("SPROUT  1.0").font(.system(size: 8, weight: .medium)).tracking(1.6).foregroundStyle(Palette.secondary.opacity(0.65))
        }.frame(height: 18)
    }
}

@MainActor struct DashboardView: View {
    @ObservedObject var store: HealthStore
    var body: some View {
        VStack(spacing: 18) {
            focusCard
            HStack(alignment: .top, spacing: 18) {
                waterCard.frame(maxWidth: .infinity)
                achievementCard.frame(width: 223)
            }
        }
    }

    private var focusCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: store.engine.phase == .resting ? "wind" : "sun.max")
                    Text(heroTitle).font(.system(size: 13, weight: .medium))
                }.foregroundStyle(Palette.green)
                Text(timerLabel).font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.top, 24)
                Text(store.pendingBreak != nil ? "欢迎回来" : (store.engine.phase == .due ? "动一动" : store.engine.displayTime))
                    .font(.system(size: store.pendingBreak != nil ? 43 : (store.engine.phase == .due ? 49 : 63), weight: .light, design: .rounded))
                    .monospacedDigit().tracking(1.5).padding(.top, 3)
                    .accessibilityLabel(store.pendingBreak != nil ? "起身活动待确认" : (store.engine.phase == .due ? "休息提醒已到" : "剩余 \(store.engine.displayTime)"))
                Text(timerDetail).font(.system(size: 11)).foregroundStyle(Palette.secondary).padding(.top, 5)
                HStack(spacing: 10) {
                    Button {
                        if store.pendingBreak != nil { store.confirmBreak() }
                        else if store.engine.phase == .resting { store.cancelBreak() } else { store.startBreak() }
                    } label: {
                        Label(store.pendingBreak != nil ? "活动过了，记一次" : (store.engine.phase == .resting ? "结束本次休息" : "现在休息一下"), systemImage: store.engine.phase == .resting ? "arrow.uturn.backward" : "figure.walk")
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("primary-break")
                    if store.pendingBreak != nil {
                        Button("没有，继续专注") { store.dismissBreak() }.buttonStyle(SoftButtonStyle())
                    } else if store.engine.phase == .due {
                        Button("5 分钟后") { store.snooze() }.buttonStyle(SoftButtonStyle())
                    } else {
                        Button { store.togglePause() } label: {
                            Image(systemName: store.engine.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12)).frame(width: 41, height: 41)
                                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).foregroundStyle(Palette.green)
                            .help(store.engine.isPaused ? "继续计时" : "暂停所有提醒")
                            .accessibilityLabel(store.engine.isPaused ? "继续计时" : "暂停计时")
                    }
                }.padding(.top, 20)
            }.padding(.leading, 28).padding(.vertical, 24)
            Spacer(minLength: 0)
            MascotScene(resting: store.engine.phase == .resting || store.engine.isPaused,
                        happy: store.engine.phase == .due,
                        animate: !store.preferences.reduceMotion)
                .padding(.trailing, 13)
        }.frame(maxWidth: .infinity, minHeight: 284)
            .background(LinearGradient(colors: [Color(hex: 0xE8EFDF), Color(hex: 0xEFF2E6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Rectangle().fill(Palette.green.opacity(0.19)).frame(width: geo.size.width * store.engine.progress, height: 3)
                }.frame(height: 3).padding(.horizontal, 25).padding(.bottom, 1)
            }
    }

    private var heroTitle: String {
        if store.pendingBreak != nil { return "刚才有起身活动一下吗？" }
        if store.engine.phase == .resting { return "暂时离开屏幕，回到身体。" }
        if store.engine.phase == .due { return "这一刻，留一点时间给自己。" }
        return "专注一会儿，记得动一动。"
    }
    private var timerLabel: String {
        if let candidate = store.pendingBreak {
            return candidate.fromIdle ? "检测到键鼠闲置约 \(candidate.seconds / 60) 分钟" : "休息倒计时已结束"
        }
        if store.idleAway && store.engine.phase != .resting { return "键鼠闲置超过 1 分钟 · 暂缓计时" }
        if store.engine.isPaused { return "计时已暂停 · 随时可以继续" }
        if store.quiet && store.engine.phase != .resting { return "安静时段 · 计时暂停中" }
        switch store.engine.phase {
        case .focus: return store.engine.isSnoozed ? "距离稍后提醒" : "距离下次起身还有"
        case .due: return "小芽轻轻提醒你"
        case .resting: return "这段时间，留给肩颈和眼睛"
        }
    }
    private var timerDetail: String {
        if store.pendingBreak != nil { return "确认后才记录；60 秒未回应会自动继续。" }
        switch store.engine.phase {
        case .focus: return "每 \(store.preferences.focusMinutes) 分钟  ·  休息 \(store.preferences.breakMinutes) 分钟"
        case .due: return "站一站，走几步，看看远处。"
        case .resting: return "起身走走，自然呼吸。结束后确认记录。"
        }
    }

    private var waterCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeading(symbol: "drop", title: "今日饮水", color: Palette.orange)
                    Spacer()
                    Text("\(Int(store.waterProgress * 100))%")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.orange)
                        .padding(.horizontal, 9).padding(.vertical, 5).background(Palette.peach, in: Capsule())
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.today.waterML.formatted()).font(.system(size: 34, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("/ \(store.preferences.waterGoalML.formatted()) mL").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    Spacer()
                }
                HStack(spacing: 0) {
                    ForEach(0..<8) { index in
                        let filled = Double(store.today.waterML) >= Double(index + 1) * Double(store.preferences.waterGoalML) / 8
                        Image(systemName: filled ? "mug.fill" : "mug")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(filled ? Palette.orange : Color(hex: 0xDCE1D8))
                            .frame(maxWidth: .infinity)
                    }
                }.accessibilityElement(children: .ignore).accessibilityLabel("饮水目标已完成百分之\(Int(store.waterProgress * 100))")
                HStack(spacing: 9) {
                    Button { store.addWater() } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus")
                            Text("喝一杯")
                            Text("\(store.preferences.cupML) mL").foregroundStyle(Palette.orange.opacity(0.85))
                        }.font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 11)
                            .foregroundStyle(Color(hex: 0x97633B)).background(Palette.peach, in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).accessibilityIdentifier("add-water")
                    Button { store.undoWater() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 12)).frame(width: 34, height: 35)
                    }.buttonStyle(.plain).foregroundStyle(Palette.secondary).disabled(store.todayWater.isEmpty)
                        .help("撤销最近一杯").accessibilityLabel("撤销最近一杯")
                }
                Text(store.todayWater.isEmpty ? "第一杯水，从现在开始。" : "最近一杯 \(store.todayWater[0].date.formatted(date: .omitted, time: .shortened)) · 每一口都算数")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
    }

    private var achievementCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(symbol: "sparkles", title: "今日小成就")
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(String(format: "%02d", store.today.breakCount)).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("次起身活动").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }.padding(.top, 5)
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 11))
                    Text("累计休息 \(store.today.breakSeconds / 60) 分钟").font(.system(size: 11))
                }.foregroundStyle(Palette.secondary)
                Rectangle().fill(Palette.line).frame(height: 1).padding(.top, 2)
                Text(store.today.breakCount == 0 ? "从一次小小的起身开始，\n让身体舒展一下。" : "每一次暂停，\n都是对自己的照顾。")
                    .font(.system(size: 11)).lineSpacing(5).foregroundStyle(Palette.green)
                Button { store.selectedPage = .history } label: {
                    HStack { Text("看看我的记录"); Image(systemName: "arrow.up.right").font(.system(size: 9)) }
                        .font(.system(size: 10))
                }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
            }
        }
    }
}
