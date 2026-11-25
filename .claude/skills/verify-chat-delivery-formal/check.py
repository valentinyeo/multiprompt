import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

from native import function, tables
from replay import replay

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RULES = ("SingleVisibleCopy", "NoFalseNotSent", "NoFalseNotSentResume")
TLC_SHA = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
TLC_SOURCES = (
    "https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar",
    "https://api.github.com/repos/tlaplus/tlaplus/releases/assets/184694200",
)


def fetch_jar(url, timeout=45):
    headers = {"Accept": "application/octet-stream"} if "api.github.com" in url else {}
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=timeout) as response:
        return response.read()


def jar():
    path = pathlib.Path(os.environ.get("TLA2TOOLS", pathlib.Path.home() / ".cache/chat-delivery-formal/tla2tools-1.7.4.jar"))
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == TLC_SHA:
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    failures = []
    for url in TLC_SOURCES:
        try:
            content = fetch_jar(url)
        except (OSError, urllib.error.URLError) as error:
            failures.append(url + ": " + str(error))
            continue
        if hashlib.sha256(content).hexdigest() != TLC_SHA:
            failures.append(url + ": checksum mismatch")
            continue
        path.write_bytes(content)
        return path
    raise ValueError("TLC download failed: " + "; ".join(failures))


def coverage(root):
    record = json.loads((HERE / "coverage.json").read_text())
    for file, digest in record["files"].items():
        if hashlib.sha256((root / file).read_bytes()).hexdigest() != digest:
            raise ValueError("MODEL DRIFT: review " + file + " and the coverage map before updating its sync commit")
    return record


def config(values, rule, scenario):
    lines = ["SPECIFICATION Spec", "CHECK_DEADLOCK FALSE", "CONSTANTS"]
    for key, value in values.items():
        lines.append(f"  {key} = " + (str(value).upper() if isinstance(value, bool) else json.dumps(value)))
    lines.append("  Scenario = " + json.dumps(scenario))
    lines.append("INVARIANT " + rule)
    return "\n".join(lines) + "\n"


def trace(text):
    steps = []
    for block in re.split(r"\nState \d+: ", text)[1:]:
        title, _, body = block.partition("\n")
        action = "Init" if "Initial predicate" in title else title.split(" ")[0].lstrip("<")
        values = {}
        for name, value in re.findall(r"^/\\ (\w+) = (.*)$", body, re.M):
            if value in ("TRUE", "FALSE"):
                values[name] = value == "TRUE"
            elif value.startswith('"'):
                values[name] = json.loads(value)
            elif value.isdigit():
                values[name] = int(value)
            elif value.startswith("{"):
                values[name] = [int(v) for v in re.findall(r"\d+", value)]
            else:
                raise ValueError("Unsupported TLC trace value: " + value)
        if values:
            steps.append({"action": action, "values": values})
    return steps


def check(values, output, reliable=False):
    output.mkdir(parents=True, exist_ok=True)
    spec = (HERE / "Delivery.tla").read_text()
    (output / "Delivery.tla").write_text(spec)
    (output / "decisions.json").write_text(json.dumps(values, indent=2) + "\n")
    shutil.copyfile(HERE / "view.mjs", output / "view.mjs")
    results = {}
    for rule in RULES:
        cfg = output / (rule + ".cfg")
        invariant = "NoFalseNotSent" if rule == "NoFalseNotSentResume" else rule
        scenario = "reliable" if reliable else "resume" if rule == "NoFalseNotSentResume" else "all"
        cfg.write_text(config(values, invariant, scenario))
        result = subprocess.run([os.environ.get("JAVA", "java"), "-XX:+UseParallelGC", "-Xmx256m", "-cp", str(jar()), "tlc2.TLC", "-workers", "1", "-seed", "1", "-metadir", str(output / (rule + "-states")), "-config", str(cfg), str(output / "Delivery.tla")], text=True, capture_output=True, timeout=60)
        text = result.stdout + result.stderr
        (output / (rule + ".log")).write_text(text)
        violated = "Error: Invariant " + invariant + " is violated."
        if result.returncode == 0 and "Model checking completed. No error has been found." in text:
            results[rule] = {"status": "PASS", "trace": []}
        elif violated in text and result.returncode == 12:
            witness = trace(text)
            if not witness:
                raise ValueError("TLC violation without a readable trace")
            results[rule] = {"status": "FAIL", "trace": witness}
        else:
            raise ValueError("TLC did not finish " + rule + "; see " + str(output / (rule + ".log")))
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return results


