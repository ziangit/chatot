<p align="center"><img src="docs/assets/chatot.svg" width="160" alt="Chatot pixel art"></p>
<h1 align="center">Chatot</h1>

[English](README.md)

选中 → 右键 → **使用 Chatot 翻译**。一个 macOS 菜单栏应用：在任意应用里（包括 Claude Code 的终端、Chrome、原生应用）选中文本或图片，译文出现在光标旁的浮动面板里。它只为一个工作流而生：和 Agent 的对话保持英文以保证质量，想细读的部分快速看中文。

- **终端（VS Code / Cursor，任何 CLI：Claude Code、Codex、普通 shell）：** 选中输出，右键 → 使用 Chatot 翻译。Terminal.app 和 iTerm2 走「服务」菜单。
- **Chrome：** 右键选中的文本或图片 → 使用 Chatot 翻译。
- **原生应用（Safari、预览、备忘录、PDF 阅读器）：** 右键 → 服务 → 使用 Chatot 翻译。
- **截图：** ⇧⌘4 / ⇧⌘3 之后，弹出一张小卡片，一键翻译这张截图。
- 浮动面板避开选中区域，随译文流式输出逐渐变大；文字可选中、⌘C 可用，可切换显示原文、复制、关闭。
- 长文本按段落切分并行翻译；每段都做校验（原样回显、长度、中文占比）并自动重试。表格和代码块原样保留。支持术语表。
- 默认英 → 简中（下拉选择）；中文原文会被译成英文。
- 翻译服务：默认 **Claude Haiku 5.5**（用你自己的 Anthropic API Key；Max 订阅每月附带 API 额度），也可选 ChatGPT / DeepSeek，各用各的 Key。只走 API，绝不碰网页会话。
- 界面支持中文 / English。菜单栏：暂停 / 设置 / 退出。

费用：855 个英文单词的长文用 Haiku 约 $0.002；一个段落不到一分钱，约 0.5 秒出第一个字。

## 安装（Release 版本）

1. 到 [Releases](https://github.com/ziangit/chatot/releases) 下载 `Chatot-<版本>.zip`，解压，把 `Chatot.app` 拖进「应用程序」。
2. 应用未经苹果公证，首次需要去掉隔离标记（或右键 → 打开）：
   ```
   xattr -dr com.apple.quarantine /Applications/Chatot.app
   ```
3. 打开 Chatot，点菜单栏的小鸟 → **设置…**，粘贴 API Key，**保存到钥匙串**。界面语言、目标语言、模型都是下拉框。
4. macOS 询问时允许访问「桌面」文件夹（截图监听需要）。不需要辅助功能或屏幕录制权限。

此时原生应用里「右键 → 服务 → 使用 Chatot 翻译」已可用。终端和 Chrome 见下文。

### 终端里的 Agent CLI（Claude Code、Codex）：一次性设置

Chatot 翻译的是你能选中的任何文字，所以任何终端里的任何程序都能用。例外是全屏的 Agent 界面：Claude Code 和 Codex 默认接管鼠标，在它们的界面里拖选没有反应，Chatot 也就收不到任何内容。两者都有关闭的开关，设置一次即可；这发生在 CLI 内部，Chatot 无法替你完成。

**Claude Code** — 在 `~/.zshrc`（或 VS Code 设置的 `terminal.integrated.env.osx`）里加入，然后新开终端、重新启动 `claude`：

```
export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1
```

**Codex** — 在 `~/.codex/config.toml` 里加入（或单次运行 `codex --no-alt-screen`）：

```toml
[tui]
alternate_screen = "never"
```

这两个开关都会让 CLI 改为内联绘制而不是使用备用屏幕：输出留在滚动历史里，滚轮可以翻看历史，拖选和普通终端一样。普通 shell、其他不接管鼠标的 CLI、Terminal.app 和 iTerm2 不需要任何设置。如果你在终端里翻译总是只得到一个单词，原因就是这个设置。

Electron 应用不显示 macOS 的「服务」菜单，所以需要装一个小扩展来加右键菜单项：

```
code --install-extension chatot-vscode-<版本>.vsix      # VS Code
cursor --install-extension chatot-vscode-<版本>.vsix    # Cursor
```

`.vsix` 在 Releases 页面。装完重载窗口。

### Chrome

从 Releases 下载 `chatot-chrome-extension-<版本>.zip`，解压后在目录里运行 `./install.sh`（会把扩展复制到 `~/.config/chatot/chrome-extension`，并为 Chrome / Brave / Edge / Arc / Chromium 注册 native messaging 桥）。然后加载一次：`chrome://extensions` → 开发者模式 → 加载已解压的扩展程序 → `~/.config/chatot/chrome-extension`。

## 从源码构建

需要 macOS 14+ 和 Xcode Command Line Tools 自带的 Swift。

```
git clone https://github.com/ziangit/chatot && cd chatot
cp .env.example .env            # 可选：把 ANTHROPIC_API_KEY 写在这里而不是钥匙串
./scripts/build-app.sh          # 构建、签名、安装到 /Applications/Chatot.app、注册服务菜单
./scripts/install-chrome-extension.sh
cd vscode-extension && npx --yes @vscode/vsce package && code --install-extension chatot-vscode-*.vsix
```

`build-app.sh` 默认 ad hoc 签名；钥匙串里若有名为「Chatot Dev」的代码签名证书则用它（自签证书可以让「桌面」权限在重新构建后保留，做法见 `docs/ARCHITECTURE.md`）。

## 开发

```
swift build
swift run chatot-cli translate "Some English text"     # 走真实翻译服务的端到端测试
swift run chatot-cli image path/to/screenshot.png
swift run chatot-tests                                   # 单元测试（Command Line Tools 没有 XCTest，用的是简单的自带 harness）
```

配置：`.env` 或 `~/.config/chatot/.env`（`ANTHROPIC_API_KEY`、`OPENAI_API_KEY`、`DEEPSEEK_API_KEY`、`CHATOT_PROVIDER`、`CHATOT_TARGET_LANG`、模型覆盖），或直接用设置窗口。术语表：`~/.config/chatot/glossary.txt`，每行 `术语 = 译文`。日志：`~/Library/Logs/chatot.log`。供其他工具调用的 URL scheme：`chatot://translate?text=…`、`chatot://image?url=…`。

基准测试、坑和设计记录：`docs/ARCHITECTURE.md`。产品范围：`docs/PRODUCT.md`。

## 隐私与合规

你翻译的文本和图片只发给你选择的服务商，用你自己的 API Key。本地日志只记录耗时和每次请求的前 40 个字符。Chatot 不会访问 claude.ai / chatgpt.com 的网页会话，也不会提取 OAuth token。

MIT 许可。
