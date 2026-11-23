import contextlib
import io
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import check


class HeadFindingsTest(unittest.TestCase):
    def test_each_head_finding_is_a_failure_after_mutations_and_replay(self):
        for failed in (*check.RULES, None):
            with self.subTest(rule=failed), tempfile.TemporaryDirectory() as directory:
                output = pathlib.Path(directory) / "result"
                values = json.loads((check.HERE / "decisions.json").read_text())
                results = {rule: {"status": "FAIL" if rule == failed else "PASS", "trace": []} for rule in check.RULES}
                with patch("sys.argv", ["check.py", "--self-test", "--output", str(output)]), \
                     patch.object(check, "coverage", return_value={"sync_commit": "base"}), \
                     patch.object(check, "tables", return_value=values), \
                     patch.object(check, "check", return_value=results), \
                     patch.object(check, "self_test", return_value=["SingleVisibleCopy", "NoFalseNotSent"]), \
                     patch.object(check, "replay") as replay, contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(1 if failed else 0, check.main())
                summary = json.loads((output / "summary.json").read_text())
                self.assertEqual([failed] if failed else [], summary["failures"])
                self.assertIsNone(summary["inherited_from"])
                self.assertEqual(2, replay.call_count)

    def test_inheritance_cannot_waive_a_head_finding(self):
        with patch("sys.argv", ["check.py", "--self-test", "--inherit-from", "HEAD"]), \
             contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            check.main()
        self.assertEqual(2, error.exception.code)


if __name__ == "__main__":
    unittest.main()
