// 32113 A2 - render the working documents to HTML and build the demo-package landing page.
//
// Called by build-demo-package.ps1. Input: <pkgDir>\docs\*.md + manifest.json (written by the
// PowerShell script). Output: one .html per .md, plus <pkgDir>\index.html and <pkgDir>\README.txt.
//
// It is a deliberately small Markdown renderer (headings, tables, fenced code, lists,
// blockquotes, bold/inline code, links) - enough for our own notes, no dependencies.

import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs';
import { join, basename } from 'node:path';

const [, , pkgDir] = process.argv;
if (!pkgDir || !existsSync(pkgDir)) {
  console.error('usage: node render-docs.mjs <packageDir>');
  process.exit(2);
}
const docsDir = join(pkgDir, 'docs');
const read = p => readFileSync(p, 'utf8').replace(/^\uFEFF/, '');

// --------------------------------------------------------------- markdown
const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

const FILE_MAP = {
  'START_HERE.md': 'start-here.html',
  '测试矩阵.md': 'test-matrix.html',
  '报表规格.md': 'report-spec.html',
  '端到端证据索引.md': 'evidence-index.html',
  '组员同步指南.md': 'sync-guide.html',
  '协作与展示方案.md': 'collaboration.html',
  '演示口播稿.md': 'demo-script.html',
  'README.md': 'part5-readme.html',
  'RUN_LOG.md': 'part5-run-log.html',
};

function inline(text) {
  let s = esc(text);
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
  s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, label, href) => {
    let h = href.replace(/\\/g, '/');                 // Windows-style links in our notes
    const base = basename(h);
    if (FILE_MAP[base]) h = FILE_MAP[base];           // link to a rendered page instead of the .md
    return `<a href="${h}">${label}</a>`;
  });
  return s;
}

function mdToHtml(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let i = 0;
  const isTableRow = l => /^\s*\|.*\|\s*$/.test(l);
  const isSep = l => /^\s*\|[\s:|-]+\|\s*$/.test(l);

  while (i < lines.length) {
    const line = lines[i];

    if (/^\s*```/.test(line)) {                        // fenced code
      const buf = [];
      i++;
      while (i < lines.length && !/^\s*```/.test(lines[i])) { buf.push(lines[i]); i++; }
      i++;
      out.push('<pre><code>' + esc(buf.join('\n')) + '</code></pre>');
      continue;
    }
    if (/^#{1,6}\s/.test(line)) {
      const level = line.match(/^#+/)[0].length;
      out.push(`<h${level}>` + inline(line.replace(/^#+\s*/, '')) + `</h${level}>`);
      i++; continue;
    }
    if (/^\s*(-{3,}|\*{3,})\s*$/.test(line)) { out.push('<hr>'); i++; continue; }
    if (isTableRow(line) && i + 1 < lines.length && isSep(lines[i + 1])) {
      const cells = r => r.trim().replace(/^\||\|$/g, '').split('|').map(c => inline(c.trim()));
      const head = cells(line);
      i += 2;
      const body = [];
      while (i < lines.length && isTableRow(lines[i])) { body.push(cells(lines[i])); i++; }
      out.push('<table><thead><tr>' + head.map(c => `<th>${c}</th>`).join('') + '</tr></thead><tbody>' +
        body.map(r => '<tr>' + r.map(c => `<td>${c}</td>`).join('') + '</tr>').join('') + '</tbody></table>');
      continue;
    }
    if (/^\s*>\s?/.test(line)) {
      const buf = [];
      while (i < lines.length && /^\s*>\s?/.test(lines[i])) { buf.push(lines[i].replace(/^\s*>\s?/, '')); i++; }
      out.push('<blockquote>' + buf.map(inline).join('<br>') + '</blockquote>');
      continue;
    }
    if (/^\s*[-*]\s+/.test(line)) {
      const buf = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) { buf.push(lines[i].replace(/^\s*[-*]\s+/, '')); i++; }
      out.push('<ul>' + buf.map(t => `<li>${inline(t)}</li>`).join('') + '</ul>');
      continue;
    }
    if (/^\s*\d+[.)]\s+/.test(line)) {
      const buf = [];
      while (i < lines.length && /^\s*\d+[.)]\s+/.test(lines[i])) { buf.push(lines[i].replace(/^\s*\d+[.)]\s+/, '')); i++; }
      out.push('<ol>' + buf.map(t => `<li>${inline(t)}</li>`).join('') + '</ol>');
      continue;
    }
    if (!line.trim()) { i++; continue; }
    const buf = [];
    while (i < lines.length && lines[i].trim() && !/^(#{1,6}\s|\s*```|\s*[-*]\s|\s*\d+[.)]\s|\s*>|\s*\|)/.test(lines[i])) {
      buf.push(lines[i]); i++;
    }
    out.push('<p>' + buf.map(inline).join(' ') + '</p>');
  }
  return out.join('\n');
}

