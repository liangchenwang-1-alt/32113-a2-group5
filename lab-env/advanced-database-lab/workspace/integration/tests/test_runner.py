"""Offline checks; these do not execute Docker or verify the group database."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runner', Path(__file__).resolve().parents[1] / 'code/run_all.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class RunnerTests(unittest.TestCase):
    def test_comparison_accepts_equal_and_rejects_changed_or_empty(self):
        runner.compare_fingerprints('a,1,hash\n', 'a,1,hash\n')
        for a, b in [('a,1,x', 'a,1,y'), ('', '')]:
            with self.assertRaises(RuntimeError):
                runner.compare_fingerprints(a, b)

    def test_sql_failure_keeps_output_and_raises(self):
        with tempfile.TemporaryDirectory() as td:
            r = runner.Runner(Path(td), Path(td))
            failed = subprocess.CompletedProcess([], 3, 'query output', 'assertion failed')
            with patch.object(runner.subprocess, 'run', return_value=failed):
                with self.assertRaises(RuntimeError):
                    r.execute('assertion', 'DO $$ BEGIN RAISE EXCEPTION \'bad\'; END $$;')
            self.assertIn('assertion failed', (Path(td) / 'assertion.txt').read_text())
            self.assertEqual(r.steps[0]['exit'], 3)

    def test_missing_files_never_calls_database(self):
        with tempfile.TemporaryDirectory() as td:
            with patch.object(runner.subprocess, 'run') as process:
                self.assertEqual(runner.main(['--lab-dir', td, '--allow-reset']), 2)
                process.assert_not_called()

    def test_reset_requires_explicit_flag(self):
        with patch.object(runner.subprocess, 'run') as process:
            with self.assertRaises(SystemExit):
                runner.main([])
            process.assert_not_called()

    def test_psql_meta_commands_preserved(self):
        with tempfile.TemporaryDirectory() as td:
            r = runner.Runner(Path(td), Path(td))
            sql = '\\echo report\nSELECT 1;'
            with patch.object(runner.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '1\n', '')) as process:
                r.execute('query', sql)
                self.assertEqual(process.call_args.kwargs['input'], sql)
                self.assertIn('ON_ERROR_STOP=1', process.call_args.args[0])

    def test_build_stops_at_first_failure(self):
        with tempfile.TemporaryDirectory() as td:
            lab = Path(td)
            first = lab / 'workspace' / runner.FILES[0]
            first.parent.mkdir(parents=True)
            first.write_text('SELECT 1;')
            r = runner.Runner(lab, lab)
            with patch.object(r, 'execute', side_effect=RuntimeError('step failed')) as execute:
                with self.assertRaises(RuntimeError):
                    r.build(1, 'checks')
                self.assertEqual(execute.call_count, 1)

    def test_main_records_two_build_success_or_mismatch(self):
        for fingerprints, expected in [(['table,1,abc', 'table,1,abc'], 'PASS'),
                                       (['table,1,abc', 'table,1,def'], 'FAIL')]:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as td:
                lab = Path(td)
                (lab / 'docker-compose.yml').write_text('services: {}')
                for name in runner.FILES:
                    path = lab / 'workspace' / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text('SELECT 1;')
                with patch.object(runner.Runner, 'execute', return_value='ready'):
                    with patch.object(runner.Runner, 'build', side_effect=fingerprints) as build:
                        code = runner.main(['--lab-dir', td, '--allow-reset'])
                        self.assertEqual(build.call_count, 2)
                summary_path = next((lab / 'workspace/evidence').glob('*/SUMMARY.json'))
                self.assertEqual(json.loads(summary_path.read_text())['status'], expected)
                self.assertEqual(code, 0 if expected == 'PASS' else 1)

if __name__ == '__main__':
    unittest.main()
