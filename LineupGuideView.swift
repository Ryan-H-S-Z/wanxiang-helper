import SwiftUI

struct LineupGuideView: View {
    let plan: LineupPlan
    let banned: String
    private let accent = Color(red: 0.43, green: 0.85, blue: 0.72)
    private var guide: LineupGuide? { LineupGuide.bundled.first { $0.matches(plan) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("阵容核心 · 排行结构").font(.headline)
            Text((plan.cores ?? []).joined(separator: " · "))
                .foregroundStyle(accent).fixedSize(horizontal: false, vertical: true)
            if let guide {
                Divider()
                Text("同体系攻略参考 · \(guide.title)").font(.headline)
                Text("适用棋手：\(guide.player) · 攻略快照 \(guide.date)")
                    .font(.caption).foregroundStyle(.secondary)
                if guide.factions.contains(banned) {
                    Text("此攻略的过渡或功能牌涉及被禁的\(banned)，本局不适用。排行阵容仍可用，但不能直接套用该攻略。")
                        .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("参考攻略与排行并非完全相同的阵容；以下站位和配装对应攻略分支，不继承排行胜率。")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("主核心：" + guide.cores.joined(separator: " · ")).foregroundStyle(accent)
                    let extra = guide.required.filter { name in !plan.heroes.contains { $0.name == name } }
                    if !extra.isEmpty {
                        Text("攻略另涉及（含过渡）：" + extra.joined(separator: "、"))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("站位参考 · 第 1 排在前").font(.headline)
                    board(guide)
                    Text(guide.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("核心配装与合成来源").font(.headline)
                    ForEach(guide.equipment.indices, id: \.self) { i in
                        let build = guide.equipment[i]
                        Text(build.hero).fontWeight(.semibold).foregroundStyle(accent)
                        ForEach(build.items, id: \.self) { name in
                            equipmentRow(name)
                        }
                    }
                    Text("前中后期运营 · 手册摘要").font(.headline)
                    ForEach(guide.stages.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(["前期 · 过渡", "中期 · 成型", "后期 · 对位"][i]).fontWeight(.semibold).foregroundStyle(accent)
                            Text(guide.stages[i]).fixedSize(horizontal: false, vertical: true)
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                if let url = URL(string: guide.source) { Link("阅读完整攻略与逐回合操作 ↗", destination: url) }
                Text("攻略为人工核对摘要；刷新按钮更新排行，不自动改写攻略。具体数值以游戏当前版本为准。")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("这套阵容暂未匹配到已核实的站位与分阶段攻略。排行源没有配装记录，不生成猜测的装备和站位。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.font(.system(size: 11))
    }
    private func board(_ guide: LineupGuide) -> some View {
        VStack(spacing: 4) {
            Text("敌方方向 ↑").font(.caption2).foregroundStyle(.secondary)
            ForEach(1...4, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(Array("ABCDEFG"), id: \.self) { column in
                        let cell = "\(column)\(row)"
                        let hero = guide.board.first { $0.cell == cell }?.hero
                        VStack(spacing: 3) {
                            Text(cell).font(.system(size: 8)).foregroundStyle(.secondary)
                            if let hero {
                                HeroPortrait(name: hero, size: 28, showsTier: false)
                            } else {
                                Text("·").foregroundStyle(.secondary).frame(height: 42)
                            }
                        }.frame(maxWidth: .infinity).frame(height: 66)
                            .background(hero == nil ? Color.white.opacity(0.03) : accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel("\(cell)：\(hero ?? "空位")")
                    }
                }
            }
        }
    }
    @ViewBuilder private func equipmentRow(_ name: String) -> some View {
        if case .success(let catalog) = EquipmentCatalog.bundled,
           let item = catalog.results.first(where: { $0.name == name }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("需求装备").font(.caption2).foregroundStyle(.secondary)
                    ForEach(catalog.origins(for: item)) { base in
                        HStack(spacing: 7) {
                            EquipmentIcon(item: base, size: 30)
                            Text(base.name).fixedSize(horizontal: false, vertical: true)
                        }.help(base.effect)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").foregroundStyle(accent)
                    .accessibilityLabel("铸造成")
                VStack(alignment: .leading, spacing: 6) {
                    Text("合成装备").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 7) {
                        EquipmentIcon(item: item, size: 30)
                        Text(item.name).fontWeight(.medium).fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(10)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .help(item.effect)
        } else { Text(name + " · 暂无已核实的合成来源").foregroundStyle(.secondary) }
    }
}
