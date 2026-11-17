import json
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1]).resolve()
source = root / 'src/chat_render.zig'
text = source.read_text(encoding='utf-8')
original = '            if (painted) send_latency.markPainted();'
replacement = original + '\n            if (painted) @import("chat_frame_probe.zig").capture(hwnd);'
if replacement not in text:
    if text.count(original) != 1:
        raise SystemExit('Expected exactly one successful transcript paint boundary')
    source.write_text(text.replace(original, replacement), encoding='utf-8', newline='\n')
shutil.copyfile(Path(__file__).with_name('frame-probe.zig'), root / 'src/chat_frame_probe.zig')
print(json.dumps(dict(instrumented=str(root), probe='after successful BitBlt; no layout or scroll changes')))
