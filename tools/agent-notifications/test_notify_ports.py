import importlib.util
from pathlib import Path
import re
import unittest

spec = importlib.util.spec_from_file_location("notify", Path(__file__).with_name("notify.py"))
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)

ZIG = Path(__file__).resolve().parents[2] / "src" / "notify_ports.zig"


class NotifyPortRange(unittest.TestCase):
    def test_hook_accepts_every_port_the_app_can_bind(self):
        text = ZIG.read_text(encoding="utf-8")
        first = int(re.search(r"FIRST_PORT: u16 = (\d+)", text).group(1))
        count = int(re.search(r"PORT_COUNT: usize = (\d+)", text).group(1))
        self.assertEqual(notify.NOTIFY_PORT_FIRST, first)
        self.assertEqual(notify.NOTIFY_PORT_LAST, first + count - 1)


if __name__ == "__main__":
    unittest.main()
