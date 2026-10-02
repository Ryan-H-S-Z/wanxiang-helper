import Foundation

func costs(_ level: Int, _ xp: Int, _ has: Bool, _ awake: Bool) -> [Int] {
    UpgradeCalculator.calculate(level: level, experience: xp, hasYixing: has, awakened: awake).map(\.totalCost)
}
assert(costs(1, 0, false, false) == [7, 20, 37, 60, 87])
assert(costs(1, 0, true, false) == [7, 18, 33, 54, 79])
assert(costs(1, 0, true, true) == [7, 16, 29, 48, 71])
assert(costs(3, 5, true, true) == [12, 31, 54])
assert(costs(5, 26, true, true) == [1]) // final reward does not discount the current upgrade
assert(costs(6, 0, true, true).isEmpty)
assert(costs(1, 0, false, true) == costs(1, 0, false, false))
// Natural experience already earned reduces immediate cost, independent of its source.
assert(costs(1, 1, false, false) == [6, 19, 36, 59, 86])
assert(costs(1, 3, false, false) == [4, 17, 34, 57, 84])
for level in 1...5 {
    for xp in 0..<UpgradeCalculator.requirements[level - 1] {
        for bonus in [0, 2, 4] {
            let rows = UpgradeCalculator.calculate(level: level, experience: xp, hasYixing: bonus > 0, awakened: bonus == 4)
            var paid = 0
            for (offset, row) in rows.enumerated() {
                paid += row.stepCost
                let expected = UpgradeCalculator.requirements[(level - 1)..<(row.level - 1)].reduce(0, +) - xp - offset * bonus
                assert(row.totalCost == expected && row.totalCost == paid && row.saved == offset * bonus)
            }
        }
    }
}
print("PASS: all levels, all valid XP, all three Yixing states, natural XP and max-level boundaries")
assert(UpgradeCalculator.projectedCosts(level: 1, experience: 0, hasYixing: false, awakened: false, naturalXP: 1)[6] == 86)
assert(UpgradeCalculator.projectedCosts(level: 1, experience: 6, hasYixing: true, awakened: true, naturalXP: 1) == [2: 0, 3: 9, 4: 22, 5: 41, 6: 64])
assert(UpgradeCalculator.projectedCosts(level: 5, experience: 26, hasYixing: true, awakened: true, naturalXP: 3) == [6: 0])
for level in 1...5 {
    for xp in 0..<UpgradeCalculator.requirements[level - 1] {
        for bonus in [0, 2, 4] {
            for natural in [1, 3] {
                let current = UpgradeCalculator.calculate(level: level, experience: xp, hasYixing: bonus > 0, awakened: bonus == 4)
                let future = UpgradeCalculator.projectedCosts(level: level, experience: xp, hasYixing: bonus > 0, awakened: bonus == 4, naturalXP: natural)
                for row in current { assert(future[row.level] == max(0, row.totalCost - natural)) }
            }
        }
    }
}
print("PASS: next battle / auction projections, automatic level-up, Yixing reward and level cap")
for round in 1...40 {
    assert(UpgradeCalculator.naturalExperience(afterRound: round) == ([3, 7, 11].contains(round) ? 3 : 1))
}
assert(UpgradeCalculator.projectedCosts(level: 1, experience: 0, hasYixing: false, awakened: false, naturalXP: UpgradeCalculator.naturalExperience(afterRound: 3))[2] == 4)
assert(UpgradeCalculator.projectedCosts(level: 1, experience: 0, hasYixing: false, awakened: false, naturalXP: UpgradeCalculator.naturalExperience(afterRound: 16))[2] == 6)
print("PASS: auctions after rounds 3 / 7 / 11, before rounds 4 / 8 / 12")

