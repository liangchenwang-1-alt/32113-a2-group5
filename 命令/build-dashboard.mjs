// 32113 A2 - build a self-contained HTML dashboard from REAL query output.
//
// The CSV files it reads are exported straight from the warehouse views by
// export-dashboard.ps1 (psql --csv). Nothing in here invents a number: the HTML shows
// exactly what the database returned, and the generation timestamp + source commands
// are printed in the footer so anyone can reproduce it.
//
// Usage: node build-dashboard.mjs <dataDir> <outHtmlFile>

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const [, , dataDir, outFile] = process.argv;
if (!dataDir || !outFile) {
  console.error('usage: node build-dashboard.mjs <dataDir> <outHtmlFile>');
  process.exit(2);
}

// ------------------------------------------------------------------ csv parsing
function parseCsv(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  const src = text.replace(/\r\n/g, '\n');
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"') {
        if (src[i + 1] === '"') { field += '"'; i++; } else { quoted = false; }
      } else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(field); field = ''; }
    else if (ch === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else field += ch;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  const clean = rows.filter(r => r.length && !(r.length === 1 && r[0].trim() === ''));
  if (!clean.length) return { columns: [], rows: [] };
  const columns = clean[0].map(c => c.trim());
  const data = clean.slice(1).map(r => {
    const o = {};
    columns.forEach((c, i) => { o[c] = (r[i] ?? '').trim(); });
    return o;
  });
  return { columns, rows: data };
}

function readTable(name) {
  const p = join(dataDir, name + '.csv');
  if (!existsSync(p)) return { columns: [], rows: [], missing: true };
  // Windows PowerShell 5.1 writes UTF-8 with a BOM; strip it so the first column name
  // is 'customer_key' and not '\uFEFFcustomer_key'.
  const text = readFileSync(p, 'utf8').replace(/^\uFEFF/, '');
  return parseCsv(text);
}

