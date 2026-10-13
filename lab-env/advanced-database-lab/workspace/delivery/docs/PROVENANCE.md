# Simplified delivery provenance

Prepared for Liangchen Wang, Member 1, on 12 October 2026.
GitHub baseline: main e8bc152e8c14724fd272921430e42e96bb4e364b and identity branch 9b252452f84b60d8c2739a36a015d298178134aa. No new remote synchronization or push is implied.

source_systems remains the upstream full source package. The effective pipeline in delivery adapts the former small-fixture model to this full source package. Identity safeguards and module decisions require owner review; see IDENTITY_RULES.md and HANDOFF.md.

This package keeps the source SQL, effective pipeline, documentation and verification evidence needed to understand and run the prototype. Temporary Python bytecode and read-only inspection-output folders are excluded; full-run evidence is retained.

The latest full run in this package is evidence/20261012T210650_069077Z: two complete builds PASS, identical business-table fingerprints, source checks, expected identity checks, T9-T13, identity boundary tests and negative amount test with rollback. The earlier evidence/20261012T122007_672614Z also contains the manual read-only query validation. LATEST_EVIDENCE.txt is the source of truth after future runs.

The package contains historical evidence that the DEMO.ps1 Build workflow reached DEMO READY. The 9 SQL blocks in DEMO_GUIDE were independently executed read-only; the results are preserved in DEMO_GUIDE_QUERY_CHECK.json in the earlier evidence batch. Environment/UI evidence at the evidence root is historical and separately dated, not a claim that the browser was retested during this cleanup.

The ZIP excludes Docker volumes, administrator credentials, images and Git history. Five course services are preserved. The technical prototype does not replace the assessed report, real recording, presentation, signed minutes or actual contribution evidence.