def base_tables(baseline, output):
    with tempfile.TemporaryDirectory(prefix="delivery-base-") as directory:
        root = pathlib.Path(directory)
        (root / "src").mkdir()
        for source in ("src/chat_echo.zig", "src/chat_send.zig"):
            (root / source).write_bytes(subprocess.check_output(["git", "show", baseline + ":" + source], cwd=ROOT))
        return tables(root, output)


def self_test(root, output):
    reliable = check(json.loads((HERE / "decisions.json").read_text()), output / "reliable-control", reliable=True)
    if any(result["status"] != "PASS" for result in reliable.values()):
        raise ValueError("Reliable mutation control must pass before planting a break")
    mutations = {
        "SingleVisibleCopy": ("src/chat_send.zig", "chatEchoWaitsOnTranscript", "    if (e.message_v1) return e.write_started or e.channel_sent or e.channel_pending;", "    if (e.message_v1) return false;"),
        "NoFalseNotSent": ("src/chat_echo.zig", "showsNotSent", "    if (!message_v1 or state == .cancelled) return false;", "    if (message_v1 and state == .delivered) return true;\n    if (!message_v1 or state == .cancelled) return false;"),
    }
    for rule, (file, name, before, after) in mutations.items():
        with tempfile.TemporaryDirectory(prefix="delivery-break-") as directory:
            scratch = pathlib.Path(directory)
            (scratch / "src").mkdir()
            for source in ("src/chat_send.zig", "src/chat_echo.zig"):
                shutil.copyfile(root / source, scratch / source)
            source = (scratch / file).read_text()
            body = function(source, name)
            if body.count(before) != 1:
                raise ValueError("Mutation no longer matches " + name)
            (scratch / file).write_text(source.replace(body, body.replace(before, after)))
            values = tables(scratch, output / rule / "native")
            result = check(values, output / rule, reliable=True)
            if result[rule]["status"] != "FAIL":
                raise ValueError("Planted production break escaped " + rule)
            if rule == "NoFalseNotSent" and result[rule]["trace"][-1]["values"]["state"] != "delivered":
                raise ValueError("Mutation did not expose the planted delivered-label break")
            replay(root, result, output / rule / "replay", scratch)
    return list(mutations)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("/tmp/chat-delivery-formal"))
    parser.add_argument("--model-only", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--inherit-from", default="")
    args = parser.parse_args()
    if args.model_only and (args.self_test or args.inherit_from):
        parser.error("model-only cannot prove mutations, native replay or inherited findings")
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError("Use a new or empty output directory")
    output.mkdir(parents=True, exist_ok=True)
    record = coverage(ROOT)
    expected = json.loads((HERE / "decisions.json").read_text())
    values = expected if args.model_only else tables(ROOT, output / "native")
    if values != expected:
        raise ValueError("Production decisions differ from the recorded model; review the mapping")
    results = check(values, output / "current")
    if not args.model_only:
        replay(ROOT, results, output / "replay")
    mutations = self_test(ROOT, output / "mutations") if args.self_test else []
    if mutations:
        restored = tables(ROOT, output / "restored-native")
        restored_results = check(restored, output / "restored")
        if restored != values or restored_results != results:
            raise ValueError("Original source did not return to its starting result")
        replay(ROOT, restored_results, output / "restored-replay")
    failures = [rule for rule in RULES if results[rule]["status"] == "FAIL"]
    inherited = None
    if failures and args.inherit_from:
        if not mutations:
            raise ValueError("Inherited findings require --self-test")
        baseline = subprocess.check_output(["git", "rev-parse", args.inherit_from], cwd=ROOT, text=True).strip()
        before = base_tables(baseline, output / "inherited-native")
        differing = sorted(name for name in values if before.get(name) != values[name])
        if differing:
            raise ValueError("Base source decides differently: " + ", ".join(differing))
        inherited = baseline
    summary = {"source_sync": record["sync_commit"], "model_only": args.model_only,
               "failures": failures, "mutations_caught": mutations, "inherited_from": inherited}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 1 if failures and not inherited else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