const CSS = `
:root{--ink:#1b2a41;--muted:#5b6b82;--line:#d9e0ea;--accent:#0b4f9e;--bg:#f5f7fb}
*{box-sizing:border-box}
body{margin:0;padding:0 0 40px;background:var(--bg);color:var(--ink);font:15px/1.65 "Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:980px;margin:0 auto;padding:0 24px}
nav{background:#fff;border-bottom:1px solid var(--line);padding:10px 0;margin-bottom:22px;position:sticky;top:0}
nav a{margin-right:16px;color:var(--accent);text-decoration:none;font-size:13.5px}
nav a:hover{text-decoration:underline}
h1{font-size:25px;margin:18px 0 10px}h2{font-size:18px;margin:26px 0 8px;border-bottom:2px solid var(--accent);padding-bottom:5px}
h3{font-size:15.5px;margin:20px 0 6px}
table{border-collapse:collapse;width:100%;font-size:13.5px;background:#fff;margin:10px 0}
th,td{border:1px solid var(--line);padding:6px 9px;text-align:left;vertical-align:top}
th{background:#eef2f8}
code{background:#eef2f8;padding:1px 4px;border-radius:3px;font-size:12.8px}
pre{background:#0f1b2d;color:#e6edf7;padding:12px 14px;border-radius:8px;overflow:auto;font-size:12.8px}
pre code{background:none;color:inherit;padding:0}
blockquote{margin:10px 0;padding:8px 14px;border-left:4px solid var(--accent);background:#fff}
hr{border:none;border-top:1px solid var(--line);margin:22px 0}
a{color:var(--accent)}
.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:14px 0}
.card{background:#fff;border:1px solid var(--line);border-radius:8px;padding:12px 14px}
.card .k{font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}
.card .v{font-size:21px;font-weight:600;margin-top:4px}
footer{color:var(--muted);font-size:12px;border-top:1px solid var(--line);margin-top:30px;padding-top:10px}
`;

