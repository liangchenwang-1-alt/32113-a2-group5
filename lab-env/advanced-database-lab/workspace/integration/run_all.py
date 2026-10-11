"""Member 1 integration runner. Liangchen Wang, 25142542.

Run on the host from the lab directory; Python 3.9+ and Docker Compose required.
Rebuilds project tables twice ONLY with --allow-reset. No volume deletion.
Keeps psql commands, all query output, exit codes, assertions and fingerprints.
This runner targets the current small-fixture contract, not source_systems/.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

FILES = [
    'part3_warehouse_etl/01_source_ddl.sql',
    'part3_warehouse_etl/02_warehouse_ddl.sql',
    'part3_warehouse_etl/90_fixtures_sources.sql',
    'part3_warehouse_etl/02b_dimensions.sql',
    'part3_warehouse_etl/03_identity_xref.sql',
    'part3_warehouse_etl/04_etl_load_facts.sql',
    'part5_reports_testing/10_report_views.sql',
    'part3_warehouse_etl/05_reconciliation.sql',
    'part5_reports_testing/r1_r2_r3_reports.sql',
    'part5_reports_testing/t5_idempotency_fingerprint.sql',
    'part5_reports_testing/t9_t13_guard_checks.sql',
]

def compare_fingerprints(first, second):
    if not first.strip() or first.strip() != second.strip():
        raise RuntimeError('Two-build fingerprint comparison failed')

class Runner:
    def __init__(self, lab, evidence, timeout=180):
        self.lab, self.evidence, self.timeout = lab, evidence, timeout
        self.steps = []

    def execute(self, label, sql=None, command=None, csv=False):
        cmd = command or ['docker', 'compose', 'exec', '-T', 'postgres',
                          'psql', '-X', '-v', 'ON_ERROR_STOP=1',
                          '-P', 'pager=off', '-U', 'student', '-d', 'lab']
        if csv:
            cmd = cmd + ['--csv', '-q', '-t']
        try:
            result = subprocess.run(cmd, cwd=self.lab, input=sql, text=True,
                                    encoding='utf-8', errors='replace',
                                    capture_output=True, timeout=self.timeout)
        except (OSError, subprocess.TimeoutExpired) as exc:
            (self.evidence / (label + '.txt')).write_text(str(exc), encoding='utf-8')
            self.steps.append({'step': label, 'exit': None, 'error': str(exc)})
            raise RuntimeError(label + ': could not finish') from exc
        (self.evidence / (label + '.txt')).write_text(
            'COMMAND: ' + ' '.join(cmd) + '\nEXIT: ' + str(result.returncode)
            + '\nSTDOUT:\n' + result.stdout + '\nSTDERR:\n' + result.stderr,
            encoding='utf-8')
        self.steps.append({'step': label, 'exit': result.returncode})
        if result.returncode != 0:
            raise RuntimeError(label + ': failed; see saved output')
        return result.stdout

    def build(self, number, checks):
        for index, name in enumerate(FILES, 1):
            self.execute(f'run{number}_{index:02d}_{Path(name).stem}',
                         (self.lab / 'workspace' / name).read_text(encoding='utf-8-sig'))
        self.execute(f'run{number}_acceptance', checks)
        self.execute(f'run{number}_identity_counts',
                     'SELECT source_system, match_rule, match_status, count(*) AS rows '
                     'FROM dw.customer_xref GROUP BY 1,2,3 ORDER BY 1,2,3;')
        fingerprint = (self.lab / 'workspace' / FILES[9]).read_text(encoding='utf-8-sig')
        return self.execute(f'run{number}_fingerprint', fingerprint, csv=True)

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lab-dir', type=Path, default=Path.cwd())
    parser.add_argument('--allow-reset', action='store_true',
                        help='Permit two rebuilds of the project tables in database lab')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args(argv)
    if not args.allow_reset:
        parser.error('Rebuild replaces project tables. Use an isolated lab copy and --allow-reset.')
    lab = args.lab_dir.resolve()
    check_path = Path(__file__).resolve().with_name('acceptance_checks.sql')
    required = [lab / 'docker-compose.yml', check_path]
    required += [lab / 'workspace' / name for name in FILES]
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        print('Missing required files:\n' + '\n'.join(missing), file=sys.stderr)
        return 2
    # Preflight completes before any database command.
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    evidence = lab / 'workspace' / 'evidence' / ('member1_' + stamp)
    evidence.mkdir(parents=True)
    runner = Runner(lab, evidence, args.timeout)
    status, reason = 'FAIL', ''
    hashes = {str(p.relative_to(lab)) if p.is_relative_to(lab) else p.name:
              hashlib.sha256(p.read_bytes()).hexdigest() for p in required}
    try:
        runner.execute('00_readiness', command=['docker', 'compose', 'exec', '-T',
                       'postgres', 'pg_isready', '-U', 'student', '-d', 'lab'])
        checks = check_path.read_text(encoding='utf-8-sig')
        first = runner.build(1, checks)
        second = runner.build(2, checks)
        compare_fingerprints(first, second)
        status = 'PASS'
    except Exception as exc:
        reason = str(exc)
    summary = {'owner': 'Liangchen Wang', 'student_id': '25142542',
               'status': status, 'reason': reason, 'timestamp_utc': stamp,
               'scope': 'Current small-fixture contract; not new source package acceptance',
               'input_sha256': hashes, 'steps': runner.steps}
    (evidence / 'SUMMARY.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (evidence / 'SUMMARY.md').write_text(
        '# Member 1 integration run\n\nOwner: Liangchen Wang (25142542)\n\n'
        + 'Result: ' + status + '\n\n' + (reason or 'Two builds passed the supplied assertions and matched fingerprints.')
        + '\n\nScope: current small-fixture contract. New source-system integration, '
        + 'manual report review and demo access require separate acceptance.\n', encoding='utf-8')
    print(status + ': ' + str(evidence))
    if reason:
        print(reason, file=sys.stderr)
    return 0 if status == 'PASS' else 1

if __name__ == '__main__':
    sys.exit(main())
