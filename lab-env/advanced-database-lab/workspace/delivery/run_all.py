"""Course-container integration for Liangchen Wang. Uses Python standard library and psql.
Run: docker compose exec -T python python /workspace/delivery/run_all.py --reset
Rebuilds this project's source/staging/warehouse tables twice, retaining audit history.
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import html
import io
import json
from pathlib import Path
import re
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
VIEWS = ['v_r1_customer_360','v_r2_transaction_by_date_channel','v_r2b_transaction_by_channel',
         'v_r3_channel_engagement','v_r4_service_case_summary','v_r5_data_quality_kpi','v_r6_attribution_reconciliation']
TABLES = ['dim_customer','dim_account','dim_date','dim_channel','customer_xref',
          'fact_transaction','fact_activity','fact_service_case','rejected_record']

def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"

class Pipeline:
    def __init__(self, compose, evidence):
        self.compose = compose
        self.evidence = evidence
        self.steps = []
        self.batch = ''

    def docker(self, *args):
        # Runs inside the course Python container, connecting over the Compose network.
        if args[:3] != ('exec','-T','postgres'):
            raise ValueError('Unsupported database operation')
        return [args[3],'-h',os.environ.get('PGHOST','postgres'),*args[4:]]

    def query(self, label, sql, expect_failure=False, csv_mode=False):
        cmd = self.docker('exec','-T','postgres','psql','-X','-v','ON_ERROR_STOP=1',
                          '-v','batch_id='+self.batch,'-U','student','-d','lab','-P','pager=off')
        if csv_mode:
            cmd += ['--csv','-q']
        result = subprocess.run(cmd,input=sql,text=True,encoding='utf-8',errors='replace',
                                capture_output=True,cwd=ROOT,timeout=180)
        self.steps.append({'step':label,'exit_code':result.returncode,'expected_failure':expect_failure})
        (self.evidence/(label+'.txt')).write_text(
            'EXIT: '+str(result.returncode)+'\nEXPECTED_FAILURE: '+str(expect_failure)+
            '\nSTDOUT:\n'+result.stdout+'\nSTDERR:\n'+result.stderr,encoding='utf-8')
        if expect_failure:
            if result.returncode == 0:
                raise RuntimeError(label+': deliberately bad data was NOT detected')
            if 'Accepted transaction count or amount mismatch' not in result.stderr:
                raise RuntimeError(label+': failed for an unexpected reason, inspect log')
        elif result.returncode != 0:
            raise RuntimeError(label+': SQL failed, inspect log')
        return result.stdout

    def fixture_checks(self, prefix):
        rows=list(csv.DictReader((ROOT.parent/'source_systems/expected_results.csv').open(encoding='utf-8-sig')))
        values=[]
        for row in rows:
            for field,system in [('core_customer_id','S1'),('payment_customer_id','S2'),('digital_customer_id','S3')]:
                if not row[field]:
                    continue
                status={'MATCH':'matched','CORE_ONLY':'matched','AMBIGUOUS':'ambiguous','UNMATCHED':'unmatched'}[row['expected_outcome']]
                values.append('('+','.join(sql_quote(v) for v in [system,row[field],row['core_customer_id'],status])+')')
        sql='''CREATE TEMP TABLE expected_identity(source_system text,source_id text,core_id text,status text);
INSERT INTO expected_identity VALUES '''+','.join(values)+''';
DO $$ BEGIN
IF EXISTS(SELECT 1 FROM expected_identity e LEFT JOIN dw.customer_xref x
ON x.source_system=e.source_system AND x.source_customer_id=e.source_id
LEFT JOIN dw.dim_customer c ON c.customer_key=x.customer_key
WHERE x.source_customer_id IS NULL OR x.match_status<>e.status
OR (e.status='matched' AND c.core_customer_id IS DISTINCT FROM e.core_id)
OR (e.status<>'matched' AND x.customer_key IS NOT NULL)) THEN
RAISE EXCEPTION 'Expected identity fixture mismatch'; END IF;
IF (SELECT count(*) FROM expected_identity)<>(SELECT count(*) FROM dw.customer_xref) THEN
RAISE EXCEPTION 'Identity coverage count mismatch'; END IF;
END $$;
SELECT count(*) AS verified_source_identities FROM expected_identity;'''
        self.query(prefix+'_expected_identity',sql)

    def identity_pipeline_test(self,prefix):
        # Exercise the actual xref INSERT and source-pair uniqueness guard, not only
        # the candidate function. Entire temporary rebuild is rolled back.
        ddl=(ROOT/'pipeline/20_warehouse.sql').read_text(encoding='utf-8')
        identity=(ROOT/'pipeline/30_identity.sql').read_text(encoding='utf-8')
        strip=lambda sql: re.sub(r'^\s*(BEGIN|COMMIT);\s*$', '', sql, flags=re.M)
        sql="""BEGIN;
