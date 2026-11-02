import Foundation
import ChatotCore

// chatot-cli: exercise the translation pipeline from the terminal.
//   chatot-cli translate [--file PATH] [--no-chunk] [TEXT...]
//   chatot-cli image PATH
//   chatot-cli providers
//   chatot-cli config

func usage() -> Never {
    FileHandle.standardError.write("usage: chatot-cli translate [--file PATH] [--no-chunk] [TEXT] | image PATH | providers | config\n".data(using: .utf8)!)
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { usage() }
args.removeFirst()
Log.echoToStderr = ProcessInfo.processInfo.environment["CHATOT_DEBUG"] != nil

let config = Config.load()

func makeTranslator(providerFilter: String?) throws -> Translator {
    let prompts = try Prompts.load()
    var providers = Translator.makeProviders(config: config)
    if let f = providerFilter { providers = providers.filter { $0.id == f } }
    guard !providers.isEmpty else { throw ChatotError.provider("no available providers\(providerFilter.map { " matching \($0)" } ?? "")") }
    return Translator(config: config, prompts: prompts, providers: providers, glossary: Glossary.load())
}

/// Prints segments in order as they complete, streaming the first in-flight one live.
final class ConsoleRenderer {
    var segments: [Segment] = []
    var done: [Int: String] = [:]
    var live: [Int: String] = [:]
    var nextToPrint = 0
    var liveSegment: Int? = nil
    let start = Date()
    func handle(_ e: TranslationEvent) {
        switch e {
        case .segments(let s):
            segments = s
            FileHandle.standardError.write("[\(s.count) segments]\n".data(using: .utf8)!)
        case .delta(let i, let t):
            if i == nextToPrint {
                if liveSegment != i { liveSegment = i; FileHandle.standardError.write(String(format: "[first text %.2fs]\n", Date().timeIntervalSince(start)).data(using: .utf8)!) }
                print(t, terminator: ""); fflush(stdout)
                live[i, default: ""] += t
            }
        case .completed(let i, let text, let provider, let secs):
            done[i] = text
            FileHandle.standardError.write(String(format: "[segment %d done via %@ in %.2fs]\n", i, provider, secs).data(using: .utf8)!)
            flush()
        case .retrying(let i, let p, let r):
            FileHandle.standardError.write("[segment \(i) retry after \(p): \(r)]\n".data(using: .utf8)!)
        case .failed(let i, let err):
            done[i] = "⚠️ segment \(i) failed: \(err)"
            flush()
        case .finished(let secs):
            FileHandle.standardError.write(String(format: "[finished in %.2fs]\n", secs).data(using: .utf8)!)
        }
    }
    func flush() {
        while let text = done[nextToPrint] {
            if let partial = live[nextToPrint] {
                // Already streamed; print only the remainder (text replaces partial on retry).
                if text.hasPrefix(partial) { print(text.dropFirst(partial.count)) } else { print("\n" + text) }
            } else {
                print(text)
            }
            print("")
            nextToPrint += 1
            liveSegment = nil
        }
        fflush(stdout)
    }
}

let sem = DispatchSemaphore(value: 0)
switch cmd {
case "config":
    var c = config; c.anthropicKey = c.anthropicKey.map { String($0.prefix(10)) + "…" }
    print(c)
case "providers":
    for p in Translator.makeProviders(config: config) { print("\(p.id) available (images: \(p.supportsImages))") }
case "translate":
    var file: String? = nil, provider: String? = nil, chunk = true, words: [String] = []
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--file": i += 1; file = args[i]
        case "--provider": i += 1; provider = args[i]
        case "--no-chunk": chunk = false
        default: words.append(args[i])
        }
        i += 1
    }
    let text: String
    if let f = file { text = try! String(contentsOfFile: f, encoding: .utf8) }
    else if !words.isEmpty { text = words.joined(separator: " ") }
    else { text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? "" }
    let translator = try! makeTranslator(providerFilter: provider)
    let r = ConsoleRenderer()
    Task { await translator.translate(text, chunk: chunk) { r.handle($0) }; sem.signal() }
    sem.wait()
case "image":
    guard let path = args.first else { usage() }
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    let mt = path.lowercased().hasSuffix(".jpg") || path.lowercased().hasSuffix(".jpeg") ? "image/jpeg" : "image/png"
    let translator = try! makeTranslator(providerFilter: nil)
    let r = ConsoleRenderer()
    Task { await translator.translateImage(data, mediaType: mt) { r.handle($0) }; sem.signal() }
    sem.wait()
default:
    usage()
}
