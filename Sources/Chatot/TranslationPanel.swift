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
    @Published var rendered = NSAttributedString()
    var fullText: String { segments.map { PanelModel.translationOnly($0.output, image: isImage) }.joined(separator: "\n\n") }

    /// Screenshot output is "original → translation" per line; keep only the translation.
    static func translationOnly(_ text: String, image: Bool) -> String {
        guard image else { return text }
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            if let r = line.range(of: " ║ ") { return String(line[r.upperBound...]) }
            return String(line)
        }.joined(separator: "\n")
    }

    /// Rebuild the attributed text shown in the panel from the segment states.
    func render() {
        let out = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]
        let mono: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: NSColor.labelColor]
        let dim: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]
        let note: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor]
        let red: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.systemRed]
        if let m = message { out.append(NSAttributedString(string: m, attributes: dim)) }
        for (i, seg) in segments.enumerated() {
            if i > 0 || message != nil { out.append(NSAttributedString(string: "\n\n", attributes: body)) }
            if let e = seg.error { out.append(NSAttributedString(string: "⚠️ " + e, attributes: red)); continue }
            if isImage {
                // Lines are "original ║ translation" (║ never occurs in content); show the translation, original above when asked.
                for (j, line) in seg.output.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    if j > 0 { out.append(NSAttributedString(string: "\n", attributes: body)) }
                    if let r = line.range(of: " ║ ") {
                        if showOriginal { out.append(NSAttributedString(string: String(line[..<r.lowerBound]) + "\n", attributes: dim)) }
                        out.append(NSAttributedString(string: String(line[r.upperBound...]), attributes: body))
                    } else {
                        out.append(NSAttributedString(string: String(line), attributes: body))
                    }
                }
            } else {
                if showOriginal && !seg.passthrough { out.append(NSAttributedString(string: seg.source + "\n", attributes: dim)) }
                out.append(NSAttributedString(string: seg.output, attributes: seg.passthrough ? mono : body))
            }
            if seg.output.isEmpty && !seg.done { out.append(NSAttributedString(string: seg.note ?? "Translating…", attributes: dim)) }
            else if let n = seg.note, !seg.done || n.hasPrefix("unchanged") { out.append(NSAttributedString(string: "  " + n, attributes: note)) }
        }
        rendered = out
    }
}

/// Native text view inside the SwiftUI panel: selectable, ⌘C / ⌘A work (the app has an Edit menu), scrolls.
struct SelectableText: NSViewRepresentable {
    var text: NSAttributedString
    func makeNSView(context: Context) -> NSScrollView {
        let tv = NSTextView()
        tv.isEditable = false; tv.isSelectable = true; tv.isRichText = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.textContainer?.widthTracksTextView = true
        tv.isVerticallyResizable = true; tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.lineFragmentPadding = 0
        let sv = NSScrollView()
        sv.documentView = tv
        sv.hasVerticalScroller = true; sv.autohidesScrollers = true; sv.drawsBackground = false
        return sv
    }
    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv = sv.documentView as? NSTextView, let storage = tv.textStorage else { return }
        if !storage.isEqual(to: text) {
            let sel = tv.selectedRange()
            storage.setAttributedString(text)
            if sel.location + sel.length <= text.length { tv.setSelectedRange(sel) }
        }
    }
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    var onCopy: () -> Void
    var onClose: () -> Void
    var onToggleOriginal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Toggle("Original", isOn: $model.showOriginal).toggleStyle(.checkbox).font(.caption)
                    .onChange(of: model.showOriginal) { _, v in UserDefaults.standard.set(v, forKey: AppConfig.Keys.showOriginal); onToggleOriginal() }
                Button(action: onCopy) { Image(systemName: "doc.on.doc") }.help("Copy translation")
                Button(action: onClose) { Image(systemName: "xmark") }.help("Close")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10).padding(.vertical, 6)
            Divider()
            SelectableText(text: model.rendered)
        }
        .frame(minWidth: 360, minHeight: 120)
    }
}

/// Floating, non-activating panel that shows translations near the mouse.
final class TranslationPanelController {
    let model = PanelModel()
    private var panel: NSPanel!
    private var currentTask: Task<Void, Never>?
    /// Where the last placement allowed the panel to grow: screen area and whether it should extend upward.
    private var growsUp = false
    private var screenArea = NSRect.zero
    private var lastFit = Date.distantPast

