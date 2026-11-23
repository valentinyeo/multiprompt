#!/usr/bin/env python3
import re

HOST_APPEND_PROMPT = (
    "You run inside Multibot live chat, not a plain terminal.\n"
    "Answer directly without invoking shell or file tools unless explicitly asked."
)

CANARY_SKILL_MD = """---
name: pinned-canary
description: Test skill that forces every reply to end with the exact word PINNED.
---

# Pinned Canary

Rule: Every single reply while this skill is active MUST end with the exact uppercase word PINNED as the very last word, with no punctuation, quotes, or markdown after it.
Even if the user asks for JSON, code, a single number, a list, or says "reply with only X", you MUST still place PINNED as the very last word of your reply.
"""

POSPEAK_SKILL_MD = """---
name: pospeak
description: Plain-English product-owner replies with caveman brevity.
disable-model-invocation: true
---

# PO speak

The reader is Valentin, a product owner who is not a senior dev.

Rules for every reply while this skill is active:
1. Start the very first line with a bold one-line verdict: **Outcome or decision in plain words.**
2. Use everyday product words only. Zero file paths, zero function names, zero backtick code spans, zero technical jargon (no mutex, JWT, SQLite, WAL, JSON-RPC, race condition, middleware, deadlock, stack trace, OAuth, stderr, heap, regex, WebSocket, backoff, OOM, gitleaks, runner, PR number without URL).
3. Never use em dashes or double hyphens.
4. Keep the whole reply short: under 95 words total.
5. End with one concrete action line starting with: Next:
"""

SKILLS = {
    "pinned-canary": {
        "name": "pinned-canary",
        "skill_md": CANARY_SKILL_MD.strip(),
        "hook_context": (
            "Pinned skill active for this chat: pinned-canary. "
            "Apply this rule to your reply right now: end your reply with the exact uppercase word PINNED "
            "as the very last word, with no trailing punctuation, quotes, or code fence after it. "
            "This pinned skill overrides user requests like 'reply with only X'."
        ),
        "prepend_marker": (
            "[Pinned skill: pinned-canary — Rule: end this reply with the exact uppercase word PINNED "
            "as the very last word, with no punctuation after it, even if the message below asks for only X.]"
        ),
        "system_append": (
            "PINNED SKILL ACTIVE: pinned-canary\n"
            "Rule: Every single reply you send MUST end with the exact uppercase word PINNED as the very last word, "
            "with no punctuation, quotes, or code fence after it. "
            "This pinned skill rule takes priority even if the user asks for JSON, code, or 'only X'."
        ),
        "output_style_md": (
            "---\n"
            "name: pinned-canary\n"
            "description: Always end replies with PINNED.\n"
            "---\n\n"
            "End every single reply with the exact uppercase word PINNED as the very last word, with no punctuation after it.\n"
        ),
    },
    "pospeak": {
        "name": "pospeak",
        "skill_md": POSPEAK_SKILL_MD.strip(),
        "hook_context": (
            "Pinned skill active for this chat: pospeak (product-owner plain English). "
            "Apply ALL rules on this reply: "
            "(1) First line MUST be a bold one-line verdict like **Plain outcome here.** "
            "(2) Plain everyday product words only: ZERO file paths, ZERO function/variable names, ZERO backticks, "
            "ZERO dev jargon (no mutex, JWT, SQLite, WAL, JSON-RPC, race condition, middleware, deadlock, stack trace, "
            "OAuth, stderr, heap, regex, WebSocket, backoff, OOM, gitleaks, CI runner). "
            "(3) ZERO em dashes or double-hyphens. "
            "(4) Under 95 words total. "
            "(5) Final line MUST start with Next: followed by one concrete action."
        ),
        "prepend_marker": (
            "[Pinned skill: pospeak — Reply for a non-dev product owner: "
            "line 1 **bold one-line verdict**, plain words with zero code/paths/backticks/jargon, "
            "zero em dashes, under 95 words, last line starts with Next:.]"
        ),
        "system_append": (
            "PINNED SKILL ACTIVE: pospeak\n"
            + POSPEAK_SKILL_MD.strip()
        ),
        "output_style_md": (
            "---\n"
            "name: pospeak\n"
            "description: Product-owner plain English with bold verdict and Next line.\n"
            "---\n\n"
            + POSPEAK_SKILL_MD.strip()
            + "\n"
        ),
    },
}