INSERT INTO stg.customer(customer_id,first_name,last_name,date_of_birth,email,phone,state)
VALUES ('TESTC1','Unique','Person','1990-01-01','unique.person@example.test','0400111222','NSW'),
 ('TESTC2','Duplicate','Person','1991-01-01','duplicate.person@example.test','0400111223','NSW');
INSERT INTO stg.payment_customer(payment_customer_id,first_name,last_name,date_of_birth,email,phone)
VALUES ('TESTP1','Unique','Person',NULL,'unique.person@example.test',NULL),
 ('TESTP2','Duplicate','Person',NULL,'duplicate.person@example.test',NULL),
 ('TESTP3','Duplicate','Person',NULL,'duplicate.person@example.test',NULL),
 ('TESTP4','Unique','Person','2000-01-01','unique.person@example.test',NULL);
"""+strip(ddl)+strip(identity)+"""
DO $$ BEGIN
-- TESTP1 and TESTP4 deliberately share a source name/email pair: source uniqueness
-- must block the missing-DOB record; a known DOB conflict must also remain unlinked.
IF NOT EXISTS(SELECT 1 FROM dw.customer_xref WHERE source_customer_id='TESTP1' AND match_rule='R3_NAME_EMAIL' AND match_status='ambiguous' AND customer_key IS NULL) THEN
 RAISE EXCEPTION 'Actual xref source uniqueness failed'; END IF;
IF (SELECT count(*) FROM dw.customer_xref WHERE source_customer_id IN ('TESTP2','TESTP3') AND match_status='ambiguous' AND customer_key IS NULL)<>2 THEN
 RAISE EXCEPTION 'Actual xref duplicate pair failed'; END IF;
IF EXISTS(SELECT 1 FROM dw.customer_xref WHERE source_customer_id='TESTP4' AND customer_key IS NOT NULL) THEN
 RAISE EXCEPTION 'Actual xref known DOB conflict failed'; END IF;
