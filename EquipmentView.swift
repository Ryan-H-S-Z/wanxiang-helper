import SwiftUI
import AppKit

private let equipmentAccent = Color(red: 0.43, green: 0.85, blue: 0.72)

struct EquipmentIcon: View {
    let item: Equipment
    var size: CGFloat = 36
    var body: some View {
        Group {
            if let url = Bundle.main.resourceURL?.appendingPathComponent("Equipment/\(item.image)"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "shield.lefthalf.filled").resizable().scaledToFit().padding(8)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

struct EquipmentView: View {
    @ObservedObject var model: CalculatorState

    var body: some View {
        switch EquipmentCatalog.bundled {
        case .success(let catalog):
            content(catalog)
        case .failure:
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                Text("装备资料未能载入").font(.headline)
                Text("请重新构建应用，确认装备资料文件完整。").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func content(_ catalog: EquipmentCatalog) -> some View {
        let visible = catalog.matchingBases(query: model.equipmentQuery)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索原始装备、成品名称或效果", text: $model.equipmentQuery)
                    .textFieldStyle(.plain).accessibilityLabel("搜索装备")
                if !model.equipmentQuery.isEmpty {
                    Button("清除") { model.equipmentQuery = "" }.buttonStyle(.plain)
                }
                Text("8 原始 / 32 成品").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(10).frame(height: 36)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
            HStack {
                Text("原始装备").frame(width: 100, alignment: .leading)
                Text("→").foregroundStyle(equipmentAccent)
                Text("全部成品 · 点击查看属性与溯源")
            }.font(.system(size: 11)).foregroundStyle(.secondary).frame(height: 16)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        if visible.isEmpty {
                            Text("没有匹配的装备，试试其他名称或效果关键词。")
                                .foregroundStyle(.secondary).font(.system(size: 12)).padding(.vertical, 40)
                        }
                        ForEach(visible) { base in
                            HStack(spacing: 8) {
                                Button { model.equipmentDetail = base } label: {
                                    VStack(spacing: 4) {
                                        EquipmentIcon(item: base, size: 28)
                                        Text(base.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    }.frame(width: 94, height: 48)
                                }.buttonStyle(.plain).accessibilityLabel("原始装备：\(base.name)")
                                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(equipmentAccent)
                                ForEach(catalog.outcomes(for: base)) { item in
                                    Button { model.equipmentDetail = item } label: {
                                        VStack(spacing: 4) {
                                            EquipmentIcon(item: item, size: 26)
                                            Text(item.name).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.8)
                                        }.frame(maxWidth: .infinity).frame(height: 48)
                                            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                                    }.buttonStyle(.plain).accessibilityLabel("成品装备：\(item.name)，来自\(base.name)")
                                }
                            }.padding(4)
                                .background(model.selectedEquipment == base.id ? equipmentAccent.opacity(0.13) : Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedEquipment == base.id ? equipmentAccent : .clear, lineWidth: 1))
                                .id(base.id)
                        }
                    }.padding(2)
                }
                .sheet(item: $model.equipmentDetail) { item in
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            EquipmentIcon(item: item, size: 48)
                            Text(item.name).font(.system(size: 22, weight: .semibold))
                            Spacer()
                            Button("关闭") { model.equipmentDetail = nil }.keyboardShortcut(.cancelAction)
                        }
                        if !item.attributes.isEmpty {
                            Text(item.attributes.map { "\($0.label) \($0.value)" }.joined(separator: "  ·  "))
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(equipmentAccent)
                        }
                        Text(item.effect).font(.system(size: 14)).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        Divider()
                        let origins = catalog.origins(for: item)
                        if origins.isEmpty {
                            Text("原始装备 · 可铸造成以下成品").font(.headline)
                            ForEach(catalog.outcomes(for: item)) { outcome in
                                Button { model.equipmentDetail = outcome } label: {
                                    HStack { EquipmentIcon(item: outcome, size: 28); Text(outcome.name); Spacer(); Image(systemName: "arrow.right") }
                                }.buttonStyle(.plain)
                            }
                        } else {
                            Text("装备溯源 · 由以下原始装备铸造").font(.headline)
                            ForEach(origins) { base in
                                Button {
                                    model.equipmentQuery = ""
                                    model.selectedEquipment = base.id
                                    model.equipmentDetail = nil
                                    // Defer scrolling until the unfiltered rows have entered the layout.
                                    DispatchQueue.main.async { proxy.scrollTo(base.id, anchor: .top) }
                                } label: {
                                    HStack {
                                        EquipmentIcon(item: base, size: 36)
                                        Text(base.name).font(.system(size: 15, weight: .medium))
                                        Spacer()
                                        Text("返回原始装备").font(.system(size: 12))
                                        Image(systemName: "arrow.uturn.backward")
                                    }.padding(12).background(equipmentAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).accessibilityLabel("溯源至\(base.name)")
                            }
                        }
                        Link("查看资料来源", destination: URL(string: item.source)!).font(.system(size: 11))
                    }.padding(24).frame(width: 460)
                        .background(OutsideSheetDismissal { model.equipmentDetail = nil })
                }
            }.frame(maxHeight: .infinity)
            HStack {
                Text("全部分支直接展示 · 成品点击可溯源 · v260924 社区资料")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Link("资料来源", destination: URL(string: "https://hokace.wiki/zh/equipment/")!)
                    .font(.system(size: 11)).foregroundStyle(equipmentAccent)
            }.frame(height: 24)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// Observe only this app's clicks while the sheet is attached; no global input permissions.
struct OutsideSheetDismissal: NSViewRepresentable {
    let dismiss: () -> Void
    func makeNSView(context: Context) -> OutsideSheetView {
        let view = OutsideSheetView()
        view.dismiss = dismiss
        return view
    }
    func updateNSView(_ view: OutsideSheetView, context: Context) { view.dismiss = dismiss }
    static func dismantleNSView(_ view: OutsideSheetView, coordinator: ()) { view.stopMonitoring() }
}

final class OutsideSheetView: NSView {
    var dismiss: (() -> Void)?
    private var monitor: Any?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, let sheet = self.window, let parent = sheet.sheetParent,
                  parent.attachedSheet === sheet, let clickedWindow = event.window else { return event }
            let point = clickedWindow.convertPoint(toScreen: event.locationInWindow)
            guard parent.frame.contains(point), !sheet.frame.contains(point) else { return event }
            DispatchQueue.main.async { [weak self] in self?.dismiss?() }
            return nil // Consume the dismissal click rather than activating the underlying control.
        }
    }
    func stopMonitoring() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
    deinit { stopMonitoring() }
}
