import importlib.util
import json
import os
import sys

reader_path, transcript_path, output_path = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("app_supplied_reader", reader_path)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
size = os.path.getsize(transcript_path)
with open(transcript_path, "rb") as source:
    base, end, data = reader.read_tail(source, size, "claude", [], fill=True)
rows = [row for raw in data.splitlines() for row in reader.conversation_rows(reader.load_line(raw), "claude", base)]
visible = [row for row in rows if row["role"] in ("user", "assistant")]
result = dict(
    base=base,
    end=end,
    frame_bytes=len(data),
    rows=len(rows),
    visible=len(visible),
    newest=[row.get("text", "")[:40] for row in visible[-2:]],
)
if not visible:
    result["reason"] = "the tail frame holds no user or assistant row, so the chat can open on tool output alone"
with open(output_path, "w", encoding="utf-8") as output:
    output.write(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
sys.exit(0 if visible else 1)
