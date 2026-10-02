import SwiftUI
import AppKit

struct HeroAppearance: Decodable {
    let name: String
    let tier: Int
    let image: String
    static let all: [HeroAppearance] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Heroes/catalog.json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }()
}

struct HeroPortrait: View {
    let name: String
    var size: CGFloat = 32
    var showsTier: Bool = true
    private var info: HeroAppearance? { HeroAppearance.all.first { $0.name == name } }
    var body: some View {
        VStack(spacing: 3) {
            Group {
                if let info, let url = Bundle.main.resourceURL?.appendingPathComponent("Heroes/\(info.image)"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else { Image(systemName: "person.fill").resizable().scaledToFit().padding(6).foregroundStyle(.secondary) }
            }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 6))
            Text(name).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            if showsTier, let info {
                Text(String(repeating: "★", count: info.tier)).font(.system(size: 7))
                    .foregroundStyle(.yellow.opacity(0.85)).accessibilityLabel("\(info.tier)阶")
            }
        }.frame(maxWidth: .infinity)
            .help("\(name)\(info.map { " · \($0.tier)阶（英雄品阶）" } ?? "")")
            .accessibilityElement(children: .combine)
    }
}
