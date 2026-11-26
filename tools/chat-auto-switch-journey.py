import argparse
import hashlib
import json
import tempfile
import time
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tools/fixtures/SOFT-2469"
READER = ROOT / "src/chat_history_reader.py"
SID = "11111111-2222-4333-8444-555555555555"
TMUX = "same-chat"
MESSAGE = "msg-0000-0001"
ORDER = {"claude": "codex", "codex": "pi", "pi": "claude", "antigravity": "claude"}
RECORDED = {"claude": "claude-usage-limit.jsonl", "codex": "codex-usage-limit.jsonl", "pi": "pi-usage-limit.jsonl",
            "antigravity": "agy-resource-exhausted.ndjson"}
DIVIDER = "Switched AI automatically: Claude ran out of plan"
STAYS = "No plan left anywhere"


def load_reader():
    outer = {}
    exec(compile(READER.read_text(encoding="utf-8"), "reader", "exec"), outer)
    runtime = {}
    exec(compile(outer["READER_SOURCE"], "runtime", "exec"), runtime)
    return runtime


def recorded(provider):
    return [json.loads(line) for line in (FIXTURES / RECORDED[provider]).read_text(encoding="utf-8").strip().splitlines()]


def prepare(r, directory, provider):
    r["HOME"] = Path(directory)
    config = dict(enabled=True, provider=provider, sid=SID, tmux=TMUX, cwd=directory,
                  permission_mode="bypassPermissions", face="custom", login="same-agent")
    r["host_write"](r["host_paths"](provider, SID)["config"], config)
    transcript = Path(directory) / "old.jsonl"
    rows = [dict(role="user", text="OLD-QUESTION about the report", id="q1"),
            dict(role="assistant", text="OLD-ANSWER the report is finished", id="a1")]
    transcript.write_text("".join(json.dumps(dict(type="multiprompt_history", row=row)) + "\n" for row in rows))
    with closing(r["message_store_db"](TMUX)) as db, db:
        db.execute("INSERT OR IGNORE INTO message_chats(provider,sid) VALUES (?,?)", (provider, SID))
        db.execute("INSERT OR REPLACE INTO message_locators(provider,sid,tmux) VALUES (?,?,?)", (provider, SID, TMUX))
        db.execute("INSERT INTO shared_messages VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                   (MESSAGE, provider, SID, "USER-QUESTION please finish the report", 1, "attempt-1", "sent",
                    None, None, 0, 1.0, "human"))
    return transcript


def starting(r, provider, current):
    state = r["host_session_state"](provider, current)
    session = {}
    r["host_session_reset"](session)
    state.update(provider=provider, sid=current, display_history=False)
    session["state"] = state
    entry = dict(id=MESSAGE, attempt="attempt-1", epoch=0, at=time.time(), accepted=True,
                 text="USER-QUESTION please finish the report", turn="t-1", sha256="0" * 64)
    session["sends"] = [entry]
    session["inflight"] = entry
    session["turn"] = "t-1"
    session["ready"] = True
    return session


def plan_out(r, provider, current, transcript):
    started = []
    seen = []

    def fake_start(ai, sid):
        started.append((ai, sid))
        return dict(status="started")

    def runner(ai, sid, target, message_id):
        seen.append((ai, target, message_id))
        return r["host_auto_switch_run"](ai, sid, target, message_id)

    session = starting(r, provider, current)
    with patch.dict(r, host_auto_switch_spawn=runner, host_start=fake_start,
                    conversation_path=lambda *args: transcript,
                    start_message_worker=lambda *args, **kwargs: None,
                    message_store_request=lambda query: dict(status="queued"),
                    host_turn_busy=lambda *args: False):
        for event in recorded(provider):
            r["host_agent_event"](provider, current, TMUX, session, json.dumps(event))
    return started, seen


def row(r):
    with closing(r["message_store_db"](TMUX)) as db:
        return db.execute("SELECT provider,sid,state FROM shared_messages WHERE id=?", (MESSAGE,)).fetchone()


