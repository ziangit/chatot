import Foundation

public struct TranslationRequest {
    public var system: String
    public var text: String
    public var image: Data?
    public var imageMediaType: String?
    public init(system: String, text: String, image: Data? = nil, imageMediaType: String? = nil) {
        self.system = system; self.text = text; self.image = image; self.imageMediaType = imageMediaType
    }
}

/// A translation backend. Implementations stream text deltas; the translator assembles and validates them.
public protocol Provider: AnyObject {
    var id: String { get }
    var supportsImages: Bool { get }
    /// Cheap availability check (binary present, key present, server reachable).
    func isAvailable() -> Bool
    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error>
}

/// Shared helper for providers that shell out to a CLI.
