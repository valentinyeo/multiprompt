import json
import os
import sys
import uuid
from pathlib import Path

HANDOVER = "\n".join([
    "Finish the saved draft. Keep the same board login.",
    "",
    "## Where I stopped",
    "I finished the board drain loop for this week and left the next ticket claimed.",
    "The draft reply to the customer is written but not sent. It sits in the composer.",
    "",
    "## What is done",
    "The release proof for the shell copy journey ran on the published build and passed.",
    "The chat shell folder journey recorded before and after screenshots on the same run.",
    "The restore journey kept one sidebar row and one transcript through the restart.",
    "The palette order journey kept the same row order after a second open and close.",
    "The status card journey showed the live server name and the running chat count.",
    "The remind me journey fired after the delay and kept the message text intact.",
    "The tab names journey kept the renamed tab after switching away and back.",
    "The relaunch journey restored both saved sessions with their own folders.",
    "The message only journey kept every row inside the reading width on the narrow pane.",
    "The chat focus journey put the caret back in the composer after a palette round trip.",
    "",
    "## What is open",
    "SOFT-2604 needs the live proof on a release before it can be closed on the board.",
    "SOFT-2999 needs a passing verifier run on the fresh start journey.",
    "The customer reply needs one more read before it goes out on Monday.",
    "The board view still has four tickets in review and two waiting on a decision.",
    "",
    "## Tickets and their state",
    "SOFT-2604, live proof on a release, waiting on the run URL and the two screenshots.",
    "SOFT-2999, verifier pass on the fresh start journey, waiting on the hosted run.",
    "SOFT-3092, fresh start on a Windows state file, open in review and not merged yet.",
    "SOFT-3101, idle worker wake test, open in review with one failing shard.",
    "SOFT-3114, idle worker wake test, open in review behind the same shard.",
    "SOFT-3001, shell copy and restore on a release, open in review with green journeys.",
    "IGSH-1040, final evidence after cleanup, done and closed this week.",
    "IGSH-1103, failure results keep the executable identity, done and closed this week.",
    "",
    "## Checks I ran",
    "The fresh start unit test passed on the branch with the doubled handover case.",
    "The feature map check passed after I linked the new driving step.",
    "The journey command check passed with the same palette row and the same search text.",
    "The proof checker read the host log and found one saved handover and two visible rows.",
    "The before and after identity files kept the same sid, tmux name, row name and layout csid.",
    "",
    "## What I decided",
    "I kept the synthetic host boundary for the journey because the real Claude child is not available here.",
    "I did not change the app settings to green a run.",
    "I did not weaken any wait or any check to make the journey pass.",
    "",
    "## Next step",
    "Open the published release, run the fresh start journey, and read the before and after files.",
    "Then send the customer reply and close the two tickets that are already proved.",
    "Then re-run the board drain loop with the same view and the same labels.",
    "",
    "## Environment",
    "Board view: my view, armed and checked.",
    "Server: the shared VPS, no local build and no local test run.",
    "Key: the same agent login, nothing rotated this week.",
    "Folder: the same checkout, no new worktree.",
    "Release: the published build, not a branch build, for every desktop proof this week.",
    "",
    "## Notes for the next chat",
    "Read this file once before anything else and do not repeat work that is already done.",
    "The handover is the only context the new chat gets, so keep it short and exact.",
    "If the board view is empty, re-run the drain command before assuming the view is lost.",
    "If a run fails, read result.json and doctor.json before dispatching another run.",
    "If a screenshot looks stale, check build.json for the version and the hash before believing it.",
    "",
    "## Files I touched",
    "The journey control for fresh start, the host stub, the agent stub and the proof checker.",
    "The feature map entry for fresh start and the coverage note for the same journey.",
    "The unit test that answers the handover twice inside one turn.",
    "",
    "## Files I did not touch",
    "No application source file in this list, because the fix itself already shipped in the release.",
    "No server tool and no board record, because the proof reads the board and never writes to it.",
    "No settings file on the runner, because the journey uses an isolated profile.",
    "",
    "## If you have to stop early",
    "Write the partial result to the run evidence folder and keep the log copy with it.",
    "Say which check failed, which file proves it, and which version and hash the binary reported.",
])
ACK = "Read the handover. Next: finish the saved draft."
HANDOVER_REPEATS = 2


def message_text(request):
    content = request.get("message", {}).get("content")
    if isinstance(content, list):
        return "".join(part.get("text", "") for part in content if isinstance(part, dict))
    return content if isinstance(content, str) else ""


def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def emit_assistant(text):
    emit(dict(type="assistant",
              message=dict(role="assistant", id="fresh-" + uuid.uuid4().hex[:12],
                           content=[dict(type="text", text=text)])))


def emit_result(text):
    emit(dict(type="result", subtype="success", session_id=sid, result=text))


def emit_turn(text, repeats=1):
    for _ in range(repeats):
        emit_assistant(text)
    emit_result(text)


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
    log(dict(event="user", text=text[:200], length=len(text.encode("utf-8")),
             carried="Finish the saved draft." in text, resumed="after a fresh start" in text))
    if "Prepare a fresh start" in text:
        emit_turn(HANDOVER, HANDOVER_REPEATS)
    elif "You are the same chat after a fresh start" in text or "saved handover file" in text:
        emit_turn(ACK)
    else:
        emit_turn("Synthetic fixture response.")