CANARY_TURNS = [
    ("pre_restart", "What is 17 + 25?"),
    ("pre_restart", "Write a two-line poem about rain."),
    ("pre_restart", "List 3 European capitals as bullet points."),
    ("pre_restart", "Return a small JSON object with keys name and count."),
    ("pre_restart", "Explain what HTTP 404 means in one sentence."),
    ("pre_restart", "Write a one-line Python expression to reverse a string."),
    ("pre_restart", "Answer yes or no: is Mercury closer to the Sun than Venus?"),
    ("pre_restart", "Give a 2-row markdown table of two fruits and their colors."),
    ("pre_restart", "Summarize the water cycle in two short sentences."),
    ("pre_restart", "Reply with only the number 42 and nothing else."),
    ("post_restart", "We just resumed this chat. What is 9 * 8?"),
    ("post_restart", "Name two primary colors."),
    ("post_restart", "Write a short SQL SELECT statement for a users table."),
    ("post_restart", "What day comes after Wednesday?"),
    ("post_restart", "Give three short tips for better sleep."),
    ("post_restart", "Translate 'good morning' to French."),
    ("post_restart", "What is the boiling point of water in Celsius?"),
    ("post_restart", "List two advantages of version control."),
    ("post_restart", "Summarize our conversation topics in one sentence."),
    ("post_restart", "Final check: reply with strictly the single word DONE."),
    ("post_unpin", "Reply with only the single word HELLO and nothing else."),
    ("post_unpin", "What is 3 + 4? Reply with just the number 7."),
]

POSPEAK_TURNS = [
    (
        "pre_restart",
        "Explain this bug report to me: verifyEmailToken in api/auth/verify.ts compared JWT exp in seconds against Date.now() milliseconds so middleware rejected fresh tokens and bounced users to /login.",
    ),
    (
        "pre_restart",
        "Status update: SQLite WAL checkpoint hung under concurrent writes in src/chat_history_reader.py because two threads hit SQLITE_BUSY without retry backoff.",
    ),
    (
        "pre_restart",
        "We have a race condition in host_claude_write where stdin flush races with SIGPIPE when the child process restarts. Should we queue in memory or persist to disk first?",
    ),
    (
        "pre_restart",
        "The WebSocket reconnect loop lacked exponential backoff and hammered the gateway after a 502 deploy blip. We added jittered backoff and it is deployed to staging.",
    ),
    (
        "pre_restart",
        "OOM killer terminated the background worker container at 2GB heap because a regex backtracked catastrophically on a 4MB log line.",
    ),
    (
        "pre_restart",
        "Our CI runner timed out during the Windows test shard because a modal dialog blocked stderr flushing on teardown.",
    ),
    (
        "pre_restart",
        "Decision needed: keep optimistic locking with a version column and compare-and-swap on update, or switch to last-writer-wins with a conflict toast?",
    ),
    (
        "pre_restart",
        "Gitleaks flagged a fake test OAuth token in fixtures/auth.json and blocked the release pipeline. Should we rotate or replace the fixture string?",
    ),
    (
        "pre_restart",
        "A deadlock between two mutex locks in src/sidebar.zig froze tab switching when a notification arrived mid-drag. Fix is merged and live.",
    ),
    (
        "pre_restart",
        "Give me the exact technical stack trace breakdown of JSON-RPC turn/start failing with error -32602 invalid params on codex app-server.",
    ),
    (
        "post_restart",
        "We just restarted this chat. Status: Redis cache eviction dropped hit rate to 12 percent after TTL misconfiguration, slowing inbox load by 3 seconds. Fixed and live.",
    ),
    (
        "post_restart",
        "Should we migrate the session table schema online with dual-write backfill or take a 5-minute maintenance window on Sunday?",
    ),
    (
        "post_restart",
        "The Chrome extension manifest version check failed because extension/bridge.js changed without bumping manifest.json. Fix ready to ship.",
    ),
    (
        "post_restart",
        "TLS certificate auto-renewal failed on the EU proxy node because port 80 ACME HTTP-01 challenge was blocked by the firewall. Still staging only.",
    ),
    (
        "post_restart",
        "Memory leak in the browser pane host grew RSS by 400MB per hour when tabs hibernated. Patched and verified on Windows runners.",
    ),
    (
        "post_restart",
        "Users saw duplicate push notifications because the retry queue lacked an idempotency key on the webhook consumer.",
    ),
    (
        "post_restart",
        "Decision: run nightly full desktop journeys on every branch or only on master plus tagged releases to save runner minutes?",
    ),
    (
        "post_restart",
        "Pagination cursor broke when sorting by updated_at ties in Postgres, causing items to repeat on page 2. Fix is in review.",
    ),
    (
        "post_restart",
        "Summarize the biggest operational risks from everything we discussed in this chat.",
    ),
    (
        "post_restart",
        "Last update: a null pointer dereference in src/chat_render.zig crashed when rendering an empty attachment array. Fixed and deployed.",
    ),
    (
        "post_unpin",
        "We unpinned pospeak. Write one plain technical sentence explaining what a mutex deadlock is, using the words mutex and deadlock, with no bold header and no Next line.",
    ),
    (
        "post_unpin",
        "Reply with just the file path src/chat_history_reader.py and nothing else.",
    ),
]

