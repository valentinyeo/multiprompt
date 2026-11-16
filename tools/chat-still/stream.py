import datetime
import json
import pathlib
import sys
import time
import uuid

state = pathlib.Path(sys.argv[1])
name = sys.argv[2]
receipt = pathlib.Path(sys.argv[3])
seed = json.loads((state / "state.json").read_text(encoding="utf-8-sig"))
index = seed["sessions"].index(name)
folder = "C--verify-work" + str(index)
transcript = pathlib.Path(seed["home"]) / ".claude/projects" / folder / (seed["sids"][name] + ".jsonl")
identity = uuid.uuid4().hex
records = []
for chunk in range(30):
    row = {"type": "assistant", "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
           "sessionId": seed["sids"][name], "uuid": identity, "isSidechain": False,
           "message": {"role": "assistant", "id": "msg_still_" + identity,
                       "content": [{"type": "text", "text": "Streaming reply " + "more words " * (chunk + 1)}]}}
    with transcript.open("ab") as output:
        output.write(json.dumps(row).encode() + b"\n")
    records.append({"chunk": chunk, "time_ns": time.time_ns(), "bytes": transcript.stat().st_size})
    time.sleep(0.1)
receipt.write_text(json.dumps({"transcript": str(transcript), "message": identity, "chunks": records}, indent=2))
