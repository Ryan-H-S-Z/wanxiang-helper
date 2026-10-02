import Foundation

struct LineupHero: Codable { let name: String; let faction: String }
struct LineupPlayer: Codable { let name: String; let share: Double; let count: Int }
struct LineupPlan: Codable, Identifiable {
    let id: String
    let title: String
    let score: Double
    let top3: Double
    let first: Double
    let samples: Int
    let heroes: [LineupHero]
    let players: [LineupPlayer]
    let playbook: [String]
    var cores: [String]? = nil
    var factions: [String] { Array(Set(heroes.map(\.faction))).sorted() }
}
struct PlayerFilterOption: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct RecommendationCatalog: Codable {
    let version: String
    let snapshotDate: String
    let checkedDate: String
    let source: String
    let heroSource: String
    let plans: [LineupPlan]
    static let factions = ["三分之地", "大河流域", "日落海", "河洛", "逐鹿"]
    func ranked(banning faction: String, minimumSamples: Int = 1000, player: String = "") -> [LineupPlan] {
        plans.filter { $0.samples >= minimumSamples && !$0.factions.contains(faction) &&
            (player.isEmpty || $0.players.contains { $0.name == player }) }
            .sorted { $0.score == $1.score ? $0.samples > $1.samples : $0.score > $1.score }
    }
    func playerOptions(banning faction: String) -> [PlayerFilterOption] {
        var counts: [String: Int] = [:]
        for plan in ranked(banning: faction) {
            for name in Set(plan.players.map(\.name)) { counts[name, default: 0] += 1 }
        }
        return counts.map { PlayerFilterOption(name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }
    func validate() throws {
        let known = Set(Self.factions + ["无阵营"])
        guard !plans.isEmpty, Set(plans.map(\.id)).count == plans.count,
              plans.allSatisfy({ !$0.heroes.isEmpty && !$0.players.isEmpty && $0.samples > 0 &&
                  $0.score.isFinite && (0...100).contains($0.score) && (0...1).contains($0.top3) && (0...1).contains($0.first) &&
                  $0.heroes.allSatisfy { known.contains($0.faction) } }) else { throw RankingError.invalidData }
    }
    static func load(_ url: URL) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)); try value.validate(); return value
    }
}
enum RankingError: LocalizedError {
    case invalidData, server(Int)
    var errorDescription: String? {
        switch self {
        case .invalidData: return "资料格式变化或英雄阵营不完整，未替换现有数据。"
        case .server(let code): return "资料站返回 HTTP \(code)，请稍后重试。"
        }
    }
}

// Parse the source's actual ranking records and complete unit tables, not lineup titles.
enum RankingImporter {
    static let rankingURL = URL(string: "https://hokace.wiki/zh/lineups/")!
    static let heroURL = URL(string: "https://hokace.wiki/zh/heroes/taiyi-zhenren/")!
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }
    static func uniqueMap(_ pairs: [[String]]) throws -> [String: String] {
        var result: [String: String] = [:]
        for pair in pairs {
            guard pair.count == 2, result[pair[0]] == nil else { throw RankingError.invalidData }
            result[pair[0]] = pair[1]
        }
        return result
    }
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("Mozilla/5.0 WanxiangHelper/1.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RankingError.server((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let html = String(data: data, encoding: .utf8) else { throw RankingError.invalidData }
        return html
    }
    static func refresh() async throws -> RecommendationCatalog {
        async let rankings = fetch(rankingURL)
        async let heroes = fetch(heroURL)
        return try await parse(rankings: rankings, heroIndex: heroes)
    }
    static func parse(rankings: String, heroIndex: String) throws -> RecommendationCatalog {
        var heroes: [String: LineupHero] = [:]
        for match in matches(#"<a class="hero-index-option" href="([^"]+)"[^>]*>(.*?)</a>"#, heroIndex) {
            guard let name = matches(#"<b[^>]*>(.*?)</b>"#, match[1]).first?.first,
                  let meta = matches(#"<small[^>]*>(.*?)</small>"#, match[1]).first?.first else { throw RankingError.invalidData }
            let faction = clean(meta).components(separatedBy: " · ")[0]
            heroes[match[0]] = LineupHero(name: clean(name), faction: faction)
        }
        let details = try uniqueMap(matches(#"<article class="lineup-detail[^>]*data-lineup-detail="([^"]+)"[^>]*>(.*?)</article>"#, rankings))
        var plans: [LineupPlan] = []
        for match in matches(#"<article class="lineup-list-card[^>]*data-lineup-card([^>]*)>(.*?)</article>"#, rankings) {
            let a = try uniqueMap(matches(#"data-([\w-]+)="([^"]*)"#, match[0]))
            guard let id = a["id"], let detail = details[id],
                  let score = Double(a["score"] ?? ""), let top3 = Double(a["top3"] ?? ""),
                  let first = Double(a["first"] ?? ""), let count = Int(a["count"] ?? ""),
                  let title = matches(#"<h2[^>]*>(.*?)</h2>"#, detail).first?.first,
                  let units = detail.components(separatedBy: "class=\"unit-table\"").dropFirst().first?.components(separatedBy: "推荐配装").first,
                  let command = detail.components(separatedBy: "class=\"commander-list\"").dropFirst().first?.components(separatedBy: "<details").first else { throw RankingError.invalidData }
            var seen = Set<String>(); var roster: [LineupHero] = []
            for path in matches(#"href="(/zh/heroes/[^"]+)""#, units).map({ $0[0] }) where seen.insert(path).inserted {
                guard let hero = heroes[path] else { throw RankingError.invalidData }; roster.append(hero)
            }
            // Require every hero declared on the ranking record to have a resolved faction.
            guard roster.count == (a["heroes"] ?? "").split(separator: ",").count else { throw RankingError.invalidData }
            var players: [LineupPlayer] = []
            for p in matches(#"<strong[^>]*>(.*?)</strong><small[^>]*>(.*?)</small>"#, command) {
                let values = clean(p[1]).components(separatedBy: " · ")
                guard values.count == 2, let share = Double(values[0].replacingOccurrences(of: "%", with: "")),
                      let count = Int(values[1].replacingOccurrences(of: ",", with: "")) else { throw RankingError.invalidData }
                players.append(LineupPlayer(name: clean(p[0]), share: share, count: count))
            }
            let coreSection = detail.components(separatedBy: "class=\"core-heroes\"").dropFirst().first?.components(separatedBy: "</section>").first ?? ""
            let cores = matches(#"<strong[^>]*>(.*?)</strong>"#, coreSection).map { clean($0[0]) }
            guard !cores.isEmpty, cores.allSatisfy({ name in roster.contains { $0.name == name } }) else { throw RankingError.invalidData }
            plans.append(LineupPlan(id: id, title: clean(title), score: score, top3: top3, first: first,
                samples: count, heroes: roster, players: players,
                playbook: ["按完整英雄名单组建阵容，优先保留关键组件。", "根据实际来牌集中培养核心，先保证战力，再补高费棋子。", "来源提供阵容结构和棋手搭配统计，未提供逐回合运营攻略。具体运营需结合天赋与来牌。 "], cores: cores))
        }
        guard let date = matches(#""dateModified":"(\d{4}-\d{2}-\d{2})""#, rankings).first?.first else { throw RankingError.invalidData }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm"; formatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
        let version = matches(#"(v\d{6})"#, rankings).first?.first ?? date
        let catalog = RecommendationCatalog(version: version, snapshotDate: date, checkedDate: formatter.string(from: Date()), source: rankingURL.absoluteString, heroSource: heroURL.absoluteString, plans: plans)
        try catalog.validate(); return catalog
    }
}
