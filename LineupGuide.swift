import Foundation

struct GuidePosition: Codable { let cell: String; let hero: String }
struct GuideEquipment: Codable { let hero: String; let items: [String] }
struct LineupGuide: Codable, Identifiable {
    let id: String
    let title: String
    let player: String
    let cores: [String]
    let required: [String]
    let factions: [String]
    let board: [GuidePosition]
    let equipment: [GuideEquipment]
    let stages: [String]
    let note: String
    let source: String
    let date: String
    func matches(_ plan: LineupPlan) -> Bool {
        let names = Set(plan.heroes.map(\.name))
        return cores.allSatisfy(names.contains) && plan.players.contains { $0.name == player }
            && Double(names.intersection(required).count) / Double(max(names.count, 1)) >= 0.6
    }
    static func load(_ url: URL) throws -> [Self] {
        let guides = try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
        for g in guides {
            guard g.stages.count == 3, !g.cores.isEmpty, g.cores.allSatisfy(g.required.contains),
                  !g.factions.isEmpty, Set(g.board.map(\.cell)).count == g.board.count,
                  g.board.allSatisfy({ $0.cell.range(of: "^[A-G][1-4]$", options: .regularExpression) != nil }),
                  URL(string: g.source)?.host == "wxqwiki.com" else { throw RankingError.invalidData }
        }
        return guides
    }
    static var bundled: [Self] {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Recommendations/guides.json") else { return [] }
        return (try? load(url)) ?? []
    }
}
