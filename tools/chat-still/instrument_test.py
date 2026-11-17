import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("chat_still_instrument", pathlib.Path(__file__).with_name("instrument.py"))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
ROOT = pathlib.Path(__file__).resolve().parents[2]


class InstrumentTest(unittest.TestCase):
    def test_only_adds_read_only_probe_and_repeats_without_changes(self):
        original = (ROOT / "src/chat_render.zig").read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = root / "src/chat_render.zig"
            path.parent.mkdir()
            path.write_bytes(original)
            metadata = root / "probe.json"
            first = probe.instrument(root, metadata)
            changed = path.read_bytes()
            self.assertEqual(first, probe.instrument(root, metadata))
            self.assertEqual(path.read_bytes(), changed)
            restored = changed.replace(probe.PROBE.read_bytes(), b"", 1).replace(probe.HOOK.encode(), b"", 1)
            self.assertEqual(restored, original)
            self.assertEqual(first["original_sha256"], hashlib.sha256(original).hexdigest())
            self.assertEqual(first["instrumented_sha256"], hashlib.sha256(changed).hexdigest())
            self.assertEqual(json.loads(metadata.read_text()), first)
            path.write_bytes(changed + b"\n")
            with self.assertRaisesRegex(ValueError, "partly installed"):
                probe.instrument(root, metadata)

    def test_changed_paint_boundary_fails_without_mutating_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = root / "src/chat_render.zig"
            path.parent.mkdir()
            path.write_bytes(b"fn changedPainter() void {}\n")
            with self.assertRaisesRegex(ValueError, "paint boundary changed"):
                probe.instrument(root, root / "probe.json")
            self.assertEqual(path.read_bytes(), b"fn changedPainter() void {}\n")


if __name__ == "__main__":
    unittest.main()
