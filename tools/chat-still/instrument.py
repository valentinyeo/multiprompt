import argparse
import hashlib
import json
import os
import pathlib

PROBE = pathlib.Path(__file__).with_name("paint.zig")
ANCHOR = "var transcript_paint_dc: HANDLE = null;"
PAINT = "                if (painted) chatBenchPaint();"
HOOK = "                if (painted) chatStillFrame(hwnd);\n"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def instrument(root, metadata):
    path = root / "src/chat_render.zig"
    original = path.read_bytes()
    probe = PROBE.read_bytes()
    source = original.decode()
    if "fn chatStillFrame(" in source or HOOK in source:
        record = json.loads(metadata.read_text())
        if record["instrumented_sha256"] != digest(original) or record["probe_sha256"] != digest(probe):
            raise ValueError("Chat paint probe changed or was only partly installed")
        return record
    if source.count(ANCHOR) != 1 or source.count(PAINT) != 1:
        raise ValueError("Chat paint boundary changed; review the verification probe")
    changed = source.replace(ANCHOR, probe.decode() + ANCHOR, 1).replace(PAINT, HOOK + PAINT, 1).encode()
    record = {"revision": os.environ.get("VERIFY_REVISION", "working-tree"),
              "source": "src/chat_render.zig", "hook": "chatTranscriptWndProc/WM_PAINT/after EndPaint",
              "original_sha256": digest(original), "instrumented_sha256": digest(changed),
              "probe_sha256": digest(probe)}
    metadata.parent.mkdir(parents=True, exist_ok=True)
    metadata.write_text(json.dumps(record, indent=2) + "\n")
    path.write_bytes(changed)
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=pathlib.Path)
    parser.add_argument("metadata", type=pathlib.Path)
    args = parser.parse_args()
    print(json.dumps(instrument(args.root, args.metadata), indent=2))
