# Executed test matrix

| Test | Method | Expected evidence |
|---|---|---|
| Source fixture validity | Original 09_source_validation.sql, result parsing | 89 PASS rows, no FAIL |
| Identity coverage | All rows from expected_results.csv expanded across sources | 577 source identities with correct status and core ID |
| R3 positive | Missing DOB plus unique normalised name/email | Match under R3_NAME_EMAIL |
| Name-only negative | Name supplied with no contact | No customer key |
| DOB conflict | Different known DOB with same name/email | No customer key |
| Ambiguous pair | Two test core people share name/email | Ambiguous with NULL key |
| Phone normalisation | DOB plus +61 formatted phone | R2_DOB_CONTACT match |
| Fact classification | Counts and known bad-row fixtures | 1807/3/192 transactions; 999/1 activity; 99/1 cases |
| Key integrity | Explicit missing-key checks and PostgreSQL FK constraints | No missing valid keys |
| Business duplicate | T000100 vs T002001 | One retained reference; T002001 rejected |
| Report totals | R1/R2 sums, R3 activity counts, R4 case counts | Equal warehouse facts |
| Unsupported attribution | Inspect report columns | No case metric assigned to channel |
| Failure detection | Add AUD 1 inside uncommitted transaction | Amount assertion fails for the expected reason |
| Failure recovery | Compare fingerprints before/after failed transaction | Identical; corruption rolled back |
| Repeatability | Two complete source-to-report builds | Nine table fingerprints identical |
| Export | CSV and HTML generated from verified dw views | Batch-labelled snapshot from final run |

The Python runner invokes these database checks; this matrix does not assert that every
possible banking or production data-quality scenario is covered. Missing-DOB R3 cases
are synthetic test-only rows, because the supplied customer source DDL requires DOB.

## Additional executed delivery checks

The runner executes the production identity load against temporary staged boundary records inside a rolled-back transaction, including duplicate source name/email pairs and conflicting known DOB. Before/after fingerprints verify rollback. MANUAL_QUERY_CHECK.json contains 12 successful read-only manual SQL blocks.
