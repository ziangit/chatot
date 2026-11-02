// Right-click → "Translate with Chatot" on selected text or an image.
// The native messaging host (chrome-host.py) opens chatot:// URLs, so no "open app?" prompt ever appears.
const HOST = 'com.ziangit.chatot';

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({ id: 'chatot-text', title: 'Translate with Chatot', contexts: ['selection'] });
  chrome.contextMenus.create({ id: 'chatot-image', title: 'Translate image with Chatot', contexts: ['image'] });
});

chrome.contextMenus.onClicked.addListener((info) => {
  if (info.menuItemId === 'chatot-text' && info.selectionText) {
    send({ action: 'translate', text: info.selectionText });
  } else if (info.menuItemId === 'chatot-image' && info.srcUrl) {
    send({ action: 'image', url: info.srcUrl });
  }
});

function send(msg) {
  chrome.runtime.sendNativeMessage(HOST, msg, () => {
    if (chrome.runtime.lastError) console.error('Chatot host:', chrome.runtime.lastError.message);
  });
}
