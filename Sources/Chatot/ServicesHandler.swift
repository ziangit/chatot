import AppKit
import ChatotCore

/// Target of the "Translate with Chatot" entry in every app's Services menu (declared in Info.plist).
final class ServicesHandler: NSObject {
    weak var panel: TranslationPanelController?

    @objc func translateSelection(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        Log.info("service invoked with types \(pboard.types?.map { $0.rawValue } ?? [])")
        if let s = pboard.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async { self.panel?.translate(text: s) }
        } else if let d = ImageUtil.imageData(from: pboard) {
            DispatchQueue.main.async { self.panel?.translate(image: d) }
        } else {
            error.pointee = "Chatot: nothing to translate" as NSString
        }
    }
}
