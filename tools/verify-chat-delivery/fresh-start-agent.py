import json
import os
import sys
import uuid
from pathlib import Path

HANDOVER = "Finish the saved draft. Keep the same board login."
ACK = "Read the handover. Next: finish the saved draft."


def message_text(request):
    content = request.get("message", {}).get("content")
    if isinstance(content, list):
        return "".join(part.get("text", "") for part in content if isinstance(part, dict))
    return content if isinstance(content, str) else ""


def emit_assistant(text):
    identity = "fresh-" + uuid.uuid4().hex[:12]
    payload = dict(type="assistant", message=dict(role="assistant", id=identity, content=[dict(type="text", text=text)]))
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()
    sys.stdout.write(json.dumps(dict(type="result", subtype="success", session_id=sid, result=text),
                                separators=(",", ":")) + "\n")
    sys.stdout.flush()


args = sys.argv[1:]
if "--session-id" not in args and "--resume" not in args:
    sys.exit(2)
sid = args[args.index("--resume") + 1] if "--resume" in args else args[args.index("--session-id") + 1]
root = Path(os.environ["MP_VERIFY_STATE"])
log_path = root / "fresh-start-agent.jsonl"


def log(row):
    with log_path.open("a", encoding="utf-8") as out:
        out.write(json.dumps(row, separators=(",", ":")) + "\n")


print(json.dumps(dict(type="system", subtype="init", session_id=sid, model="sonnet")), flush=True)
for line in sys.stdin:
    request = json.loads(line)
    if request.get("type") != "user":
        continue
    text = message_text(request)
    log(dict(event="user", text=text[:200]))
    if "Prepare a fresh start" in text:
        emit_assistant(HANDOVER)
    elif "You are the same chat after a fresh start" in text or "saved handover file" in text:
        emit_assistant(ACK)
    else:
        emit_assistant("Synthetic fixture response.")