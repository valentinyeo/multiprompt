import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)

TOKEN = "97d2ee6a3f5a889f"
TAG = "[mp:" + TOKEN + "]"


def event(role, text, kind=None):
    return dict(type=kind or role, uuid="u-" + role, timestamp="2026-11-15T00:00:00.000Z",
                message=dict(role=role, content=text))


class ClearDisplayTagTest(unittest.TestCase):
    def test_clear_bubble_hides_the_delivery_tag(self):
        markup = "<command-name>/clear</command-name>\n<command-message>clear</command-message>\n<command-args>" + TAG + "</command-args>"
        shown = reader.conversation_event(event("user", markup), "claude")
        self.assertEqual(shown["text"], "/clear")
        self.assertNotIn("[mp:", shown["text"])
        literal = reader.conversation_event(event("user", "/clear " + TAG), "claude")
        self.assertEqual(literal["text"], "/clear")
        newline = reader.conversation_event(event("user", "Please review\n" + TAG), "claude")
        self.assertEqual(newline["text"], "Please review")

    def test_the_tag_is_hidden_for_every_role_and_a_reaction_keeps_it(self):
        assistant = reader.conversation_event(event("assistant", "Paused. Nothing was in flight. " + TAG), "claude")
        self.assertEqual(assistant["text"], "Paused. Nothing was in flight.")
        self.assertNotIn("[mp:", assistant["text"])
        reaction = "👍 to: Paused " + TAG
        kept = reader.conversation_event(event("user", reaction), "claude")
        self.assertEqual(kept["text"], reaction)
        history = reader.conversation_rows(dict(type="multiprompt_history", row=dict(role="user", text="/clear " + TAG, id="h")), "claude")
        self.assertEqual(history[0]["text"], "/clear")


if __name__ == "__main__":
    unittest.main()
