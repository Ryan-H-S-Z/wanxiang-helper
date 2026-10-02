import Foundation

struct EquipmentAttribute: Codable {
    let label: String
    let value: String
}

struct Equipment: Codable, Identifiable {
    let id: String
    let name: String
    let effect: String
    let attributes: [EquipmentAttribute]
    let related: [String]
    let source: String
    let image: String
    let version: String
}

struct EquipmentCatalog: Codable {
    let bases: [Equipment]
    let results: [Equipment]

    func origins(for item: Equipment) -> [Equipment] {
        bases.filter { $0.related.contains(item.id) }
    }

    func matchingBases(query: String) -> [Equipment] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return bases }
        return bases.filter { base in
            ([base] + outcomes(for: base)).contains { $0.name.localizedCaseInsensitiveContains(term) || $0.effect.localizedCaseInsensitiveContains(term) }
        }
    }

    func outcomes(for base: Equipment) -> [Equipment] {
        base.related.compactMap { id in results.first { $0.id == id } }
    }

    func validate() throws {
        let all = bases + results
        guard !bases.isEmpty, Set(all.map(\.id)).count == all.count,
              all.allSatisfy({ !$0.name.isEmpty && !$0.effect.isEmpty && URL(string: $0.source)?.scheme == "https" }),
              bases.allSatisfy({ base in
                  !base.related.isEmpty && Set(base.related).count == base.related.count &&
                  base.related.allSatisfy { id in results.contains { $0.id == id && $0.related.contains(base.id) } }
              }) else { throw CocoaError(.fileReadCorruptFile) }
    }

    static func load(from url: URL) throws -> EquipmentCatalog {
        let catalog = try JSONDecoder().decode(EquipmentCatalog.self, from: Data(contentsOf: url))
        try catalog.validate()
        return catalog
    }

    static let bundled: Result<EquipmentCatalog, Error> = Result {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Equipment/catalog.json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }
}