def noticed(r, provider, current):
    with closing(r["message_store_db"](TMUX)) as db:
        for seq, body in db.execute("SELECT seq,body FROM message_events WHERE provider=? AND sid=? ORDER BY seq",
                                    (provider, current)):
            if STAYS in body:
                return True
    return False


def chats(r):
    return [chat for chat in r["host_chats"]() if chat["name"] == TMUX]


def run(evidence):
    r = load_reader()
    steps = []
    checks = []

    def check(name, passed, detail):
        checks.append(dict(step=steps[-1]["step"], check=name, passed=bool(passed), detail=detail))

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "claude")
        started, seen = plan_out(r, "claude", SID, transcript)
        followed = r["host_switch_follow"](SID)
        live = chats(r)
        new = started[0][1] if started else None
        shown = r["host_paths"]("codex", new)["history"].read_text(encoding="utf-8") if new else ""
        handover = r["host_read"](r["host_paths"]("codex", new)["root"] / r["host_session_state"]("codex", new)["fresh_start"]["file"]) if new else {}
        steps.append(dict(step="claude-plan-out", from_ai="claude", target=ORDER["claude"],
                          fixtures=[RECORDED["claude"]], followed=followed,
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started],
                          live=[dict(provider=chat["provider"], sid=chat["sid"], name=chat["name"]) for chat in live]))
        check("recorded usage limit starts the next AI once", seen == [("claude", "codex", MESSAGE)], seen)
        check("the chat keeps its address and moves to the next AI",
              len(live) == 1 and live[0]["provider"] == "codex" and followed == ("codex", new), [live, followed])
        check("the old AI config is disabled", r["host_config"]("claude", SID) is None, r["host_config"]("claude", SID))
        check("the new chat shows the automatic switch divider", DIVIDER in shown, shown[-400:])
        check("the new chat keeps the earlier conversation", "OLD-QUESTION" in shown and "OLD-ANSWER" in shown, shown[:400])
        check("the queued message moves with the chat", row(r) == ("codex", new, "queued"), row(r))
        check("the handover names the used-up plan", isinstance(handover, dict) and "ran out of plan" in handover.get("text", ""),
              str(handover.get("text", ""))[:200])
        (evidence / "switched-history.jsonl").write_text(shown, encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "claude")
        config = r["host_read"](r["host_paths"]("claude", SID)["config"])
        config["auto_switch"] = dict(on=True, order=["claude", "codex", "pi"], empty={"codex": time.time()})
        r["host_write"](r["host_paths"]("claude", SID)["config"], config)
        started, seen = plan_out(r, "claude", SID, transcript)
        followed = r["host_switch_follow"](SID)
        steps.append(dict(step="fallback-order", from_ai="claude", target="pi", skipped="codex",
                          fixtures=[RECORDED["claude"]], followed=followed,
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started]))
        check("a used-up AI is skipped in the saved order", seen == [("claude", "pi", MESSAGE)], seen)
        check("the chat lands on the third AI", followed is not None and followed[0] == "pi", followed)

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "claude")
        config = r["host_read"](r["host_paths"]("claude", SID)["config"])
        config["auto_switch"] = dict(on=True, order=["claude", "codex", "pi", "antigravity"],
                                     empty={"codex": time.time(), "pi": time.time()})
        r["host_write"](r["host_paths"]("claude", SID)["config"], config)
        started, seen = plan_out(r, "claude", SID, transcript)
        followed = r["host_switch_follow"](SID)
        steps.append(dict(step="land-on-antigravity", from_ai="claude", target="antigravity", skipped="codex,pi",
                          fixtures=[RECORDED["claude"]], followed=followed,
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started]))
        check("Antigravity is the next AI with a plan", seen == [("claude", "antigravity", MESSAGE)], seen)
        check("the chat lands on Antigravity", followed is not None and followed[0] == "antigravity", followed)

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "claude")
        config = r["host_read"](r["host_paths"]("claude", SID)["config"])
        config["auto_switch"] = dict(on=True, order=["claude", "codex", "pi", "antigravity"],
                                     empty={"codex": time.time(), "pi": time.time(), "antigravity": time.time()})
        r["host_write"](r["host_paths"]("claude", SID)["config"], config)
        started, seen = plan_out(r, "claude", SID, transcript)
        steps.append(dict(step="all-plans-empty", from_ai="claude", fixtures=[RECORDED["claude"]],
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started]))
        check("an all-empty fallback still starts nothing", started == [] and seen == [], started)
        check("the chat stays on its own AI", row(r) == ("claude", SID, "sent"), row(r))
        check("the app says no plan is left anywhere", noticed(r, "claude", SID), "message events")

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "antigravity")
        started, seen = plan_out(r, "antigravity", SID, transcript)
        followed = r["host_switch_follow"](SID)
        new = started[0][1] if started else None
        steps.append(dict(step="antigravity-plan-out", from_ai="antigravity", target=ORDER["antigravity"],
                          fixtures=[RECORDED["antigravity"]], followed=followed,
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started]))
        check("an Antigravity resource-exhausted result starts the next AI once",
              seen == [("antigravity", "claude", MESSAGE)], seen)
        check("the chat leaves Antigravity", followed is not None and followed[0] == "claude", followed)
        check("the used-up Antigravity config is disabled", r["host_config"]("antigravity", SID) is None,
              r["host_config"]("antigravity", SID))
        check("the queued message moves off Antigravity", row(r) == ("claude", new, "queued"), row(r))

    with tempfile.TemporaryDirectory(prefix="auto-switch-") as directory:
        transcript = prepare(r, directory, "claude")
        off = r["host_reply"](dict(op="set_auto_switch", provider="claude", sid=SID, toggle=True))
        settings = r["host_auto_switch_settings"](r["host_config"]("claude", SID))
        started, seen = plan_out(r, "claude", SID, transcript)
        followed = r["host_switch_follow"](SID)
        steps.append(dict(step="toggle-off-keeps-chat", from_ai="claude", toggle=off, settings=settings,
                          fixtures=[RECORDED["claude"]], followed=followed,
                          spawned=[dict(ai=item[0], sid=item[1]) for item in started]))
        check("the toggle saves off", off == dict(status="ok", on=False) and settings["on"] is False, off)
        check("a recorded limit starts no new AI while the toggle is off", started == [] and seen == [], started)
        check("the chat stays where it is", followed is None and row(r) == ("claude", SID, "sent"), [followed, row(r)])
        check("no automatic notice appears while the toggle is off", not noticed(r, "claude", SID), "message events")
        on = r["host_reply"](dict(op="set_auto_switch", provider="claude", sid=SID, toggle=True))
        after = r["host_auto_switch_settings"](r["host_config"]("claude", SID))
        steps.append(dict(step="toggle-back-on", toggle=on, settings=after))
        check("the toggle turns back on", on == dict(status="ok", on=True) and after["on"] is True, on)

    journey = dict(status="passed" if all(item["passed"] for item in checks) else "failed",
                   reader_sha256=hashlib.sha256(READER.read_bytes()).hexdigest(),
                   fixtures={name: hashlib.sha256((FIXTURES / name).read_bytes()).hexdigest() for name in sorted(RECORDED.values())},
                   order=ORDER, steps=steps, checks=checks)
    (evidence / "journey.json").write_text(json.dumps(journey, indent=2) + "\n", encoding="utf-8")
    failed = [item for item in checks if not item["passed"]]
    summary = dict(status=journey["status"], checks=len(checks), failed=[item["check"] for item in failed],
                   steps=[step["step"] for step in steps], reader_sha256=journey["reader_sha256"],
                   fixtures=journey["fixtures"], order=ORDER)
    (evidence / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(dict(status=journey["status"], checks=len(checks), failed=len(failed))))
    for item in failed:
        print("FAILED " + item["step"] + ": " + item["check"] + " -> " + str(item["detail"])[:400])
    return 0 if not failed else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, default=ROOT / "evidence")
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    return run(args.evidence)


if __name__ == "__main__":
    raise SystemExit(main())