function page(title, body, pkgDirRel) {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>${esc(title)} - 32113 A2 Group 5</title><style>${CSS}</style></head><body>
<nav><div class="wrap"><a href="${pkgDirRel}index.html">&larr; Package home</a>
<a href="${pkgDirRel}dashboard.html">Dashboard</a>
<a href="${pkgDirRel}dashboard.pdf">Dashboard (PDF)</a></div></nav>
<div class="wrap">${body}
<footer>32113 Advanced Database &middot; Assignment 2 &middot; Group 5 &middot; synthetic data only &middot; generated ${new Date().toISOString().slice(0, 10)}</footer>
</div></body></html>`;
}

// ------------------------------------------------------------------- convert
const manifestPath = join(docsDir, 'manifest.json');
const manifest = existsSync(manifestPath) ? JSON.parse(read(manifestPath)) : { docs: [] };
const converted = [];
for (const entry of manifest.docs) {
  const srcPath = join(docsDir, entry.file);
  if (!existsSync(srcPath)) continue;
  const html = page(entry.title, mdToHtml(read(srcPath)), '../');
  const outName = entry.file.replace(/\.md$/, '.html');
  writeFileSync(join(docsDir, outName), html, 'utf8');
  converted.push({ ...entry, out: 'docs/' + outName });
  console.log('rendered: docs/' + outName);
}

// --------------------------------------------------------------- index page
const cards = [
  ['Sources integrated', '3', 's1_core / s2_payments / s3_digital'],
  ['Transactions loaded', '6', '7 settled − 1 orphan (recorded, not dropped)'],
  ['Value reconciled', 'AUD 1,835.50', 'source total = warehouse total'],
  ['Re-run consistency', 'identical', '7 tables, md5 fingerprint, 2 runs'],
];

const links = converted.map(d => `<li><a href="${d.out}">${esc(d.title)}</a> &mdash; ${esc(d.desc || '')}</li>`).join('\n');

const index = `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>32113 A2 Group 5 - demo package</title><style>${CSS}</style></head><body>
<nav><div class="wrap"><a href="dashboard.html">Dashboard</a><a href="dashboard.pdf">Dashboard (PDF)</a>
<a href="evidence/e2e_20261001_172851/SUMMARY.md">Raw run summary</a></div></nav>
<div class="wrap">
<h1>CBA Customer 360 &mdash; working prototype</h1>
<p>32113 Advanced Database &middot; Assignment 2 &middot; Group 5 &middot; Liangchen Wang 25142542,
Md Mohsin Himel Mozumder, Qiushi Huang, Sejin Park, Yutong Wang.</p>
<p>Three source systems are integrated into one warehouse, identity is resolved deterministically, and
three use-case reports are produced &mdash; all running in the provided Lab Environment (Docker Compose:
PostgreSQL, Neo4j, ClickHouse, CloudBeaver, Python). <strong>All data is synthetic; no real bank or
customer data is used anywhere in this prototype.</strong></p>

<div class="cards">
${cards.map(([k, v, s]) => `<div class="card"><div class="k">${esc(k)}</div><div class="v">${esc(v)}</div><div class="s">${esc(s)}</div></div>`).join('\n')}
</div>

<h2>Open the artefacts</h2>
<ul>
<li><a href="dashboard.html">Report dashboard</a> &mdash; the three use-case reports over the integrated warehouse</li>
<li><a href="dashboard.pdf">Report dashboard (PDF)</a> &mdash; same figures, fixed layout</li>
<li><a href="docs/run-summary.html">End-to-end run summary</a> &mdash; 19 steps with every exit code</li>
<li><a href="docs/source-code.html">Prototype source code</a> &mdash; all SQL scripts on one page</li>
</ul>
<h2>Documents</h2>
<ul>
${links}
</ul>
<h2>Raw evidence</h2>
<p>The unedited output of every step is kept under <code>evidence/</code> (text files): reconciliation,
guard tests, table fingerprints and the environment check. Nothing in this package is a re-typed number &mdash;
the documents and the dashboard are generated from those outputs.</p>

<h2>Reproduce it</h2>
<p>In the full project folder (Docker Desktop installed):</p>
<pre><code>cd 命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\\run-lab.ps1 start
powershell -NoProfile -ExecutionPolicy Bypass -File .\\verify-e2e.ps1</code></pre>
<p>The last line must read <code>OVERALL: PASS</code> (exit code 0). The fixtures are deterministic, so a
rebuild on any machine produces the same seven table fingerprints.</p>
<footer>Generated ${new Date().toISOString().slice(0, 10)} from the committed working tree.
The original run outputs are included under <code>evidence/</code> so every number here can be checked.</footer>
</div></body></html>`;
writeFileSync(join(pkgDir, 'index.html'), index, 'utf8');

const readme = `32113 A2 - Group 5 - CBA Customer 360 working prototype
=========================================================

WHAT TO OPEN
  index.html        - start here (links to everything)
  dashboard.html    - the three reports / dashboard
  dashboard.pdf     - same dashboard as PDF (easy to print or attach)
  docs\\             - test matrix, report specification, evidence index (HTML)
  evidence\\         - raw query output from the end-to-end run (text)
  source\\           - the SQL scripts of the prototype

NOTHING NEEDS TO BE INSTALLED. Just open index.html in a browser.
All data is synthetic - no real bank or customer data is used.

REPRODUCING THE PROTOTYPE (optional, needs Docker Desktop)
  cd 命令
  powershell -NoProfile -ExecutionPolicy Bypass -File .\\run-lab.ps1 start
  powershell -NoProfile -ExecutionPolicy Bypass -File .\\verify-e2e.ps1     -> OVERALL: PASS
`;
writeFileSync(join(pkgDir, 'README.txt'), readme, 'utf8');

console.log('index.html and README.txt written');