for round in [3, 7, 11] {
    assert(UpgradeCalculator.projectedCosts(level: 1, experience: 0, hasYixing: false, awakened: false, naturalXP: UpgradeCalculator.naturalExperience(afterRound: round))[2] == 4)
}
for round in [2, 4, 6, 8, 10, 12, 16] {
    assert(UpgradeCalculator.projectedCosts(level: 1, experience: 0, hasYixing: false, awakened: false, naturalXP: UpgradeCalculator.naturalExperience(afterRound: round))[2] == 6)
}
print("PASS: auction boundary projections and adjacent battle rounds")
let equipmentURL = URL(fileURLWithPath: "Resources/Equipment/catalog.json")
let catalog = try EquipmentCatalog.load(from: equipmentURL)
assert(catalog.bases.count == 8 && catalog.results.count == 32)
assert(catalog.bases.allSatisfy { catalog.outcomes(for: $0).count == 4 })
assert(Set(catalog.bases.flatMap(\.related)) == Set(catalog.results.map(\.id)))
let sword = catalog.bases.first { $0.id == "storm-greatsword" }!
assert(Set(catalog.outcomes(for: sword).map(\.name)) == Set(["纯净苍穹", "铸梦·逐风", "无尽巨剑", "制裁之剑"]))
let armor = catalog.bases.first { $0.id == "guardian-armor" }!
assert(Set(catalog.outcomes(for: armor).map(\.name)) == Set(["不祥征兆", "极寒风暴", "近卫荣耀", "反伤重甲"]))
for item in catalog.bases + catalog.results {
    assert(FileManager.default.fileExists(atPath: "Resources/Equipment/\(item.image)"))
}
print("PASS: 8 bases, 32 linked outcomes, reverse links, distinct branches and 40 bundled icons")
assert(catalog.matchingBases(query: "").count == 8)
assert(catalog.matchingBases(query: "   ").count == 8)
assert(catalog.matchingBases(query: "无尽巨剑").map(\.id) == ["storm-greatsword"])
assert(catalog.matchingBases(query: "不存在的装备").isEmpty)
for base in catalog.bases {
    for item in catalog.outcomes(for: base) {
        assert(catalog.origins(for: item).contains { $0.id == base.id })
    }
}
assert(catalog.bases.allSatisfy { catalog.origins(for: $0).isEmpty })
print("PASS: overview search, empty results and all 32 reverse equipment origins")
let recommendations = try RecommendationCatalog.load(URL(fileURLWithPath: "Resources/Recommendations/catalog.json"))
assert(recommendations.plans.count == 35)
for ban in RecommendationCatalog.factions {
    let ranked = recommendations.ranked(banning: ban)
    assert(!ranked.isEmpty)
    assert(ranked.allSatisfy { !$0.heroes.contains { $0.faction == ban } && $0.samples >= 1000 })
    assert(zip(ranked, ranked.dropFirst()).allSatisfy { $0.score >= $1.score })
}
assert(recommendations.ranked(banning: "逐鹿").first?.id == "4")
assert(recommendations.ranked(banning: "河洛").first?.id == "14")
// Mixed-faction rosters must be excluded even when the title does not name the banned faction.
for plan in recommendations.plans {
    for faction in plan.factions where faction != "无阵营" {
        assert(!recommendations.ranked(banning: faction, minimumSamples: 0).contains { $0.id == plan.id })
    }
}
do {
    _ = try RankingImporter.parse(rankings: "<html>changed</html>", heroIndex: "")
    assertionFailure("Malformed source must fail closed")
} catch {}
print("PASS: 35 lineups, five faction bans, complete mixed-faction exclusion, ranking and invalid refresh rejection")

let guides = try LineupGuide.load(URL(fileURLWithPath: "Resources/Recommendations/guides.json"))
assert(guides.count == 4)
for id in ["4", "14", "23", "17"] {
    let plan = recommendations.plans.first { $0.id == id }!
    assert(guides.contains { $0.matches(plan) })
}
for plan in recommendations.plans {
    assert(!(plan.cores ?? []).isEmpty)
    assert(plan.cores!.allSatisfy { core in plan.heroes.contains { $0.name == core } })
}
let mulanGuide = guides.first { $0.id == "yinglv_mulan" }!
assert(mulanGuide.factions.contains("日落海")) // Transient Luna dependency, even absent from final ranking roster.
for guide in guides {
    for build in guide.equipment {
        for name in build.items {
            let item = catalog.results.first { $0.name == name }!
            assert(!catalog.origins(for: item).isEmpty)
        }
    }
}
print("PASS: four matched reference guides, full core rosters, transient faction dependencies and all equipment recipes")

for ban in RecommendationCatalog.factions {
    let all = recommendations.ranked(banning: ban)
    let options = recommendations.playerOptions(banning: ban)
    assert(Set(options.map(\.name)) == Set(all.flatMap { $0.players.map(\.name) }))
    for option in options {
        let expected = all.filter { $0.players.contains { $0.name == option.name } }
        let actual = recommendations.ranked(banning: ban, player: option.name)
        assert(option.count == expected.count && actual.map(\.id) == expected.map(\.id))
    }
    assert(recommendations.ranked(banning: ban, player: "不存在的棋手").isEmpty)
}
print("PASS: player filter counts match all listed player associations under each faction ban")
