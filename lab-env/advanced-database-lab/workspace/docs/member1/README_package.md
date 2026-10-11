# Member 1 integration and architecture package

Owner: Liangchen Wang  
Student ID: 25142542  
Subject: 32113 Advanced Database, Assignment 2, Group 5  
Prepared: 12 October 2026 (Sydney date)

This package contains Member 1's revised architecture notes, requirement checklist,
integration runner and release checklist. It is an overlay for the existing group
repository, not a standalone copy of the database project. Student ID is taken from
the repository README and should be checked against the official contribution form.

Baseline reviewed: `f11cbc08de6ff9ab59c23af77491fd30aab789be` on `main`.
Repository: https://github.com/liangchenwang-1-alt/32113-a2-group5

## Current status

Member 1 materials have been revised. No database acceptance run was performed when
preparing this package. Do not cite this revision as a successful clean build.
The current main branch has a small-fixture pipeline and a separate, larger source
package. Their integration remains open. The new runner intentionally detects the
existing transaction-to-account linkage defect rather than reporting a false PASS.

## Files and placement

| Package file | Suggested repository destination |
|---|---|
| `code/run_all.py` and `code/acceptance_checks.sql` | `lab-env/advanced-database-lab/workspace/integration/` |
| `docs/*.md` | `lab-env/advanced-database-lab/workspace/docs/member1/` |
| `figures/architecture.svg` | `lab-env/advanced-database-lab/workspace/figures/` |
| `2.1_Solution_Architecture.md` | Architecture working notes for the report owner |
| `tests/test_runner.py` | Member 1 runner verification; run before handoff |

Keep the two files in `code/` together. The runner executes on the host, using the
existing PostgreSQL container through Docker Compose. It requires Python 3.9+ and
does not need psycopg2 on the host. Read `docs/RUN_AND_BATCH.md` before execution.

The supplied plan says assessed report prose must be independently written under
course rules. Architecture notes here are a technical working reference; verify
the actual brief and write the assessed explanation in your own words.
