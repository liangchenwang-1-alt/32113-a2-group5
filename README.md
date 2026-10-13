# 32113 A2 Group 5 runnable candidate

Start with DEMO_GUIDE.html (Chinese step-by-step presentation guide).
Open PowerShell in this directory, with Docker Desktop running:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\DEMO.ps1 -Mode Build
```

This rebuilds the project sample tables twice, validates them and displays presentation queries. Stop if any command fails. To inspect existing data with services running, use -Mode Show.

CloudBeaver: http://localhost:8979/ ; dashboard: http://localhost:8089/
CloudBeaver database connection: postgres:5432, database lab, student/student.
The administrator password is separate and set by each user.

## Files to learn

- lab-env/advanced-database-lab/docker-compose.yml and python/: course environment.
- workspace/source_systems/: unchanged upstream full source SQL and expected results.
- workspace/delivery/run_all.py: integrated build and verification entry.
- workspace/delivery/pipeline/: eight effective warehouse, identity, ETL and test SQL files.
- workspace/delivery/queries/: read-only queries, including demo.sql.
- workspace/delivery/docs/: effective technical definitions and handover documents.
- workspace/delivery/evidence/: latest verified full run; read LATEST_EVIDENCE.txt.
- workspace/delivery/site/: generated report snapshot and CSVs.

All workspace paths above are within lab-env/advanced-database-lab.
This package is based on main e8bc152 and identity branch 9b25245. New integration decisions require module-owner review. No GitHub push or assessed report is included. Real video, presentation, contribution records and signed meeting minutes remain team deliverables. Three sources are represented by three PostgreSQL schemas; confirm that interpretation with the tutor.