END $$;
SELECT 'PASS actual xref source duplicate guard and DOB conflict' AS result;
ROLLBACK;"""
        self.query(prefix+'_identity_pipeline',sql)

    def fingerprint(self,prefix):
        parts=[]
        for table in TABLES:
            parts.append("SELECT "+sql_quote(table)+" AS table_name,count(*) AS rows,"
                         "md5(coalesce(string_agg(rowdata::text,E'\\n' ORDER BY rowdata::text),'')) AS fingerprint "
                         "FROM (SELECT to_jsonb(t)-'batch_id'-'first_seen_at'-'rejected_at' AS rowdata FROM dw."+table+" t) q")
        result=self.query(prefix+'_fingerprints',' UNION ALL '.join(parts)+' ORDER BY table_name;',csv_mode=True)
        (self.evidence/(prefix+'_fingerprints.csv')).write_text(result,encoding='utf-8')
        return result

    def build(self,number):
        prefix=f'run{number}'
        self.batch=self.evidence.name+f'_{number}'
        b=sql_quote(self.batch)
        self.query(prefix+'_batch_start',f"INSERT INTO audit.batch(batch_id,status) VALUES({b},'RUNNING');")
        source_files=sorted((ROOT.parent/'source_systems').glob('*.sql'))
        pipeline_files=sorted((ROOT/'pipeline').glob('*.sql'))
        for index,path in enumerate(source_files+pipeline_files,1):
            print(f'[{prefix} {index}/{len(source_files+pipeline_files)}] {path.name}',flush=True)
            output=self.query(prefix+'_'+path.stem,path.read_text(encoding='utf-8-sig'))
            if path.name=='09_source_validation.sql':
                if re.search(r'\|\s*FAIL\s*\|',output):
                    raise RuntimeError('Source validation scorecard contains FAIL')
                count=len(re.findall(r'\|\s*PASS\s*\|',output))
                if count != 89:
                    raise RuntimeError(f'Expected 89 source checks, got {count}')
        self.fixture_checks(prefix)
        first=self.fingerprint(prefix)
        self.identity_pipeline_test(prefix)
        if first!=self.fingerprint(prefix+'_after_identity'):
            raise RuntimeError('Identity pipeline test changed business data')
        # Run the production checks against corrupted data in a transaction.
        # ON_ERROR_STOP closes psql after the expected error; PostgreSQL rolls it back.
        checks=(ROOT/'pipeline/60_checks.sql').read_text(encoding='utf-8')
        self.query(prefix+'_negative_amount',
                   'BEGIN; UPDATE dw.fact_transaction SET amount_aud=amount_aud+1 '
                   'WHERE transaction_key=(SELECT min(transaction_key) FROM dw.fact_transaction);\n'+checks,
                   expect_failure=True)
        after=self.fingerprint(prefix+'_after_negative')
        if first!=after:
            raise RuntimeError('Negative test changed business data')
        self.query(prefix+'_batch_pass',f"UPDATE audit.batch SET status='PASS',finished_at=now() WHERE batch_id={b};")
        return first

    def export(self):
        from dashboard import render_dashboard
        out=self.evidence/'reports'; out.mkdir()
        for view in VIEWS:
            data=self.query('export_'+view,'SELECT * FROM dw.'+view+' ORDER BY 1;',csv_mode=True)
            (out/(view+'.csv')).write_text(data,encoding='utf-8-sig')
        page=render_dashboard(out,self.batch)
        (out/'dashboard.html').write_text(page,encoding='utf-8')
        site=ROOT/'site'; site.mkdir(exist_ok=True)
        for artifact in out.iterdir():
            shutil.copy2(artifact,site/artifact.name)
        (site/'index.html').write_text(page,encoding='utf-8')


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reset',action='store_true',help='Permit rebuilding learning source/staging/warehouse tables twice')
    parser.add_argument('--compose',type=Path,default=Path('/workspace/delivery/config/docker-compose.yml'),help='Recorded Compose configuration (runner uses PGHOST within the lab)')
    args=parser.parse_args(argv)
    if not args.reset:
        parser.error('Use --reset to allow project table rebuilds in your isolated learning environment.')
    compose=args.compose.resolve()
    if not compose.exists():
        parser.error('Compose file missing')
    evidence=ROOT/'evidence'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
    evidence.mkdir(parents=True)
    pipeline=Pipeline(compose,evidence)
    status='FAIL';reason='';audit_ready=False;lock=None
    try:
        import psycopg2
        lock=psycopg2.connect('')
        lock.autocommit=True
        with lock.cursor() as cur:
            cur.execute('SELECT pg_try_advisory_lock(32113002)')
            if not cur.fetchone()[0]:
                raise RuntimeError('Another delivery rebuild is running; wait for it to finish.')
        ready=subprocess.run(pipeline.docker('exec','-T','postgres','pg_isready','-U','student','-d','lab'),
                             capture_output=True,text=True,timeout=30)
        if ready.returncode:
            raise RuntimeError('PostgreSQL not ready. Start Docker Desktop, then docker compose up -d --build.')
        pipeline.query('00_audit_setup','''CREATE SCHEMA IF NOT EXISTS audit;
CREATE TABLE IF NOT EXISTS audit.batch(batch_id text PRIMARY KEY,started_at timestamptz DEFAULT now(),finished_at timestamptz,status text,error text);
CREATE TABLE IF NOT EXISTS audit.step_counts(batch_id text REFERENCES audit.batch,step text,source_count bigint,loaded_count bigint,rejected_count bigint,excluded_count bigint);''')
        audit_ready=True
        first=pipeline.build(1)
        second=pipeline.build(2)
        if first!=second:
            raise RuntimeError('Two full builds have different fingerprints')
        pipeline.export()
        status='PASS'
    except Exception as exc:
        reason=str(exc)
        if audit_ready and pipeline.batch:
            try:
                pipeline.query('failure_audit',"UPDATE audit.batch SET status='FAIL',finished_at=now(),error="+
                               sql_quote(reason)+" WHERE batch_id="+sql_quote(pipeline.batch)+';')
            except Exception:
                pass
    if lock is not None:
        lock.close()
    inputs=[p for folder in [ROOT/'pipeline',ROOT.parent/'source_systems',ROOT/'queries',ROOT/'config'] for p in folder.rglob('*') if p.is_file()]+list(ROOT.glob('*.py'))
    manifest={str(p.relative_to(ROOT.parent)) if p.is_relative_to(ROOT.parent) else str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    summary={'status':status,'reason':reason,'scope':'Course lab container integrated full source fixture pipeline',
             'identity_branch_baseline':'9b25245',
             'main_baseline':'e8bc152e8c14724fd272921430e42e96bb4e364b',
             'effective_compose':str(compose),'input_sha256':manifest,'steps':pipeline.steps}
    (evidence/'SUMMARY.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    (evidence/'SUMMARY.md').write_text('# Delivery integration result\n\n'+status+'\n\n'+
        (reason or 'Two complete builds matched. Source checks, expected identity fixtures, executable assertions, identity examples and rollback failure test passed.')+
        '\n\nThis is a locally tested delivery candidate based on main e8bc152 and identity branch 9b25245. Full service/UI evidence is recorded separately. No video, signatures or upstream publication is implied.\n',encoding='utf-8')
    (ROOT/'LATEST_EVIDENCE.txt').write_text(str(evidence.relative_to(ROOT)),encoding='utf-8')
    print(status+': '+str(evidence))
    if reason: print(reason,file=sys.stderr)
    return 0 if status=='PASS' else 1

if __name__=='__main__':
    sys.exit(main())
