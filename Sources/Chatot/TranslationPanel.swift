import AppKit
import SwiftUI
import ChatotCore

final class SegmentState: ObservableObject, Identifiable {
    let id: Int
    let source: String
    let passthrough: Bool
    @Published var output: String = ""
    @Published var done = false
    @Published var error: String? = nil
    @Published var note: String? = nil
    init(segment: Segment) { id = segment.id; source = segment.text; passthrough = segment.kind == .passthrough; if passthrough { output = segment.text; done = true } }
}

final class PanelModel: ObservableObject {
    @Published var segments: [SegmentState] = []
    @Published var status: String = "Ready"
    @Published var message: String? = nil
    @Published var isImage = false
    @Published var showOriginal = UserDefaults.standard.bool(forKey: AppConfig.Keys.showOriginal)
    @Published var pinned = false
    var fullText: String { segments.map { $0.output }.joined(separator: "\n\n") }
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    var onCopy: () -> Void
    var onPin: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Toggle("Original", isOn: $model.showOriginal).toggleStyle(.checkbox).font(.caption)
                    .onChange(of: model.showOriginal) { _, v in UserDefaults.standard.set(v, forKey: AppConfig.Keys.showOriginal) }
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }.help("Copy translation")
                Button(action: onPin) { Image(systemName: model.pinned ? "pin.fill" : "pin") }.help("Keep panel open")
                Button(action: onClose) { Image(systemName: "xmark") }.help("Close")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10).padding(.vertical, 6)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let m = model.message {
                        Text(m).foregroundStyle(.secondary).padding(12)
                    }
                    ForEach(model.segments) { seg in
                        SegmentView(seg: seg, showOriginal: model.showOriginal && !model.isImage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
        .frame(minWidth: 360, minHeight: 120)
    }
}

struct SegmentView: View {
    @ObservedObject var seg: SegmentState
    var showOriginal: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showOriginal && !seg.passthrough {
                Text(seg.source).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if let e = seg.error {
                Text("⚠️ \(e)").font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled)
            } else if seg.output.isEmpty && !seg.done {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text(seg.note ?? "Translating…").font(.caption).foregroundStyle(.secondary) }
            } else {
                Text(seg.output)
                    .font(seg.passthrough ? .system(size: 12, design: .monospaced) : .system(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let n = seg.note, !seg.done { Text(n).font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}

/// Floating, non-activating panel that shows translations near the mouse.
final class TranslationPanelController {
    let model = PanelModel()
    private var panel: NSPanel!
    private var currentTask: Task<Void, Never>?

    init() {
        let view = PanelView(model: model, onCopy: { [weak self] in self?.copyAll() }, onPin: { [weak self] in self?.togglePin() }, onClose: { [weak self] in self?.panel.orderOut(nil) })
        let hosting = NSHostingView(rootView: view)
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360), styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Chatot"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        panel.minSize = NSSize(width: 360, height: 140)
    }

    func show() {
        positionNearMouse()
        panel.orderFrontRegardless()
    }

    func showMessage(_ text: String) {
        model.segments = []; model.message = text; model.status = "Chatot"; model.isImage = false
        show()
    }

    func translate(text: String) {
        start(status: "Translating \(text.count) characters…", isImage: false)
        let translator = makeTranslator()
        currentTask = Task { [model] in
            guard let translator = translator else { return }
            await translator.translate(text) { ev in DispatchQueue.main.async { self.apply(ev, to: model) } }
        }
    }

    func translate(image: Data) {
        start(status: "Reading image (\(image.count / 1024) KB)…", isImage: true)
        let translator = makeTranslator()
        currentTask = Task { [model] in
            guard let translator = translator else { return }
            await translator.translateImage(image) { ev in DispatchQueue.main.async { self.apply(ev, to: model) } }
        }
    }

    private func start(status: String, isImage: Bool) {
        currentTask?.cancel()
        model.segments = []; model.message = nil; model.status = status; model.isImage = isImage
        show()
    }

    private func makeTranslator() -> Translator? {
        do {
            let config = AppConfig.current()
            let providers = Translator.makeProviders(config: config)
            if providers.isEmpty {
                model.message = "No translation provider available. Add ANTHROPIC_API_KEY in Settings, or install the claude/codex CLI."
                model.status = "No provider"
                return nil
            }
            return Translator(config: config, prompts: try Prompts.load(), providers: providers, glossary: Glossary.load())
        } catch {
            model.message = error.localizedDescription; model.status = "Error"; return nil
        }
    }

    private func apply(_ ev: TranslationEvent, to model: PanelModel) {
        switch ev {
        case .segments(let segs):
            model.segments = segs.map(SegmentState.init(segment:))
            model.status = "Translating \(segs.filter { $0.kind == .translate }.count) segment(s)…"
        case .delta(let i, let t):
            guard i < model.segments.count else { return }
            model.segments[i].output += t
        case .completed(let i, let text, let provider, let secs):
            guard i < model.segments.count else { return }
            let s = model.segments[i]; s.output = text; s.done = true; s.error = nil
            if provider != "passthrough" { s.note = String(format: "%@ · %.1fs", provider, secs) }
        case .retrying(let i, let p, let r):
            guard i < model.segments.count else { return }
            model.segments[i].note = "Retrying after \(p): \(r)"
            model.segments[i].output = ""
        case .failed(let i, let err):
            guard i < model.segments.count else { return }
            model.segments[i].error = err; model.segments[i].done = true
        case .finished(let secs):
            let failed = model.segments.filter { $0.error != nil }.count
            model.status = failed == 0 ? String(format: "Done in %.1fs", secs) : String(format: "Done in %.1fs, %d failed", secs, failed)
        }
    }

    private func positionNearMouse() {
        guard !panel.isVisible || !model.pinned else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - panel.frame.height - 12)
        origin.x = min(max(vf.minX, origin.x), vf.maxX - panel.frame.width)
        origin.y = min(max(vf.minY, origin.y), vf.maxY - panel.frame.height)
        panel.setFrameOrigin(origin)
    }

    private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(model.fullText, forType: .string)
        model.status = "Copied"
    }

    private func togglePin() { model.pinned.toggle() }

    /// Dev hook: render the panel's own content to a PNG (no screen-recording permission needed).
    func snapshot(to path: String) {
        guard let v = panel.contentView else { return }
        let scale = panel.backingScaleFactor
        let w = Int(v.bounds.width * scale), h = Int(v.bounds.height * scale)
        // 1) Layer tree render (SwiftUI hosting views are layer-backed).
        if let layer = v.layer, let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
           let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
            ctx.cgContext.scaleBy(x: scale, y: scale)
            layer.render(in: ctx.cgContext)
            NSGraphicsContext.restoreGraphicsState()
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path + ".layer.png")) }
        }
        // 2) Window capture of our own window.
        if let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(panel.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
            let rep = NSBitmapImageRep(cgImage: cg)
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
        }
        Log.info("snapshot written to \(path)")
    }
}
