"""Keep a reply streaming into seeded live chats for the whole idle window.

A released app with live chats polls each transcript through the shell reader.
Quiet transcripts never change, so that reader returns the same bytes and the
chat view never rebuilds. This appender grows one reply at a time in every
seeded transcript, which is what a live answer does while the user does
nothing, so the poll path and the chat paint path both run for the window.

Usage: python stream-reply.py <workload.json> <seconds> <count-file> <stop-file>

It rewrites the count file about twice a second so the probe can read how many
reply events landed inside its window, and exits on the stop file.
"""

import json
import os
from pathlib import Path
import sys
import time
import uuid

INLINE = [
    "Checking the failing row first, then the retry path. ",
    "The second observer disagrees, so I re-read the transcript. ",
    "That leaves the timeout at eight seconds, which matches the log. ",
    "I will keep the guard and drop the duplicate poll. ",
    "Two of the three windows agree on the same answer. ",
    "Here is the short version before the diff. ",
    "Next step is the check that proves it on the real build. ",
    "Still running the last case, about ten seconds left. ",
]
REPLY_EVERY = 25
PERIOD_S = 0.4


def event(session_id, message_id, text):
    return (json.dumps(dict(type="assistant", timestamp=time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime()),
                            sessionId=session_id, uuid=str(uuid.uuid4()), isSidechain=False,
                            message=dict(role="assistant", id=message_id, model="claude-opus-5-5",
                                         content=[dict(type="text", text=text)])))
            + "\n").encode("utf-8")


def main():
    workload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    seconds = float(sys.argv[2])
    count_file = Path(sys.argv[3])
    stop_file = Path(sys.argv[4])
    chats = [dict(handle=None, sid=row["sid"], text="", message="", chunk=0,
                  delay=index * PERIOD_S / max(len(workload["chats"]), 5))
             for index, row in enumerate(workload["chats"])]
    flags = os.O_WRONLY | os.O_APPEND | getattr(os, "O_BINARY", 0)
    for chat, row in zip(chats, workload["chats"]):
        chat["handle"] = os.open(row["path"], flags)
    written = 0
    started = time.monotonic()
    reported = 0.0
    try:
        while time.monotonic() - started < seconds:
            if stop_file.exists():
                break
            wrote = False
            now = time.monotonic() - started
            for chat in chats:
                if now < chat["delay"]:
                    continue
                if chat["chunk"] % REPLY_EVERY == 0:
                    chat["text"] = ""
                    chat["message"] = "msg_" + uuid.uuid4().hex[:12]
                chat["text"] += INLINE[chat["chunk"] % len(INLINE)]
                os.write(chat["handle"], event(chat["sid"], chat["message"], chat["text"]))
                written += 1
                chat["chunk"] += 1
                chat["delay"] += PERIOD_S
                wrote = True
            if now - reported >= 0.5:
                count_file.write_text(json.dumps(dict(events=written, seconds=round(now, 1))), encoding="utf-8")
                reported = now
            if not wrote:
                time.sleep(0.01)
    finally:
        for chat in chats:
            os.close(chat["handle"])
        count_file.write_text(json.dumps(dict(events=written, seconds=round(time.monotonic() - started, 1))), encoding="utf-8")


if __name__ == "__main__":
    main()
