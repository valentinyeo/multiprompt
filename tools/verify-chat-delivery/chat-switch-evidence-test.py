import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

proof = None


def cpu():
    return dict(input='ctrl-digit', timing_scope=proof.TIMING_SCOPE, shown_ms=10, cpu_at_shown_ms=5, elapsed_ms=1200, cpu_ms=30,
                cpu_one_core_percent=2.5, observer_cpu_ms=4, machine_busy_percent=10,
                cpu_points=[dict(elapsed_ms=0, cpu_ms=0), dict(elapsed_ms=25, cpu_ms=10), dict(elapsed_ms=1200, cpu_ms=30)],
                image_probe=False, forced_paints=False)


class SwitchEvidenceTest(unittest.TestCase):
    def setUp(self):
        global proof
        path = Path(__file__).with_name('chat-switch-evidence.py')
        self.assertTrue(path.is_file(), 'Native switching requires its strict observation evaluator')
        spec = importlib.util.spec_from_file_location('switch_evidence', path)
        proof = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(proof)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bmp = struct.pack('<2sIHHI', b'BM', 70, 0, 0, 54) + struct.pack('<IiiHHIIiiII', 40, 2, 2, 1, 24, 0, 16, 0, 0, 0, 0) + bytes(16)
        def chunk(kind, raw):
            return struct.pack('>I', len(raw)) + kind + raw + struct.pack('>I', zlib.crc32(kind + raw))
        self.png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 2, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(14))) + chunk(b'IEND', b'')
        profiles = [dict(name='chat-' + str(i), source_completeness='complete-host-log', conversation_messages=3,
                         source_bytes=8192, source_records=10, runner_lengths_utf16=[[150, 1]], tool_record_bytes=[[400, 2]]) for i in range(5)]
        shapes = dict(content_policy=proof.POLICY, sessions=profiles)
        raw = json.dumps(shapes).encode()
        (self.root / 'chat-shapes.json').write_bytes(raw)
        generated = [dict(name=p['name'], source_completeness=p['source_completeness'], source_conversation_messages=3,
                          generated_conversation_messages=5, marker_messages=2, generated_bytes=8192, generated_records=12,
                          runner_messages=1, tool_records=2, ignored_source_padding_bytes=100) for p in profiles]
        self.value = dict(schema=1, source='GitHub Windows native desktop', setup_passed=True, errors=[], session_shells=[1, 2, 3, 4, 5],
                          fixture=dict(policy=proof.POLICY, shape_sha256=hashlib.sha256(raw).hexdigest(), sessions=generated),
                          modes={}, idle=dict(before=dict(cpu(), input='idle'), after=dict(cpu(), input='idle')))
        for mode in ('browser_closed', 'browser_open'):
            samples = []
            for index in range(20):
                source, target = index % 5 + 1, (index + 1) % 5 + 1
                prefix = mode + '-' + str(index)
                sample = dict(cpu(), index=index, source_shell=source, target_shell=target, hang_ms=4,
                              layout_width=800, client_width=800, post_paint_moves=False,
                              expected_latest=prefix, latest_message_verified=True, last_marker='fixture-last-' + str(target), latest_receipt=prefix + '.txt',
                              frame_probe=dict(source_shell=source, target_shell=target, image_probe=True, forced_paints=False,
                                               frame_scope=proof.FRAME_SCOPE, shown_ms=10, capture_started_ms=11,
                                               capture_completed_ms=15, elapsed_ms=1200, image_prefix=prefix))
                (self.root / sample['latest_receipt']).write_text(sample['expected_latest'] + '\n' + sample['last_marker'])
                for suffix in ('-first-observed', '-settled'):
                    (self.root / (prefix + suffix + '.bmp')).write_bytes(self.bmp)
                    (self.root / (prefix + suffix + '.png')).write_bytes(self.png)
                samples.append(sample)
            self.value['modes'][mode] = samples

    def evaluate(self):
        return proof.evaluate(self.value, self.root)

    def test_generated_complete_observations_validate_without_claiming_compositor_frames(self):
        result = self.evaluate()
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['switches'], 40)
        self.assertIs(result['product_acceptance_proven'], False)
        self.assertEqual(result['peak_observed_one_core_percent'], 40)
        self.assertIn(proof.FRAME_SCOPE, result['limitations'])

    def test_one_slow_outlier_fails_even_with_a_fast_median(self):
        self.value['modes']['browser_closed'][7]['shown_ms'] = 150
        result = self.evaluate()
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['category'], 'switch-budget')
        self.assertEqual([f['index'] for f in result['failures']], [7])

    def test_one_hundred_millisecond_hang_fails(self):
        self.value['modes']['browser_open'][3]['hang_ms'] = 100
        self.assertEqual(self.evaluate()['status'], 'failed')

    def test_first_observed_pixel_change_fails(self):
        path = self.root / 'browser_open-4-first-observed.bmp'
        path.write_bytes(self.bmp[:-1] + b'\xff')
        self.assertEqual(self.evaluate()['failures'][0]['first_observed_matches_settled'], False)

    def test_width_or_later_layout_movement_fails(self):
        self.value['modes']['browser_open'][0]['layout_width'] = 799
        self.value['modes']['browser_open'][1]['post_paint_moves'] = True
        self.assertEqual(len(self.evaluate()['failures']), 2)

    def test_setup_error_is_not_a_valid_budget_regression(self):
        self.value['setup_passed'] = False
        with self.assertRaisesRegex(ValueError, 'setup errors'):
            self.evaluate()

    def test_missing_mode_and_sample_are_rejected(self):
        self.value['modes']['browser_closed'].pop()
        with self.assertRaisesRegex(ValueError, 'twenty actual'):
            self.evaluate()
        del self.value['modes']['browser_open']
        with self.assertRaisesRegex(ValueError, 'both browser'):
            self.evaluate()

    def test_wrong_or_disconnected_target_is_rejected(self):
        self.value['modes']['browser_closed'][0]['target_shell'] = 1
        with self.assertRaisesRegex(ValueError, 'route'):
            self.evaluate()

    def test_self_report_without_the_actual_copied_receipt_is_rejected(self):
        (self.root / 'browser_closed-0.txt').write_text('different generated session')
        with self.assertRaisesRegex(ValueError, 'session endpoint receipt'):
            self.evaluate()

    def test_stale_target_with_correct_identity_is_a_product_failure_not_setup_error(self):
        sample = self.value['modes']['browser_closed'][0]
        (self.root / sample['latest_receipt']).write_text(sample['last_marker'])
        sample['latest_message_verified'] = False
        result = self.evaluate()
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['category'], 'switch-budget')
        self.assertIs(result['failures'][0]['latest_message_verified'], False)

    def test_nonfinite_or_negative_cpu_is_rejected(self):
        for value in (float('nan'), float('inf'), -1, True):
            with self.subTest(value=value):
                sample = cpu()
                sample['cpu_ms'] = value
                with self.assertRaises(ValueError):
                    proof.cpu(sample)

    def test_cpu_divided_by_logical_cores_is_rejected(self):
        sample = cpu()
        sample['cpu_one_core_percent'] /= 8
        with self.assertRaisesRegex(ValueError, 'one-core'):
            proof.cpu(sample)

    def test_missing_or_reversed_cpu_counter_coverage_is_rejected(self):
        for key, value in [('elapsed_ms', 1201), ('cpu_ms', 29)]:
            sample = cpu()
            sample['cpu_points'][-1][key] = value
            with self.assertRaisesRegex(ValueError, 'entire window'):
                proof.cpu(sample)

    def test_owned_job_cpu_uses_its_own_recorded_window(self):
        sample = cpu()
        sample['owned_job'] = dict(elapsed_ms=1250, cpu_ms=125, cpu_one_core_percent=10)
        self.assertEqual(proof.cpu(sample), 40)
        sample['owned_job']['cpu_one_core_percent'] = 1
        with self.assertRaisesRegex(ValueError, 'owned job CPU accounting'):
            proof.cpu(sample)

    def test_forced_paint_or_capture_cannot_be_presented_as_ordinary_cpu(self):
        for key in ('forced_paints', 'image_probe'):
            sample = cpu()
            sample[key] = True
            with self.assertRaisesRegex(ValueError, 'ordinary CPU'):
                proof.cpu(sample)

    def test_image_probe_must_replay_the_same_route(self):
        self.value['modes']['browser_closed'][0]['frame_probe']['target_shell'] = 3
        with self.assertRaisesRegex(ValueError, 'same route'):
            self.evaluate()

    def test_image_capture_cannot_precede_target_paint(self):
        self.value['modes']['browser_closed'][0]['frame_probe']['capture_started_ms'] = 9
        with self.assertRaisesRegex(ValueError, 'capture timing'):
            self.evaluate()

    def test_truncated_image_files_are_rejected(self):
        (self.root / 'browser_closed-0-first-observed.bmp').write_bytes(b'BM')
        with self.assertRaisesRegex(ValueError, 'BMP capture'):
            self.evaluate()

    def test_png_and_bmp_must_cover_the_same_rectangle(self):
        path = self.root / 'browser_closed-0-first-observed.png'
        raw = bytearray(path.read_bytes())
        raw[16:20] = struct.pack('>I', 3)
        path.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, 'dimensions differ'):
            self.evaluate()

    def test_artifact_paths_cannot_escape_the_owned_evidence(self):
        with self.assertRaisesRegex(ValueError, 'escapes'):
            proof.artifact(self.root, '../outside')

    def test_recorded_shape_hash_and_message_counts_are_checked(self):
        self.value['fixture']['sessions'][0]['generated_conversation_messages'] = 4
        with self.assertRaisesRegex(ValueError, 'conversation count'):
            self.evaluate()

    def test_partial_sample_cannot_be_inflated_to_an_unknown_full_source(self):
        path = self.root / 'chat-shapes.json'
        shapes = json.loads(path.read_text())
        shapes['sessions'][0]['source_completeness'] = 'partial-desktop-cache-sample'
        raw = json.dumps(shapes).encode()
        path.write_bytes(raw)
        self.value['fixture']['shape_sha256'] = hashlib.sha256(raw).hexdigest()
        self.value['fixture']['sessions'][0]['source_completeness'] = 'partial-desktop-cache-sample'
        with self.assertRaisesRegex(ValueError, 'partial source'):
            self.evaluate()

    def test_empty_geometry_is_invalid_evidence_not_a_speed_win(self):
        self.value['modes']['browser_open'][0]['layout_width'] = 0
        with self.assertRaisesRegex(ValueError, 'nonempty'):
            self.evaluate()

    def test_final_validation_requires_real_owned_cleanup_receipts(self):
        with self.assertRaises(OSError):
            proof.evaluate(self.value, self.root, require_cleanup=True)
        (self.root / 'process-tree.json').write_text(json.dumps(dict(activeAfterStop=0)))
        (self.root / 'result.json').write_text(json.dumps(dict(scratchRemoved=True)))
        self.assertEqual(proof.evaluate(self.value, self.root, require_cleanup=True)['status'], 'passed')
        (self.root / 'process-tree.json').write_text(json.dumps(dict(activeAfterStop=1)))
        with self.assertRaisesRegex(ValueError, 'cleanup incomplete'):
            proof.evaluate(self.value, self.root, require_cleanup=True)

    def test_cli_writes_failed_verdict_for_actual_budget_failure(self):
        self.value['modes']['browser_open'][0]['shown_ms'] = 151
        path = self.root / 'shape-switch.json'
        path.write_text(json.dumps(self.value))
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('chat-switch-evidence.py')), str(path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(json.loads(path.with_name('shape-switch-verdict.json').read_text())['category'], 'switch-budget')


if __name__ == '__main__':
    unittest.main()
