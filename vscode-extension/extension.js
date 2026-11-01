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
  if (t && typeof t.selection === 'string' && t.selection.trim()) return t.selection;
  // Fallback for older VS Code builds: copy the terminal selection and read it back, restoring the clipboard.
  const before = await vscode.env.clipboard.readText();
  await vscode.commands.executeCommand('workbench.action.terminal.copySelection');
  await new Promise(r => setTimeout(r, 120));
  const copied = await vscode.env.clipboard.readText();
  await vscode.env.clipboard.writeText(before);
  return copied !== before ? copied : '';
}

function activate(context) {
  context.subscriptions.push(
    vscode.commands.registerCommand('chatot.translateTerminalSelection', async () => {
      const text = await terminalSelection();
      if (!text || !text.trim()) { vscode.window.showInformationMessage('Chatot: select some terminal text first.'); return; }
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