const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const num = v => { const n = Number(String(v).replace(/[^0-9.\-]/g, '')); return Number.isFinite(n) ? n : 0; };
const money = v => num(v).toLocaleString('en-AU', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// ------------------------------------------------------------------- rendering
function table(t, opts = {}) {
  if (t.missing) return '<p class="missing">data file missing – run export-dashboard.ps1</p>';
  const cols = t.columns;
  const numCols = opts.numCols || [];
  const heads = cols.map(c => `<th${numCols.includes(c) ? ' class="n"' : ''}>${esc(c.replace(/_/g, ' '))}</th>`).join('');
  const body = t.rows.map(r => '<tr>' + cols.map(c => {
    const raw = r[c] ?? '';
    const shown = (opts.money && opts.money.includes(c)) ? money(raw) : raw;
    return `<td${numCols.includes(c) ? ' class="n"' : ''}>${esc(shown)}</td>`;
  }).join('') + '</tr>').join('\n');
  return `<table><thead><tr>${heads}</tr></thead><tbody>${body}</tbody></table>`;
}

function bars(t, labelCol, valueCol, opts = {}) {
  if (t.missing || !t.rows.length) return '<p class="missing">no data</p>';
  const max = Math.max(...t.rows.map(r => num(r[valueCol])), 1);
  return '<div class="bars">' + t.rows.map(r => {
    const v = num(r[valueCol]);
    const pct = Math.max(1, Math.round((v / max) * 100));
    const shown = opts.money ? money(v) : v.toLocaleString('en-AU');
    return `<div class="bar"><span class="bl">${esc(r[labelCol])}</span>` +
      `<span class="bt"><i style="width:${pct}%"></i></span>` +
      `<span class="bv">${shown}${opts.suffix || ''}</span></div>`;
  }).join('\n') + '</div>';
}

const r1 = readTable('r1_customer_360');
const r2 = readTable('r2_transaction_by_date_channel');
const r2b = readTable('r2b_transaction_by_channel');
const r3 = readTable('r3_channel_engagement');
const r4 = readTable('r4_service_case_summary');
const r5 = readTable('r5_data_quality_kpi');
const r6 = readTable('r6_attribution_reconciliation');

const kpi = r5.rows[0] || {};
const kpiCards = [
  ['Customers (resolved)', kpi.dim_customer_rows, 'dw.dim_customer'],
  ['Accounts', kpi.dim_account_rows, 'dw.dim_account'],
  ['Transactions', kpi.transaction_rows, 'dw.fact_transaction'],
  ['Transaction value (AUD)', kpi.transaction_amount_aud ? money(kpi.transaction_amount_aud) : '', 'sum(amount_aud)'],
  ['Identity rows', kpi.xref_rows, 'dw.customer_xref'],
  ['Ambiguous identities', kpi.xref_ambiguous, 'match_status = ambiguous'],
  ['Unresolved transactions', kpi.transactions_unresolved, 'customer_key IS NULL'],
  ['Rejected records', kpi.rejected_rows, 'dw.rejected_record'],
];

const now = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CBA Customer 360 – Integrated Warehouse Dashboard</title>
<style>
  :root { --ink:#1b2a41; --muted:#5b6b82; --line:#d9e0ea; --accent:#0b4f9e; --bg:#f5f7fb; }
  * { box-sizing:border-box; }
  body { margin:0; padding:28px; background:var(--bg); color:var(--ink);
         font:14px/1.5 "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  h1 { font-size:24px; margin:0 0 4px; }
  h2 { font-size:16px; margin:28px 0 8px; padding-bottom:6px; border-bottom:2px solid var(--accent); }
  .sub { color:var(--muted); font-size:12.5px; margin-bottom:18px; }
  .cards { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; }
  .card { background:#fff; border:1px solid var(--line); border-radius:8px; padding:12px 14px; }
  .card .k { font-size:11px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); }
  .card .v { font-size:22px; font-weight:600; margin-top:4px; }
  .card .s { font-size:11px; color:var(--muted); margin-top:2px; }
  .panel { background:#fff; border:1px solid var(--line); border-radius:8px; padding:14px 16px; }
  table { border-collapse:collapse; width:100%; font-size:13px; }
  th, td { border-bottom:1px solid var(--line); padding:6px 8px; text-align:left; }
  th { background:#eef2f8; font-weight:600; }
  td.n, th.n { text-align:right; font-variant-numeric:tabular-nums; }
  .bars { display:flex; flex-direction:column; gap:6px; }
  .bar { display:grid; grid-template-columns:190px 1fr 120px; align-items:center; gap:10px; font-size:13px; }
  .bt { background:#e8edf5; border-radius:4px; height:14px; display:block; overflow:hidden; }
  .bt i { display:block; height:100%; background:var(--accent); }
  .bv { text-align:right; font-variant-numeric:tabular-nums; }
  .missing { color:#b3261e; font-style:italic; }
  footer { margin-top:28px; color:var(--muted); font-size:11.5px; border-top:1px solid var(--line); padding-top:10px; }
  code { background:#eef2f8; padding:1px 4px; border-radius:3px; }
</style>
</head>
<body>
  <h1>CBA Customer 360 – Integrated Warehouse Dashboard</h1>
  <div class="sub">32113 Advanced Database · Assignment 2 · Group 5 · synthetic data only (no real customer data) ·
    generated from live query output at ${esc(now)}</div>

  <h2>Data-quality scorecard (dw.v_r5_data_quality_kpi)</h2>
  <div class="cards">
    ${kpiCards.map(([k, v, s]) => `<div class="card"><div class="k">${esc(k)}</div><div class="v">${esc(v ?? '')}</div><div class="s">${esc(s)}</div></div>`).join('\n    ')}
  </div>

  <h2>R1 · Customer 360 (dw.v_r1_customer_360)</h2>
  <div class="panel">
    ${table(r1, { numCols: ['accounts', 'transactions', 'amount_aud', 'digital_activities', 'service_cases', 'open_cases'], money: ['amount_aud'] })}
    <div class="sub" style="margin:10px 0 0">Amounts are per resolved customer. Rows whose identity could not be resolved are
    not guessed onto a customer – see the reconciliation panel (R6) below.</div>
  </div>

  <h2>R2b · Transaction value by channel (dw.v_r2b_transaction_by_channel)</h2>
  <div class="panel">
    ${bars(r2b, 'channel_name', 'amount_aud', { money: true, suffix: ' AUD' })}
    <div style="margin-top:12px">${table(r2b, { numCols: ['txn_count', 'amount_aud'], money: ['amount_aud'] })}</div>
  </div>

  <h2>R2 · Transactions by date and channel (dw.v_r2_transaction_by_date_channel)</h2>
  <div class="panel">${table(r2, { numCols: ['txn_count', 'amount_aud'], money: ['amount_aud'] })}</div>

  <h2>R3 · Channel engagement (dw.v_r3_channel_engagement)</h2>
  <div class="panel">
    ${bars(r3, 'channel_name', 'activity_count')}
    <div style="margin-top:12px">${table(r3, { numCols: ['active_customers', 'activity_count'] })}</div>
    <div class="sub" style="margin:10px 0 0">Digital activity is genuinely channel-attributed in the source.
    Service cases are <strong>not</strong> shown per channel: the source carries no channel for a case, so a
    per-channel case figure would be a fabricated attribution (guard test T10).</div>
  </div>

  <h2>R4 · Service cases by status (dw.v_r4_service_case_summary)</h2>
  <div class="panel">${table(r4, { numCols: ['case_count', 'customers', 'high_severity'] })}</div>

  <h2>R6 · Attribution reconciliation (dw.v_r6_attribution_reconciliation)</h2>
  <div class="panel">
    ${table(r6, { numCols: ['total_rows', 'attributed_rows', 'unattributed_rows', 'total_amount_aud', 'attributed_amount_aud', 'unattributed_amount_aud'], money: ['total_amount_aud', 'attributed_amount_aud', 'unattributed_amount_aud'] })}
    <div class="sub" style="margin:10px 0 0">Proves nothing is lost: attributed + unattributed equals the warehouse total
    (test T13). Unattributed rows are customers/payers whose identity could not be resolved deterministically.</div>
  </div>

  <footer>
    Generated by <code>命令\\export-dashboard.ps1</code> → <code>node build-dashboard.mjs</code> from CSV exported with
    <code>psql --csv</code> against the official Lab Environment (<code>student-postgres</code>, database <code>lab</code>).
    Every figure above is a direct copy of a query result; regenerate the prototype to reproduce.
    Data is deterministic synthetic fixture data – no real CommBank data was used.
  </footer>
</body>
</html>
`;

writeFileSync(outFile, html, 'utf8');
console.log('dashboard written: ' + outFile);
console.log('rows: R1=' + r1.rows.length + ' R2=' + r2.rows.length + ' R2b=' + r2b.rows.length +
            ' R3=' + r3.rows.length + ' R4=' + r4.rows.length + ' R6=' + r6.rows.length);
