import AppKit
import SwiftUI

/// One reusable, nonmodal reference panel per plugin instance. Hiding a dock
/// surface does not dismiss it; unloading the plugin explicitly releases it.
@MainActor
final class MathReferenceWindow {
    private(set) var panel: NSPanel?

    func show(model: QuickNoteModel) {
        if let panel { panel.orderFront(nil); return }
        let panel = ReferencePanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                                   styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        panel.title = "QuickNote — Math Reference"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = NSSize(width: 380, height: 340)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        let host = TransparentHostingView(rootView: MathReferenceView(model: model))
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: material.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            host.topAnchor.constraint(equalTo: material.topAnchor),
            host.bottomAnchor.constraint(equalTo: material.bottomAnchor),
        ])
        panel.contentView = material
        panel.center()
        // Place beside the editor where the screen permits; no focus is taken
        // from its text view just to open the guide.
        if let editor = NSApp.keyWindow, let screen = editor.screen {
            let bounds = screen.visibleFrame
            let right = editor.frame.maxX + 12
            let x = right + panel.frame.width <= bounds.maxX ? right : editor.frame.minX - panel.frame.width - 12
            panel.setFrameOrigin(NSPoint(x: min(max(x, bounds.minX), bounds.maxX - panel.frame.width),
                                         y: min(max(editor.frame.maxY - panel.frame.height, bounds.minY), bounds.maxY - panel.frame.height)))
        }
        self.panel = panel
        updateAppearance(isDark: model.theme?.isDark)
        panel.orderFront(nil)
    }

    func updateAppearance(isDark: Bool?) {
        panel?.appearance = isDark.map { NSAppearance(named: $0 ? .darkAqua : .aqua) } ?? nil
    }

    func close() {
        panel?.close()
        panel?.contentView = nil
        panel = nil
    }
}

@MainActor
private final class ReferencePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct MathReferenceView: View {
    @ObservedObject var model: QuickNoteModel
    @State private var query = ""
    private var primary: Color { Color(nsColor: model.editorTextColor) }
    private var secondary: Color { Color(nsColor: model.theme?.secondaryTextColor ?? .secondaryLabelColor) }
    private var entries: [MathReferenceEntry] { MathReferenceCatalog.entries.filter { $0.matches(query.trimmingCharacters(in: .whitespacesAndNewlines)) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Math Reference", systemImage: "function").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Done") { model.mathReference.close() }
            }
            Text("Keep this window open while you type in your note. Select any example to copy it.")
                .font(.system(size: 11)).foregroundStyle(secondary)
            TextField("Search functions, syntax or examples", text: $query)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Search math reference")
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.category.uppercased()).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(secondary)
                            Text(entry.syntax).font(.system(size: 12, weight: .semibold, design: .monospaced)).textSelection(.enabled)
                            Text(entry.detail).font(.system(size: 11)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                            Text(entry.example).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            Divider()
                        }
                    }
                    if entries.isEmpty { Text("No matching functions. Try a name such as sin, pmt or mean.").font(.system(size: 12)).foregroundStyle(secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(primary).padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: model.theme?.isDark) { model.mathReference.updateAppearance(isDark: $1) }
    }
}
