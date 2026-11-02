import Foundation

/// Two-language UI strings. "system" follows macOS; otherwise the user's explicit choice in Settings.
enum L10n {
    static let key = "language"   // "system" | "en" | "zh-Hans"
    static var language: String { UserDefaults.standard.string(forKey: key) ?? "system" }
    static var isChinese: Bool {
        switch language {
        case "zh-Hans": return true
        case "en": return false
        default: return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") ?? false
        }
    }
    static let table: [String: (String, String)] = [
        "Pause Chatot": ("Pause Chatot", "暂停 Chatot"),
        "Resume Chatot": ("Resume Chatot", "恢复 Chatot"),
        "Settings…": ("Settings…", "设置…"),
        "Quit Chatot": ("Quit Chatot", "退出 Chatot"),
        "Chatot Settings": ("Chatot Settings", "Chatot 设置"),
        "General": ("General", "通用"),
        "Language": ("Language", "界面语言"),
        "System": ("System", "跟随系统"),
        "Target language": ("Target language", "目标语言"),
        "target_hint": ("Text already in the target language is translated to English.", "已是目标语言的文本会被翻译成英文。"),
        "Provider": ("Provider", "翻译服务"),
        "Model": ("Model", "模型"),
        "API key": ("API key", "API 密钥"),
        "Save to Keychain": ("Save to Keychain", "保存到钥匙串"),
        "Saved": ("Saved", "已保存"),
        "Keychain error": ("Keychain error", "钥匙串错误"),
        "key_hint": ("A key in .env (repo or ~/.config/chatot/.env) takes precedence over the keychain.", ".env（仓库或 ~/.config/chatot/.env）中的密钥优先于钥匙串。"),
        "deepseek_hint": ("DeepSeek cannot read images; screenshots need Claude or ChatGPT.", "DeepSeek 不支持图片；截图翻译需要 Claude 或 ChatGPT。"),
        "Screenshots": ("Screenshots", "截图"),
        "Offer to translate new screenshots": ("Offer to translate new screenshots", "截图后提示翻译"),
        "Where to find it": ("Where to find it", "在哪里使用"),
        "where_text": ("Right-click selected text or an image → Services → Translate with Chatot\nVS Code / Cursor terminal and editor: right-click → Translate with Chatot\nChrome: right-click → Translate with Chatot", "右键选中的文本或图片 → 服务 → 使用 Chatot 翻译\nVS Code / Cursor 终端和编辑器：右键 → 使用 Chatot 翻译\nChrome：右键 → 使用 Chatot 翻译"),
        "glossary_hint": ("Glossary: ~/.config/chatot/glossary.txt (term = translation per line)", "术语表：~/.config/chatot/glossary.txt（每行一条：术语 = 译文）"),
        "Ready": ("Ready", "就绪"),
        "Original": ("Original", "原文"),
        "Copy translation": ("Copy translation", "复制译文"),
        "Close": ("Close", "关闭"),
        "Copied": ("Copied", "已复制"),
        "Chatot": ("Chatot", "Chatot"),
        "translating_chars": ("Translating %d characters…", "正在翻译 %d 个字符…"),
        "reading_image": ("Reading image (%d KB)…", "正在读取图片（%d KB）…"),
        "translating_segments": ("Translating %d segment(s)…", "正在翻译 %d 段…"),
        "done_in": ("Done in %.1fs", "完成，用时 %.1f 秒"),
        "done_failed": ("Done in %.1fs, %d failed", "完成，用时 %.1f 秒，%d 段失败"),
        "Translating…": ("Translating…", "翻译中…"),
        "unchanged": ("unchanged — nothing to translate", "未改动 — 无需翻译"),
        "retrying": ("Retrying after %@: %@", "%@ 失败，重试中：%@"),
        "no_key": ("No API key for %@. Add it in Settings.", "尚未设置 %@ 的 API 密钥，请在设置中添加。"),
        "no_image_provider": ("%@ cannot read images. Choose Claude or ChatGPT in Settings.", "%@ 不支持图片，请在设置中选择 Claude 或 ChatGPT。"),
        "Fetching image…": ("Fetching image…", "正在获取图片…"),
        "image_failed": ("Could not load image: %@", "无法加载图片：%@"),
        "Translate this screenshot": ("译  Translate this screenshot", "译  翻译这张截图"),
        "nothing_to_translate": ("Chatot: nothing to translate", "Chatot：没有可翻译的内容"),
        "needs_text": ("chatot://translate needs a text parameter.", "chatot://translate 需要 text 参数。"),
        "unknown_action": ("Unknown chatot:// action: %@", "未知的 chatot:// 操作：%@"),
    ]
}

func L(_ key: String) -> String {
    guard let pair = L10n.table[key] else { return key }
    return L10n.isChinese ? pair.1 : pair.0
}
