import argparse
import ast
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import tempfile

from replay import replay

import z3

ROOT = pathlib.Path(__file__).resolve().parents[2]


def function(source, name):
    start = re.search(r"(?:pub )?fn " + name + r"\(", source).start()
    end = re.search(r"\n(?:pub )?fn |\n(?:pub )?const ", source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


def symbolic(expression, values):
    expression = re.sub(r"!(?!=)", " not ", expression).replace("null", "-1")
    tree = ast.parse(expression.strip(), mode="eval")

    def visit(node):
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, (ast.Name, ast.Attribute)):
            return values[ast.unparse(node)]
        if isinstance(node, ast.Constant):
            return node.value
        if isinstance(node, ast.UnaryOp):
            return z3.Not(visit(node.operand)) if isinstance(node.op, ast.Not) else -visit(node.operand)
        if isinstance(node, ast.BoolOp):
            return (z3.And if isinstance(node.op, ast.And) else z3.Or)(*[visit(v) for v in node.values])
        if isinstance(node, ast.BinOp):
            a, b = visit(node.left), visit(node.right)
            if isinstance(node.op, ast.Add):
                return a + b
            if isinstance(node.op, ast.Sub):
                return a - b
        if isinstance(node, ast.Compare) and len(node.ops) == 1:
            a, b = visit(node.left), visit(node.comparators[0])
            op = node.ops[0]
            if isinstance(op, ast.Eq):
                return a == b
            if isinstance(op, ast.NotEq):
                return a != b
            if isinstance(op, ast.LtE):
                return a <= b
            if isinstance(op, ast.Lt):
                return a < b
            if isinstance(op, ast.Gt):
                return a > b
            if isinstance(op, ast.GtE):
                return a >= b
        raise ValueError("Unsupported Zig scalar expression: " + ast.dump(node))

    return visit(tree)


def held(body):
    match = re.search(r"const held_y: \?i32 = if \((.*?)\) null else if \(anchor_top\) \|top\| (.*?) else (.*?);", body)
    if not match:
        raise ValueError("held_y changed shape; update the source-to-SMT mapping before moving the sync commit")
    return match.groups()


def normalized(body):
    return re.sub(r"\s+", " ", re.sub(r"const held_y: \?i32 = .*?;", "HELD_Y", body)).strip()


def check(root, replay_code=False):
    session = (root / "src/chat_session.zig").read_text()
    history = (root / "src/chat_history.zig").read_text()
    bodies = {name: function(session, name) for name in ("refreshChatTranscript", "chatRelayoutPreservingScroll")}
    covered = {**bodies, **{name: function(history, name) for name in ("scrollAnchor", "readAnchor", "readAnchorTop", "followBottom", "scrollAfterLayout", "openScroll")},
               "chatSetTopPad": function((root / "src/chat_render.zig").read_text(), "chatSetTopPad")}
    recorded = json.loads((ROOT / "tools/chat-still/coverage.json").read_text())
    for name, body in covered.items():
        digest = hashlib.sha256(normalized(body).encode()).hexdigest()
        if digest != recorded["functions"][name]["sha256"]:
            raise ValueError(name + " changed outside the translated expression; review the model and coverage record")
    for name, record in recorded["types"].items():
        line = next((line for line in history.splitlines() if line.startswith("pub const " + name + " = struct")), "")
        if hashlib.sha256(normalized(line).encode()).hexdigest() != record["sha256"]:
            raise ValueError(name + " changed; review the model and replay types")
    failures = []
    witnesses = []
    for name, body in bodies.items():
        condition, anchor_expression, fallback = held(body)
        for event in ("history/divider", "row measurement", "late top padding", "live append", "reconciliation"):
            old_h, new_h, viewport, old_top, new_top, old_scroll, divider, pad, delta = z3.Ints("old_h new_h viewport old_top new_top old_scroll divider pad delta")
            before, after = z3.Ints("previous_boundary next_boundary")
            old_newest, new_newest = z3.Ints("old_newest new_newest")
            offset = old_scroll - old_newest
            values = {"old_content_h": old_h, "viewport_h": viewport, "previous_boundary.index": before,
                      "app_state.g_chat_read_boundary.index": after, "top": new_newest, "anchor_offset": offset,
                      "old_scroll_y": old_scroll, "old_y": old_scroll, "anchor.?.offset": old_scroll - old_top,
                      "app_state.g_chat_layout_top_pad": pad + delta, "old_top_pad": pad}
            expression = anchor_expression.replace("anchor.?.offset", "anchor_offset_value")
            values["anchor_offset_value"] = old_scroll - old_top
            drop = symbolic(condition, values)
            anchor = symbolic(expression, values)
            selected = z3.If(drop, z3.If(after >= 0, divider - pad - delta, new_h - viewport), anchor)
            scroll = z3.If(new_h <= viewport, new_h - viewport, z3.If(selected < 0, 0, z3.If(selected > new_h - viewport, new_h - viewport, selected)))
            solver = z3.Solver()
            solver.add(viewport >= 100, viewport <= 1000, old_h > viewport, old_h <= 10000,
                       new_h > viewport, new_h <= 10000, old_scroll >= 0, old_scroll <= old_h - viewport,
                       old_top >= old_scroll, old_top < old_scroll + viewport, new_top >= 0, new_top < new_h,
                       pad >= 0, pad <= 100, divider >= pad + delta, divider <= new_h,
                       before >= -1, before <= 1, after >= -1, after <= 1,
                       new_top + old_scroll - old_top >= 0,
                       new_top + old_scroll - old_top <= new_h - viewport,
                       old_newest > old_top, old_newest < old_scroll + viewport,
                       new_newest > new_top, new_newest < new_h,
                       new_newest + old_scroll - old_newest >= 0,
                       new_newest + old_scroll - old_newest <= new_h - viewport)
            if event == "late top padding":
                solver.add(delta >= 1, delta <= 32, new_top == old_top + delta, new_h == old_h + delta, before == after)
            else:
                solver.add(delta == 0)
            if event not in ("row measurement", "reconciliation"):
                solver.add(new_newest - new_top == old_newest - old_top)
            if event == "history/divider":
                solver.add(new_h >= old_h, new_top >= old_top,
                           z3.Implies(z3.And(before == -1, after >= 0),
                                      z3.And(new_top == old_top + 28, new_h == old_h + 28, divider == old_top)))
            if event != "history/divider":
                solver.add(before == after)
            if event == "live append":
                solver.add(new_top == old_top, new_h >= old_h)
            solver.add(new_newest - scroll != old_newest - old_scroll)
            outcome = solver.check()
            label = name + "/" + event
            if outcome == z3.sat:
                model = solver.model()
                witness = {str(v): model.eval(v, model_completion=True).as_long() for v in (old_h, new_h, viewport, old_top, new_top, old_scroll, divider, pad, delta, before, after, old_newest, new_newest)}
                witness.update(property=label, before_y=model.eval(old_newest - old_scroll).as_long(), after_y=model.eval(new_newest - scroll).as_long())
                failures.append(label)
                witnesses.append(witness)
                print("FAIL", label, json.dumps(witness, sort_keys=True))
            elif outcome == z3.unsat:
                print("PASS", label, "all integer geometries within the stated bounds")
            else:
                raise RuntimeError("SMT solver returned " + str(outcome))
    if replay_code:
        if witnesses:
            replay(root, witnesses, function)
        else:
            replay(root, json.loads((ROOT / "tools/fixtures/SOFT-2713/chat-still-regressions.json").read_text()), function, preserved=True)
    return {"tool": "z3-solver==4.13.4.0", "failures": failures, "counterexamples": witnesses, "sync_commit": recorded["sync_commit"]}


