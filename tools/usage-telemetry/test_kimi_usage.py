from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("kimi-usage.py")
SPEC = importlib.util.spec_from_file_location("kimi_usage_helper", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NormalizeKimiUsageTest(unittest.TestCase):
    def test_normalizes_summary_and_rolling_window(self) -> None:
        result = MODULE.normalize_payload(
            {
                "usage": {
                    "name": "Weekly limit",
                    "used": 150,
                    "limit": 1000,
                    "resetAt": "2026-08-03T00:00:00Z",
                },
                "limits": [
                    {
                        "window": {"duration": 300, "timeUnit": "MINUTE"},
                        "detail": {
                            "remaining": 480,
                            "limit": 500,
                            "reset_in": 3600,
                        },
                    }
                ],
                "membership": {"name": "Kimi Max"},
                "account_id": "must-not-leak",
            }
        )

        self.assertEqual(result["plan"], "Kimi Max")
        self.assertEqual(result["quotas"][0]["usedPercent"], 15)
        self.assertEqual(result["quotas"][0]["windowMinutes"], 10080)
        self.assertEqual(result["quotas"][1]["usedPercent"], 4)
        self.assertEqual(result["quotas"][1]["windowMinutes"], 300)
        self.assertNotIn("must-not-leak", str(result))


if __name__ == "__main__":
    unittest.main()
