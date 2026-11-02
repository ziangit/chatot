#!/usr/bin/env python3
"""Chrome native-messaging host for Chatot: receives {action, text|url} and opens a chatot:// URL."""
import sys, struct, json, subprocess, urllib.parse

def read():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4: return None
    n = struct.unpack('<I', raw)[0]
    return json.loads(sys.stdin.buffer.read(n).decode('utf-8'))

def reply(obj):
    data = json.dumps(obj).encode('utf-8')
    sys.stdout.buffer.write(struct.pack('<I', len(data)) + data); sys.stdout.buffer.flush()

msg = read()
if msg is None: sys.exit(0)
action = msg.get('action')
if action == 'translate' and msg.get('text'):
    url = 'chatot://translate?text=' + urllib.parse.quote(msg['text'])
elif action == 'image' and msg.get('url'):
    url = 'chatot://image?url=' + urllib.parse.quote(msg['url'], safe='')
else:
    reply({'ok': False, 'error': 'bad message'}); sys.exit(0)
subprocess.run(['/usr/bin/open', url])
reply({'ok': True})
