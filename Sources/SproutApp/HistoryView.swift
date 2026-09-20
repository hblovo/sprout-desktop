import SwiftUI
import SproutCore

@MainActor struct HistoryView: View {
    @ObservedObject var store: HealthStore
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 16) {
                    summaryCard(symbol: "drop", label: "最近 7 天饮水", value: String(format: "%.1f", Double(store.week.reduce(0) { $0 + $1.waterML }) / 1000), unit: "L", color: Palette.orange)
                    summaryCard(symbol: "figure.walk", label: "最近 7 天起身", value: "\(store.week.reduce(0) { $0 + $1.breakCount })", unit: "次", color: Palette.green)
                }
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            SectionHeading(symbol: "chart.bar", title: "一点一滴，慢慢积累")
                            Spacer()
                            Text("近 7 天 · 饮水量").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                        HStack(alignment: .bottom, spacing: 22) {
                            ForEach(store.week) { day in
                                VStack(spacing: 9) {
                                    Text(day.waterML == 0 ? "—" : "\(day.waterML)")
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Calendar.current.isDateInToday(day.date) ? Palette.green : Palette.greenLight)
                                        .frame(height: max(4, 85 * Double(day.waterML) / Double(max(store.week.map(\.waterML).max() ?? 0, 250))))
                                    Text(Calendar.current.isDateInToday(day.date) ? "今天" : day.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted))，饮水 \(day.waterML) 毫升，休息 \(day.breakCount) 次")
                            }
                        }.frame(height: 128)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SectionHeading(symbol: "clock.arrow.circlepath", title: "今天的饮水足迹", color: Palette.orange)
                            Spacer()
                            Text("共 \(store.todayWater.count) 笔").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                        if store.todayWater.isEmpty {
                            HStack(spacing: 18) {
                                Image(systemName: "cup.and.saucer").font(.system(size: 27, weight: .ultraLight)).foregroundStyle(Palette.orange)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text("这里还空着，刚好适合一个开始。").font(.system(size: 12))
                                    Text("记录第一杯水，今天的足迹就会出现在这里。").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                }
                                Spacer()
                                Button("记一杯") { store.addWater() }.buttonStyle(PrimaryButtonStyle(compact: true))
                            }.padding(.vertical, 18)
                        } else {
                            ForEach(store.todayWater) { entry in
                                HStack(spacing: 12) {
                                    Image(systemName: "drop.fill").font(.system(size: 12)).foregroundStyle(Palette.orange)
                                        .frame(width: 30, height: 30).background(Palette.peach, in: RoundedRectangle(cornerRadius: 9))
                                    Text("喝了一杯水").font(.system(size: 12))
                                    Text("+\(entry.milliliters) mL").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.orange)
                                    Spacer()
                                    Text(entry.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                    Button { store.removeWater(entry.id) } label: {
                                        Image(systemName: "arrow.uturn.backward").font(.system(size: 11)).padding(6)
                                    }.buttonStyle(.plain).foregroundStyle(Palette.secondary).help("撤销这条记录")
                                        .accessibilityLabel("撤销 \(entry.date.formatted(date: .omitted, time: .shortened)) 的 \(entry.milliliters) 毫升记录")
                                }
                            }
                        }
                    }
                }
                Text("饮水与休息记录按本地日期归档，跨天自动开始新的一页。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).padding(.bottom, 8)
            }.padding(1)
        }.scrollIndicators(.hidden)
    }

    private func summaryCard(symbol: String, label: String, value: String, unit: String, color: Color) -> some View {
        Card(padding: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 13) {
                    Text(label).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value).font(.system(size: 29, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(unit).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                }
                Spacer()
                Image(systemName: symbol).font(.system(size: 23, weight: .light)).foregroundStyle(color)
                    .frame(width: 52, height: 52).background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
            }
        }
    }
}