    init() {
        let view = PanelView(model: model, onCopy: { [weak self] in self?.copyAll() }, onClose: { [weak self] in self?.panel.orderOut(nil) }, onToggleOriginal: { [weak self] in self?.model.render(); self?.fitToContent(force: true) })
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

    func show(textLength: Int = 0) {
        place(textLength: textLength)
        panel.orderFrontRegardless()
    }

    func showMessage(_ text: String) {
        model.segments = []; model.message = text; model.status = "Chatot"; model.isImage = false
        model.render()
        show()
        fitToContent(force: true)
    }

    func translate(text: String) {
        start(status: "Translating \(text.count) characters…", isImage: false, textLength: text.count)
        let translator = makeTranslator()
        currentTask = Task { [model] in
            guard let translator = translator else { return }
            await translator.translate(text) { ev in DispatchQueue.main.async { self.apply(ev, to: model) } }
        }
    }

    func translate(image: Data) {
        start(status: "Reading image (\(image.count / 1024) KB)…", isImage: true, textLength: 600)
        let translator = makeTranslator()
        currentTask = Task { [model] in
            guard let translator = translator else { return }
            await translator.translateImage(image) { ev in DispatchQueue.main.async { self.apply(ev, to: model) } }
        }
    }

    private func start(status: String, isImage: Bool, textLength: Int) {
        currentTask?.cancel()
        model.segments = []; model.message = nil; model.status = status; model.isImage = isImage
        model.render()
        show(textLength: textLength)
    }

    private func makeTranslator() -> Translator? {
        do {
            let config = AppConfig.current()
            let providers = Translator.makeProviders(config: config)
            if providers.isEmpty {
                model.message = "No ANTHROPIC_API_KEY. Add it in Settings (or ~/.config/chatot/.env)."
                model.status = "No provider"
                return nil
            }
            return Translator(config: config, prompts: try Prompts.load(), providers: providers, glossary: Glossary.load())
        } catch {
            model.message = error.localizedDescription; model.status = "Error"; return nil
        }
    }

    private func apply(_ ev: TranslationEvent, to model: PanelModel) {
        defer { model.render() }
        switch ev {
        case .segments(let segs):
            model.segments = segs.map(SegmentState.init(segment:))
            model.status = "Translating \(segs.filter { $0.kind == .translate }.count) segment(s)…"
        case .delta(let i, let t):
            guard i < model.segments.count else { return }
            model.segments[i].output += t
            fitToContent(force: false)
        case .completed(let i, let text, let provider, let secs):
            guard i < model.segments.count else { return }
            let s = model.segments[i]; s.output = text; s.done = true; s.error = nil
            if provider != "passthrough" { s.note = String(format: "%@ · %.1fs", provider, secs) }
            if !model.isImage && Validator.normalize(text) == Validator.normalize(s.source) { s.note = "unchanged — nothing to translate" }
            fitToContent(force: true)
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
            fitToContent(force: true)
        }
    }

    /// Put the panel where it does not cover the text being translated, and make it as large as that space allows.
    private func place(textLength: Int) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        let m: CGFloat = 12
        // Without Accessibility we cannot see where the selected text is; assume a band around the mouse,
        // since a right-click happens on the selection.
        let avoid = NSRect(x: vf.minX, y: max(vf.minY, mouse.y - 300), width: vf.width, height: min(600, vf.height))
        var how = "mouse band"
        let minW: CGFloat = 380, minH: CGFloat = 200
        let maxW = max(520, vf.width * 0.45)
        // Candidate free regions around the avoid rect; sides first because the user reads left-to-right.
        let regions: [(String, NSRect)] = [
            ("right", NSRect(x: avoid.maxX + m, y: vf.minY, width: vf.maxX - avoid.maxX - m, height: vf.height)),
            ("left", NSRect(x: vf.minX, y: vf.minY, width: avoid.minX - vf.minX - m, height: vf.height)),
            ("below", NSRect(x: vf.minX, y: vf.minY, width: vf.width, height: avoid.minY - vf.minY - m)),
            ("above", NSRect(x: vf.minX, y: avoid.maxY + m, width: vf.width, height: vf.maxY - avoid.maxY - m)),
        ].filter { $0.1.width >= minW && $0.1.height >= minH }
        let frame: NSRect
        if let best = regions.max(by: { score($0.1) < score($1.1) }) {
            let r = best.1
            let w = min(r.width, maxW)
            let h = min(r.height, max(minH, estimatedHeight(textLength: textLength, width: w)))
            var x: CGFloat, y: CGFloat
            switch best.0 {
            case "right": x = r.minX; y = avoid.maxY - h
            case "left": x = r.maxX - w; y = avoid.maxY - h
            case "below": x = mouse.x < vf.midX ? r.maxX - w : r.minX; y = r.maxY - h
            default: x = mouse.x < vf.midX ? r.maxX - w : r.minX; y = r.minY
            }
            x = min(max(r.minX, x), r.maxX - w); y = min(max(r.minY, y), r.maxY - h)
            frame = NSRect(x: x, y: y, width: w, height: h)
            growsUp = best.0 == "above"
            how += " → \(best.0)"
        } else {
            growsUp = false
            // Nothing fits beside the text: dock to the screen edge away from the mouse, full height.
            let w = max(minW, vf.width * 0.4)
            frame = NSRect(x: mouse.x < vf.midX ? vf.maxX - w : vf.minX, y: vf.minY, width: w, height: vf.height)
            how += " → dock"
        }
        screenArea = vf
        Log.info("panel placed via \(how): \(Int(frame.width))×\(Int(frame.height)) at \(Int(frame.minX)),\(Int(frame.minY))")
        panel.setFrame(frame, display: true)
    }