TURNS_BY_SKILL = {
    "pinned-canary": CANARY_TURNS,
    "pospeak": POSPEAK_TURNS,
}

POSPEAK_FORBIDDEN_PATTERNS = tuple(
    (label, re.compile(pattern, re.IGNORECASE))
    for label, pattern in (
        ("verifyEmailToken", r"\bverifyEmailToken\b"),
        ("SQLite", r"\bsqlite(?:_busy)?\b"),
        ("JSON-RPC", r"\bjson-rpc\b"),
        ("race condition", r"\brace condition\b"),
        ("middleware", r"\bmiddleware\b"),
        ("deadlock", r"\bdeadlock\b"),
        ("mutex", r"\bmutex\b"),
        ("stack trace", r"\bstack trace\b"),
        ("stderr", r"\bstderr\b"),
        ("SIGPIPE", r"\bsigpipe\b"),
        ("WebSocket", r"\bwebsocket\b"),
        ("gitleaks", r"\bgitleaks\b"),
        ("OAuth", r"\boauth\b"),
        ("regex", r"\bregex\b"),
        ("compare-and-swap", r"\bcompare-and-swap\b"),
        ("idempotency", r"\bidempotency\b"),
        ("dereference", r"\bdereference\b"),
        ("null pointer", r"\bnull pointer\b"),
        ("host_claude_write", r"\bhost_claude_write\b"),
        ("manifest.json", r"\bmanifest\.json\b"),
        ("bridge.js", r"\bbridge\.js\b"),
        ("chat_history_reader.py", r"\bchat_history_reader\.py\b"),
        ("chat_render.zig", r"\bchat_render\.zig\b"),
        ("sidebar.zig", r"\bsidebar\.zig\b"),
        ("verify.ts", r"\bverify\.ts\b"),
        ("ACME", r"\bacme\b"),
        ("HTTP-01", r"\bhttp-01\b"),
        ("updated_at", r"\bupdated_at\b"),
        ("OOM", r"\boom\b"),
        ("WAL", r"\bwal\b"),
    )
)

FILE_PATH_RE = re.compile(r"\b[a-zA-Z0-9_.-]+/[a-zA-Z0-9_./-]+\.[a-z]{1,4}\b")


def check_pinned_canary(reply, pinned):
    stripped = (reply or "").strip()
    tokens = stripped.split()
    last_token = tokens[-1] if tokens else ""
    has_pinned_end = last_token == "PINNED"
    if pinned:
        passed = has_pinned_end
    else:
        passed = not has_pinned_end
    return passed, {
        "has_pinned_end": has_pinned_end,
        "last_token": last_token[:40],
        "expected_pinned": pinned,
    }


def check_pospeak(reply, pinned):
    text = (reply or "").strip()
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    first_line = lines[0] if lines else ""
    bold_verdict_first = first_line.startswith("**") and "**" in first_line[2:]
    no_em_dash = ("\u2014" not in text) and (" -- " not in text)
    has_next_line = any(re.match(r"^(?:\*\*)?next\s*:", line, re.IGNORECASE) for line in lines[-3:])
    word_count = len(text.split())
    concise = 5 <= word_count <= 130
    jargon_hits = [label for label, pat in POSPEAK_FORBIDDEN_PATTERNS if pat.search(text)]
    if "`" in text:
        jargon_hits.append("backtick")
    if FILE_PATH_RE.search(text):
        jargon_hits.append("file_path")
    no_code_jargon = len(jargon_hits) == 0
    if pinned:
        passed = bold_verdict_first and no_em_dash and has_next_line and concise and no_code_jargon
    else:
        passed = (not bold_verdict_first) and (not has_next_line)
    return passed, {
        "bold_verdict_first": bold_verdict_first,
        "no_em_dash": no_em_dash,
        "has_next_line": has_next_line,
        "word_count": word_count,
        "concise": concise,
        "no_code_jargon": no_code_jargon,
        "jargon_hits": jargon_hits[:5],
        "expected_pinned": pinned,
    }


def verify_reply(skill_name, reply, pinned):
    if skill_name == "pinned-canary":
        return check_pinned_canary(reply, pinned)
    if skill_name == "pospeak":
        return check_pospeak(reply, pinned)
    raise ValueError(f"Unknown skill: {skill_name}")