def self_test(root, replay_code=False):
    with tempfile.TemporaryDirectory(prefix="chat-still-mutation-") as directory:
        scratch = pathlib.Path(directory)
        (scratch / "src").mkdir()
        source = (root / "src/chat_session.zig").read_text()
        for name in ("refreshChatTranscript", "chatRelayoutPreservingScroll"):
            original = function(source, name)
            condition = held(original)[0]
            broken = original.replace("if (" + condition + ") null else if (anchor_top)", "if (old_content_h >= 0) null else if (anchor_top)")
            assert original != broken
            source = source.replace(original, broken)
        (scratch / "src/chat_session.zig").write_text(source)
        (scratch / "src/chat_history.zig").write_text((root / "src/chat_history.zig").read_text())
        (scratch / "src/chat_render.zig").write_text((root / "src/chat_render.zig").read_text())
        result = check(scratch, replay_code)
        assert len(result["failures"]) == 10, "Each anchor obligation must reject the real-source scratch break"
        print("MUTATION PASS: both production held_y guards were broken in scratch; every obligation rejected them")
        if replay_code:
            history = (root / "src/chat_history.zig").read_text()
            render = (root / "src/chat_render.zig").read_text()
            capture = function(history, "readAnchor")
            for label in ("first visible row", "uncompensated cached padding"):
                (scratch / "src/chat_session.zig").write_text((root / "src/chat_session.zig").read_text())
                broken_history = history.replace(capture, capture.replace("result = .{", "if (result == null) result = .{")) if label == "first visible row" else history
                broken_render = render.replace("const held_y = app_state.g_chat_scroll_y + delta;", "const held_y = app_state.g_chat_scroll_y;") if label == "uncompensated cached padding" else render
                assert broken_history != history or broken_render != render
                (scratch / "src/chat_history.zig").write_text(broken_history)
                (scratch / "src/chat_render.zig").write_text(broken_render)
                try:
                    replay(scratch, json.loads((ROOT / "tools/fixtures/SOFT-2713/chat-still-regressions.json").read_text()), function, preserved=True)
                except ValueError as error:
                    if "TestExpectedEqual" not in str(error):
                        raise
                    print("MUTATION PASS: native regressions rejected", label)
                else:
                    raise ValueError("Native regressions accepted " + label)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=pathlib.Path, default=ROOT)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--replay", action="store_true")
    parser.add_argument("--inherit-from")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test(args.source_root, args.replay)
        result = check(args.source_root, args.replay)
        if result["failures"] and args.inherit_from:
            baseline = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "--verify", args.inherit_from + "^{commit}"], stderr=subprocess.PIPE, timeout=10).decode().strip()
            coverage = json.loads((ROOT / "tools/chat-still/coverage.json").read_text())
            files = sorted({record["file"] for section in ("functions", "types") for record in coverage[section].values()})
            if all((args.source_root / file).read_bytes() == subprocess.check_output(
                    ["git", "-C", str(ROOT), "show", baseline + ":" + file], stderr=subprocess.PIPE, timeout=10) for file in files):
                result["inherited_from"] = baseline
                print("INHERITED:", len(result["failures"]), "findings; every modeled source file is byte-identical to", baseline)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2) + "\n")
        sys.exit(bool(result["failures"]) and not result.get("inherited_from"))
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print("BASELINE UNAVAILABLE:", error, file=sys.stderr)
        sys.exit(2)
    except (ValueError, KeyError, AttributeError, StopIteration, SyntaxError) as error:
        print("MODEL DRIFT:", error, file=sys.stderr)
        sys.exit(2)