    /// Grow the panel so the whole translation is visible without scrolling: measure the real text at the current
    /// width, extend away from the source text first, and spill the other way only when the screen runs out.
    private func fitToContent(force: Bool) {
        guard panel.isVisible, !screenArea.isEmpty else { return }
        if !force && Date().timeIntervalSince(lastFit) < 0.25 { return }
        lastFit = Date()
        let m: CGFloat = 12
        let width = panel.frame.width - 24
        var needed: CGFloat = 34 + 1 + 24   // header, divider, content padding
        let opts: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        func h(_ text: String, size: CGFloat, mono: Bool = false) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont.systemFont(ofSize: size)
            return ceil((text as NSString).boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude), options: opts, attributes: [.font: font]).height)
        }
        if let msg = model.message { needed += h(msg, size: 13) + 24 }
        for seg in model.segments {
            if model.showOriginal && !model.isImage && !seg.passthrough { needed += h(seg.source, size: 12) + 4 }
            needed += seg.error != nil ? 20 : (seg.output.isEmpty ? 20 : h(seg.output, size: seg.passthrough ? 12 : 14, mono: seg.passthrough))
            needed += seg.note != nil && !seg.done ? 16 : 0
            needed += 10
        }
        needed = ceil(needed * 1.04) + 8
        let maxH = screenArea.height - 2 * m
        let target = min(max(needed, panel.minSize.height), maxH)
        guard target > panel.frame.height + 2 else { return }   // only grow during a translation
        var f = panel.frame
        if growsUp { f.origin.y = f.minY } else { f.origin.y = f.maxY - target }
        f.size.height = target
        if f.minY < screenArea.minY + m { f.origin.y = screenArea.minY + m }
        if f.maxY > screenArea.maxY - m { f.origin.y = screenArea.maxY - m - target }
        Log.info("panel grown to \(Int(f.width))×\(Int(f.height)) (needed \(Int(needed)), \(growsUp ? "up" : "down"))")
        panel.setFrame(f, display: true, animate: false)
    }

    private func score(_ r: NSRect) -> CGFloat { r.width * r.height }

    /// Rough height for the translation (EN→ZH shrinks to ~60%), plus the original if it is shown.
    private func estimatedHeight(textLength: Int, width: CGFloat) -> CGFloat {
        let charsPerLine = max(10, (width - 24) / 15)
        var chars = Double(textLength) * 0.65
        if model.showOriginal { chars += Double(textLength) * 0.6 }
        let lines = ceil(chars / charsPerLine) + Double(textLength / 300) + 1
        return CGFloat(lines) * 22 + 70
    }

    private func copyAll() {
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(model.fullText, forType: .string)
        model.status = "Copied"
    }

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
