import SwiftUI

@MainActor final class RecommendationStore: ObservableObject {
    @Published var catalog: RecommendationCatalog?
    @Published var refreshing = false
    @Published var status = ""
    @Published var banned = ""
    @Published var selectedID = ""
    @Published var playerFilter = ""
    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WanxiangHelper/recommendations.json")
    }
    init() {
        if let cached = try? RecommendationCatalog.load(cacheURL), cached.plans.allSatisfy({ $0.cores != nil }) { catalog = cached; status = "已载入上次成功刷新资料" }
        else if let url = Bundle.main.resourceURL?.appendingPathComponent("Recommendations/catalog.json"),
                let bundled = try? RecommendationCatalog.load(url) { catalog = bundled; status = "内置快照 · 可手动刷新" }
        else { status = "推荐资料未能载入，请点击刷新重试" }
    }
    var available: [LineupPlan] { banned.isEmpty ? [] : catalog?.ranked(banning: banned) ?? [] }
    var playerOptions: [PlayerFilterOption] { banned.isEmpty ? [] : catalog?.playerOptions(banning: banned) ?? [] }
    var ranked: [LineupPlan] { banned.isEmpty ? [] : catalog?.ranked(banning: banned, player: playerFilter) ?? [] }
    var selected: LineupPlan? { ranked.first { $0.id == selectedID } ?? ranked.first }
    func refresh() {
        guard !refreshing else { return }
        refreshing = true; status = "正在获取排行、棋手搭配和英雄阵营…"
        Task {
            defer { refreshing = false }
            do {
                let fresh = try await RankingImporter.refresh()
                let sameSnapshot = fresh.snapshotDate == catalog?.snapshotDate
                let bytes = try JSONEncoder().encode(fresh)
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try bytes.write(to: cacheURL, options: .atomic)
                catalog = fresh
                if !playerFilter.isEmpty && !playerOptions.contains(where: { $0.name == playerFilter }) {
                    playerFilter = ""
                }
                status = sameSnapshot ? "刷新成功 · 来源快照日期未变化" : "刷新成功 · 已更新排行与阵营资料"
            } catch { status = "刷新失败，保留已有资料：\(error.localizedDescription)" }
        }
    }
}

