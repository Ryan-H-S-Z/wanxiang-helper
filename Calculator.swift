import Foundation

struct UpgradeCost: Identifiable {
    var id: Int { level }
    let level: Int
    let stepCost: Int
    let totalCost: Int
    let saved: Int
}

enum UpgradeCalculator {
    static func naturalExperience(afterRound round: Int) -> Int {
        [3, 7, 11].contains(round) ? 3 : 1
    }

    static let requirements = [7, 13, 17, 23, 27]
    static func projectedCosts(level: Int, experience: Int, hasYixing: Bool, awakened: Bool, naturalXP: Int) -> [Int: Int] {
        guard (1...5).contains(level) else { return [:] }
        var projectedLevel = level
        var carried = min(max(0, experience), requirements[level - 1] - 1) + max(0, naturalXP)
        let bonus = hasYixing ? (awakened ? 4 : 2) : 0
        var result: [Int: Int] = [:]
        while projectedLevel < 6 && carried >= requirements[projectedLevel - 1] {
            carried -= requirements[projectedLevel - 1]
            projectedLevel += 1
            carried += bonus
            result[projectedLevel] = 0
        }
        for row in calculate(level: projectedLevel, experience: carried, hasYixing: hasYixing, awakened: awakened) {
            result[row.level] = row.totalCost
        }
        return result
    }
    static func calculate(level: Int, experience: Int, hasYixing: Bool, awakened: Bool) -> [UpgradeCost] {
        guard (1...6).contains(level), level < 6 else { return [] }
        let xp = min(max(0, experience), requirements[level - 1] - 1)
        let bonus = hasYixing ? (awakened ? 4 : 2) : 0
        var carried = xp
        var total = 0
        var baseline = -xp
        var rows: [UpgradeCost] = []
        for source in level..<6 {
            let required = requirements[source - 1]
            let spend = max(0, required - carried)
            total += spend
            baseline += required
            rows.append(UpgradeCost(level: source + 1, stepCost: spend, totalCost: total, saved: baseline - total))
            // Award only after crossing the level boundary. The final reward cannot pay for reaching it.
            carried = max(0, carried - required) + bonus
        }
        return rows
    }
}
