import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)

PAUSED = "Paused. Nothing was in flight."


class ClearResetSideTest(unittest.TestCase):
    def test_an_assistant_event_stays_an_assistant_reply(self):
        event = dict(type="assistant", uuid="paused", timestamp="2026-11-15T00:00:00.000Z",
                     message=dict(role="user", content=[dict(type="text", text=PAUSED)]))
        shown = reader.conversation_event(event, "claude")
        self.assertEqual(shown["role"], "assistant")
        self.assertEqual(shown["text"], PAUSED)

    def test_a_reset_page_does_not_repeat_the_reply_as_the_user(self):
        source = (ROOT / "src/chat_history_reader.py").read_text(encoding="utf-8")
        self.assertIn("def keep_reply_side(", source)
        rows = [
            dict(role="assistant", text=PAUSED, id="a"),
            dict(role="user", text="/clear", id="c"),
            dict(role="user", text=PAUSED, id="echo"),
            dict(role="assistant", text="Context empty. Fresh session.", id="b"),
        ]
        kept = reader.keep_reply_side(rows)
        self.assertIn(("assistant", PAUSED), [(row["role"], row["text"]) for row in kept])
        self.assertNotIn(("user", PAUSED), [(row["role"], row["text"]) for row in kept])
        self.assertIn(("user", "/clear"), [(row["role"], row["text"]) for row in kept])
        self.assertIn("paired = keep_reply_side(", source)


if __name__ == "__main__":
    unittest.main()
