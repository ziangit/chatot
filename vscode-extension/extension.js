const vscode = require('vscode');
const { execFile } = require('child_process');

function send(action, text) {
  const url = text === undefined ? `chatot://${action}` : `chatot://${action}?text=${encodeURIComponent(text)}`;
  execFile('/usr/bin/open', [url], (err) => {
    if (err) vscode.window.showErrorMessage(`Chatot: could not open the app (${err.message}). Is /Applications/Chatot.app installed?`);
  });
}

async function terminalSelection() {
  const t = vscode.window.activeTerminal;
  if (t && typeof t.selection === 'string' && t.selection.trim()) {
    const sel = t.selection.trim();
    // macOS VS Code selects the word under the cursor on right-click. When a TUI (Claude Code) owns the real
    // selection it has already copied it to the clipboard; if that clipboard text is longer and contains the
    // lone word, the clipboard is what the user meant.
    if (!/\s/.test(sel)) {
      const clip = (await vscode.env.clipboard.readText()).trim();
      if (clip.length > sel.length && clip.includes(sel)) return { text: clip, source: 'clipboard' };
    }
    return { text: sel, source: 'terminal' };
  }
  if (t && t.selection === undefined) {
    // Very old VS Code without the selection API: copy the xterm selection and read it back, restoring the clipboard.
    const before = await vscode.env.clipboard.readText();
    await vscode.commands.executeCommand('workbench.action.terminal.copySelection');
    await new Promise(r => setTimeout(r, 120));
    const copied = await vscode.env.clipboard.readText();
    await vscode.env.clipboard.writeText(before);
    if (copied !== before && copied.trim()) return { text: copied, source: 'terminal' };
  }
  // TUIs that capture the mouse (Claude Code, vim, tmux) keep the selection to themselves; Claude Code copies it to
  // the clipboard on mouse-up, so the clipboard is the best available source. The Chatot panel shows what it got.
  const clip = await vscode.env.clipboard.readText();
  if (clip && clip.trim()) return { text: clip, source: 'clipboard' };
  return { text: '', source: 'none' };
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('chatot.translateTerminalSelection', async () => {
      const { text, source } = await terminalSelection();
      if (!text || !text.trim()) { vscode.window.showInformationMessage('Chatot: select some terminal text first (in a TUI, the selection is read from the clipboard).'); return; }
      if (source === 'clipboard') vscode.window.setStatusBarMessage('Chatot: translating clipboard text (terminal reported no selection)', 4000);
      send('translate', text);
    }),
    vscode.commands.registerCommand('chatot.translateSelection', () => {
      const ed = vscode.window.activeTextEditor;
      const text = ed ? ed.selections.map(s => ed.document.getText(s)).join('\n\n') : '';
      if (!text.trim()) { vscode.window.showInformationMessage('Chatot: select some text first.'); return; }
      send('translate', text);
    }),
    vscode.commands.registerCommand('chatot.translateRegion', () => send('region'))
  );
}

function deactivate() {}
module.exports = { activate, deactivate };