struct RecommendationView: View {
    @ObservedObject var store: RecommendationStore
    private let tint = Color(red: 0.43, green: 0.85, blue: 0.72)
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("按完整阵容排除禁用阵营，再按综合指数排序")
                        .font(.system(size: 12, weight: .medium))
                    Text("快照 \(store.catalog?.snapshotDate ?? "未知") · \(store.catalog?.plans.count ?? 0) 套阵容 · 样本 ≥ 1,000")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
                Button { store.refresh() } label: { Label("刷新", systemImage: "arrow.clockwise") }
                    .disabled(store.refreshing).help("重新获取资料站当前提供的排行及英雄阵营")
            }.frame(height: 42)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("本局禁用阵营").font(.system(size: 12, weight: .semibold))
                    ForEach(RecommendationCatalog.factions, id: \.self) { faction in
                        Button { store.banned = faction; store.selectedID = ""; store.playerFilter = "" } label: {
                            HStack {
                                Image(systemName: store.banned == faction ? "nosign" : "circle")
                                Text(faction)
                                Spacer(minLength: 0)
                            }.font(.system(size: 12, weight: .medium)).padding(11)
                                .foregroundStyle(store.banned == faction ? tint : .white.opacity(0.7))
                                .background(store.banned == faction ? tint.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).accessibilityLabel("禁用\(faction)")
                    }
                    Text("包含被禁阵营的任何棋子，整套排除；无阵营棋子保留。")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
                    Spacer()
                }.frame(width: 128)
                VStack(alignment: .leading, spacing: 10) {
                    if store.banned.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "person.3.sequence.fill").font(.system(size: 30)).foregroundStyle(tint)
                            Text("先选择本局被禁用的阵营").font(.headline)
                            Text("右侧将显示优先棋手、备选方案和完整英雄名单。")
                                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let plan = store.selected {
                        HStack {
                            Text("禁用\(store.banned) · \(store.ranked.count)套可用").font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("快照推荐").font(.system(size: 10)).foregroundStyle(tint)
                        }
                        playerFilters
                        Text("\(store.playerFilter.isEmpty ? "全部阵容" : store.playerFilter) · 上下滚动选择 · ★ 表示英雄品阶")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(store.ranked.enumerated()), id: \.element.id) { index, candidate in
                                    Button { store.selectedID = candidate.id } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("#\(index + 1)").foregroundStyle(tint)
                                                Text(store.playerFilter.isEmpty ? (candidate.players.first?.name ?? "未知棋手") : store.playerFilter).fontWeight(.semibold)
                                                Text(candidate.title).foregroundStyle(.secondary).lineLimit(1)
                                                Spacer(minLength: 0)
                                                Text(String(format: "%.1f", candidate.score)).fontWeight(.semibold)
                                            }.font(.system(size: 11))
                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 6) {
                                                ForEach(candidate.heroes.indices, id: \.self) { i in
                                                    HeroPortrait(name: candidate.heroes[i].name)
                                                }
                                            }
                                        }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(plan.id == candidate.id ? tint.opacity(0.12) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(plan.id == candidate.id ? tint.opacity(0.7) : .clear, lineWidth: 1))
                                    }.buttonStyle(.plain).accessibilityLabel("第\(index + 1)套：\(candidate.title)，英雄：\(candidate.heroes.map(\.name).joined(separator: "、"))")
                                }
                            }.padding(.trailing, 8)
                        }.frame(height: 202).id(store.banned + "|" + store.playerFilter).accessibilityLabel("筛选后的可用阵容列表")
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(plan.title).font(.system(size: 16, weight: .semibold))
                                Text(String(format: "前三 %.1f%% · 登顶 %.1f%% · %d 场", plan.top3 * 100, plan.first * 100, plan.samples))
                                    .font(.system(size: 11)).foregroundStyle(tint)
                                Text("所需阵营：" + plan.factions.joined(separator: " / "))
                                    .font(.system(size: 11, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                LineupGuideView(plan: plan, banned: store.banned)
                                Divider()
                                Text("棋手搭配（按该阵容使用占比）").font(.system(size: 12, weight: .semibold))
                                ForEach(plan.players.indices, id: \.self) { i in
                                    let player = plan.players[i]
                                    Text(String(format: "%@  %.1f%% · %d 场", player.name, player.share, player.count))
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Text("完整英雄名单").font(.system(size: 12, weight: .semibold))
                                ForEach(plan.heroes.indices, id: \.self) { i in
                                    HStack {
                                        Text(plan.heroes[i].name)
                                        Spacer()
                                        Text(plan.heroes[i].faction).foregroundStyle(.secondary)
                                    }.font(.system(size: 12))
                                }
                                if let source = store.catalog?.source, let url = URL(string: source) {
                                    Link("打开完整排行与阵容资料", destination: url).font(.system(size: 11))
                                }
                            }.padding(.trailing, 5)
                        }.id(plan.id).accessibilityLabel("所选阵容详情")
                    } else {
                        Text("当前快照没有满足条件的阵容，请刷新资料或切换禁用阵营。").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.status).lineLimit(2)
                Text("校验：\(store.catalog?.checkedDate ?? "未刷新") · 战绩为全局快照，非该禁用局专属胜率；不保证实时最强。")
                    .foregroundStyle(.secondary)
            }.font(.system(size: 10)).frame(height: 44, alignment: .topLeading)
        }
    }
    private var playerFilters: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("棋手筛选 · 数量为当前禁用条件下的匹配阵容数")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHGrid(rows: [GridItem(.fixed(24)), GridItem(.fixed(24))], spacing: 6) {
                    playerChip(name: "", count: store.available.count)
                    ForEach(store.playerOptions) { option in
                        playerChip(name: option.name, count: option.count)
                    }
                }.padding(.bottom, 5)
            }.frame(height: 57).id(store.banned).accessibilityLabel("棋手筛选与阵容数量")
        }
    }
    private func playerChip(name: String, count: Int) -> some View {
        Button {
            store.playerFilter = name
            store.selectedID = ""
        } label: {
            HStack(spacing: 5) {
                Text(name.isEmpty ? "全部" : name)
                Text("\(count)").monospacedDigit().opacity(0.8)
            }.font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9).frame(height: 24)
                .foregroundStyle(store.playerFilter == name ? Color.black : Color.white.opacity(0.8))
                .background(store.playerFilter == name ? tint : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
            .accessibilityLabel("筛选\(name.isEmpty ? "全部棋手" : name)，\(count)套阵容")
            .help("按来源记录的所有棋手搭配匹配；同一阵容可对应多位棋手。")
    }

}
