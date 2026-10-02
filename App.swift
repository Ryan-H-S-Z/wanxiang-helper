import SwiftUI
import AppKit

private let accent = Color(red: 0.43, green: 0.85, blue: 0.72)
private let muted = Color(red: 0.57, green: 0.64, blue: 0.67)

@main
struct WanxiangApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("万象棋 · 升级助手", id: "main") {
            CalculatorView()
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 620, height: 760)
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

final class CalculatorState: ObservableObject {
    @Published var page = 0
    @Published var selectedEquipment = ""
    @Published var equipmentQuery = ""
    @Published var equipmentDetail: Equipment?
    @Published var round = 1
    @Published var roundText = "1"
    var naturalXP: Int { UpgradeCalculator.naturalExperience(afterRound: round) }
    @Published var level: Int = 1
    @Published var xp: Int = 0
    @Published var xpText = "0"
    @Published var hasYixing: Bool = false
    @Published var awakened: Bool = false
    @Published var showRules: Bool = false
    @Published var pin: Bool = false
}

struct CalculatorView: View {
    @StateObject private var model = CalculatorState()
    @StateObject private var recommendations = RecommendationStore()
    private var level: Int { get { model.level } nonmutating set { model.level = newValue } }
    private var xp: Int { get { model.xp } nonmutating set { model.xp = newValue; model.xpText = String(newValue) } }
    private var hasYixing: Bool { get { model.hasYixing } nonmutating set { model.hasYixing = newValue } }
    private var awakened: Bool { get { model.awakened } nonmutating set { model.awakened = newValue } }
    private var showRules: Bool { get { model.showRules } nonmutating set { model.showRules = newValue } }
    private var pin: Bool { get { model.pin } nonmutating set { model.pin = newValue } }
    private var maxXP: Int { level < 6 ? UpgradeCalculator.requirements[level - 1] - 1 : 0 }
    private var rows: [UpgradeCost] {
        UpgradeCalculator.calculate(level: level, experience: xp, hasYixing: hasYixing, awakened: awakened)
    }
    private var nextCosts: [Int: Int] {
        UpgradeCalculator.projectedCosts(level: level, experience: xp, hasYixing: hasYixing, awakened: awakened, naturalXP: model.naturalXP)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("王者万象棋").font(.system(size: 12, weight: .medium)).foregroundStyle(accent)
                    Text(["升级，还差多少？", "装备，该怎么合？", "这局，选谁来赢？"][model.page]).font(.system(size: 27, weight: .semibold))
                    Text(["选好当前状态，后续花费一目了然。", "全部装备总览，点击成品查看来源。", "先排除禁用阵营，再挑可用强阵。"][model.page]).font(.system(size: 12)).foregroundStyle(muted)
                }.frame(width: 258, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    ForEach(0...2, id: \.self) { page in
                        Button { model.page = page } label: {
                            Text(["升级计算", "装备合成", "阵容推荐"][page])
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 7).padding(.vertical, 8)
                                .foregroundStyle(model.page == page ? Color.black : Color.white.opacity(0.7))
                                .background(model.page == page ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityAddTraits(model.page == page ? .isSelected : [])
                    }
                }.padding(3).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                Button {
                    pin.toggle()
                    NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "万象棋 · 升级助手" })?.level = pin ? .floating : .normal
                } label: { Image(systemName: pin ? "pin.fill" : "pin").foregroundStyle(pin ? accent : muted).frame(width: 28, height: 28) }
                .buttonStyle(.plain).help(pin ? "取消窗口置顶" : "窗口置顶").accessibilityLabel("窗口置顶")
            }.frame(height: 80, alignment: .top)
            Group {
            if model.page == 0 {
            VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("当前棋手等级").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("LEVEL \(level)").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                }
                HStack(spacing: 8) {
                    ForEach(1...6, id: \.self) { value in
                        Button { level = value; xp = 0 } label: {
                            Text("\(value)").font(.system(size: 20, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 42)
                                .foregroundStyle(level == value ? Color.black : Color.white.opacity(0.75))
                                .background(level == value ? accent : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).accessibilityLabel("当前等级 \(value)").accessibilityAddTraits(level == value ? .isSelected : [])
                    }
                }
                HStack {
                    Text("当前经验").font(.system(size: 13))
                    Text("本级已累积，默认 0").font(.system(size: 11)).foregroundStyle(muted)
                    Spacer()
                    TextField("0", text: Binding(
                        get: { model.xpText },
                        set: { value in
                            if value.isEmpty { model.xpText = ""; model.xp = 0; return }
                            guard value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return }
                            let bounded = min(Int(value) ?? maxXP, maxXP)
                            model.xpText = String(bounded)
                            model.xp = bounded
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .monospacedDigit()
                    .accessibilityLabel("当前经验输入框")
                    .help("可输入 0–\(maxXP)，也可点击右侧箭头增减")
                    .disabled(level == 6)
                    .onSubmit { model.xpText = String(xp) }
                    Text("/ \(level < 6 ? UpgradeCalculator.requirements[level - 1] : 0)")
                        .monospacedDigit().font(.system(size: 13, weight: .medium))
                        .frame(width: 30, alignment: .leading)
                    Stepper("当前经验", value: Binding(get: { xp }, set: { xp = $0 }), in: 0...maxXP).labelsHidden().disabled(level == 6)
                }
                Divider().overlay(Color.white.opacity(0.04))
                HStack {
                    Toggle("弈星在场", isOn: $model.hasYixing).toggleStyle(.switch).tint(accent)
                    Spacer(minLength: 30)
                    Toggle("弈星已觉醒", isOn: $model.awakened).toggleStyle(.switch).tint(accent).disabled(!hasYixing)
                }.font(.system(size: 13))
                Text(hasYixing ? "每次升级后获得 \(awakened ? 4 : 2) 经验，用于下一次升级。" : "未计入弈星加成。")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }.padding(16).frame(height: 224).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            HStack {
                Text("当前回合").font(.system(size: 12, weight: .medium))
                TextField("1", text: Binding(
                    get: { model.roundText },
                    set: { value in
                        if value.isEmpty { model.roundText = ""; model.round = 1; return }
                        guard value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return }
                        let bounded = min(max(Int(value) ?? 999, 1), 999)
                        model.roundText = String(bounded)
                        model.round = bounded
                    }
                ))
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .frame(width: 52).monospacedDigit().accessibilityLabel("当前回合输入框")
                .onSubmit { model.roundText = String(model.round) }
                Stepper("当前回合", value: Binding(
                    get: { model.round },
                    set: { model.round = $0; model.roundText = String($0) }
                ), in: 1...999).labelsHidden()
                Spacer()
                Text("第 \(model.round) → \(model.round + 1) 回合 · \(model.naturalXP == 3 ? "拍卖 +3" : "战斗 +1") 经验")
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(accent)
            }.frame(height: 24)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("升级预算").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("从当前状态出发 · 单位：能量").font(.system(size: 11)).foregroundStyle(muted)
                }
                if rows.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal").font(.system(size: 32)).foregroundStyle(accent)
                        Text("已达 6 级，无需继续升级").font(.system(size: 16, weight: .medium))
                        Text("本局升级预算已完成").foregroundStyle(muted).font(.system(size: 12))
                    }.frame(maxWidth: .infinity, minHeight: 244)
                } else {
                    HStack {
                        Text("目标等级").frame(maxWidth: .infinity, alignment: .leading)
                        Text("现在升级").frame(width: 85, alignment: .trailing)
                        Text("下轮升级").frame(width: 105, alignment: .trailing)
                        Text("下轮少花").frame(width: 80, alignment: .trailing)
                    }.font(.system(size: 11)).foregroundStyle(muted).padding(.horizontal, 14)
                    VStack(spacing: 6) {
                        ForEach(rows) { row in
                            HStack {
                                HStack(spacing: 8) {
                                    Text("\(row.level)").font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("级").font(.system(size: 11)).foregroundStyle(muted)
                                    if row.id == rows.first?.id { Text("下一等级").font(.system(size: 10)).foregroundStyle(accent) }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(row.totalCost)").font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(Color.white).frame(width: 85, alignment: .trailing)
                                Text("\(nextCosts[row.level] ?? 0)").font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(accent).frame(width: 105, alignment: .trailing)
                                Text(row.totalCost > (nextCosts[row.level] ?? 0) ? "−\(row.totalCost - (nextCosts[row.level] ?? 0))" : "—").font(.system(size: 12)).foregroundStyle(muted).frame(width: 80, alignment: .trailing)
                            }.monospacedDigit().padding(.horizontal, 14).frame(height: 43)
                                .background(Color.white.opacity(row.id == rows.first?.id ? 0.065 : 0.025), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
            }
            // Reserve the maximum table height so changing row count never reflows the controls.
            .frame(height: 300, alignment: .top)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("下轮 = 当前回合结算后；第 3、7、11 回合结束后拍卖。").font(.system(size: 11)).foregroundStyle(muted)
                    Text("1 能量 = 1 经验 · 战斗 +1 / 拍卖 +3").font(.system(size: 11)).foregroundStyle(muted)
                }
                Spacer()
                Button("计算规则") { showRules = true }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent)
            }.frame(height: 32)
            }
            } else if model.page == 1 {
                EquipmentView(model: model)
            } else {
                RecommendationView(store: recommendations)
            }
            }.frame(width: 576, height: 624, alignment: .topLeading)
        }
        .transaction { $0.animation = nil }
        .padding(22).frame(width: 620, height: 760)
        .background(LinearGradient(colors: [Color(red: 0.065, green: 0.11, blue: 0.13), Color(red: 0.045, green: 0.065, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .onChange(of: hasYixing) { value in if !value { awakened = false } }
        .sheet(isPresented: $model.showRules) {
            VStack(alignment: .leading, spacing: 16) {
                Text("计算规则").font(.title2.bold())
                Text("1→2 / 2→3 / 3→4 / 4→5 / 5→6 级\n所需经验：7 / 13 / 17 / 23 / 27").lineSpacing(6)
                Text("当前经验应填写游戏中显示的本级经验，包含此前已获得的弈星经验。弈星在后续每次升级完成后返还 2 经验，觉醒后返还 4 经验；达到目标等级时获得的返还，不抵扣达到该等级的费用。")
                Text("1 能量购买 1 经验。每场战斗结束获得 1 经验，每轮拍卖结束获得 3 经验。已获得的自然经验应计入「当前经验」；「现在升级」不提前扣除未来经验；「下轮升级」指当前回合结算后、进入下一回合时升级。第 3、7、11 回合结束后进入拍卖，拍卖结束后分别进入第 4、8、12 回合；这三次回合过渡计入 3 拍卖经验；其他回合加 1 战斗经验，两者不叠加。例如当前第 3 回合，拍卖结束进入第 4 回合的预算扣除 3 经验；当前第 4 回合，进入第 5 回合仅扣除 1 经验。回合输入不会改写当前经验，避免重复计算此前已获得的经验。如自然经验触发升级，会接着计入弈星返还。下轮所需金额为 0 表示自然经验已足够到达该等级。计算假设弈星全程在场，且觉醒状态不变；不计其他卡牌、天赋或棋手技能。")
                Link("经验表来源：万象棋谱", destination: URL(string: "https://whatsyour.fun/calculator")!)
                Link("弈星效果来源：王者万象棋 Wiki", destination: URL(string: "https://hokace.wiki/zh/heroes/yixing/")!)
                Text("社区资料核对：2026-10-02。请以游戏内规则为准。非官方玩家工具。").font(.caption).foregroundStyle(.secondary)
                HStack { Spacer(); Button("知道了") { showRules = false }.keyboardShortcut(.defaultAction) }
            }.font(.system(size: 13)).padding(26).frame(width: 470)
        }
    }
}
