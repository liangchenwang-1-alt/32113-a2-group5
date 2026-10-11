# Integration and release checklist

Coordinator: Liangchen Wang (Member 1), 25142542

These are outstanding tasks and acceptance conditions, not claims of completed work.

| Priority | Owner and handoff | Acceptance evidence |
|---|---|---|
| 1 | Liangchen + Qiushi + Sejin + Yutong: freeze source contract | Table/column mapping, identity formats, event dates, grain and rejection policy agreed in repository |
| 1 | Sejin + Yutong: load account dimensions before transaction facts | Valid source account references have matching non-null warehouse account keys |
| 1 | Sejin: align date dimension to selected source data | Every required event date is represented; no inner-join row loss |
| 1 | Sejin: update branch from main and open PR | Reviewable DATA_MODEL and identity changes; resolve merge conflicts if any |
| 1 | Sejin: supply rule evidence | Resolved counts by R1/R2/R3, unmatched and ambiguous counts, rationale and source-to-target mapping |
| 2 | Sejin to Yutong and Mohsin: freeze warehouse contract | Dimension keys and report schema acknowledged; reports query dw only |
| 2 | Liangchen: run independent acceptance twice | Full logs, hashes, actual assertion results and matching business fingerprints |
| 2 | Mohsin + module owners: check reports and record demo | Expected fixture outputs, screenshots and accessible demo link |
| 2 | Liangchen: update architecture and documentation | Diagram, execution steps and requirement links match merged implementation |
| 3 | All; Liangchen coordinates: finish official materials | Independently authored report sections, actual contribution records and required signed minutes |

## Integration issues to resolve explicitly

- Old `customers/accounts/payers/digital_users` tables differ from the new
  `customer/account/payment_customer/digital_customer` contract. Choose an adapter
  or update downstream SQL; do not assume placing files together connects them.
- New event data uses January-March 2026; current date dimension uses August 2026.
- Current source root README still describes the package as Snowflake, while its
  own README and current SQL describe PostgreSQL. Correct the root description.
- The current reconciliation T2 includes some unfiltered LEFT JOIN counts; those
  are row totals, not orphan counts. Correct the checks with the ETL owner.
- R3_NAME_EMAIL is a proposed branch change, not part of the reviewed main baseline.
  Do not reuse old matching counts or fingerprints after merging it.
- Update null/reject policies before adapting acceptance checks to the new dataset.
  Current activity/case count assertions assume no rejected activity/case rows.

## Final delivery checks

- Confirm the actual Canvas deadline, submission link, naming and presentation date.
  The planning document states 16 October 2026 at 11:59 pm, with a timezone ambiguity;
  this package does not independently confirm that deadline.
- Ensure sections 2.2 and 2.3 reflect Sejin's final model and assessed authorship.
- Test the demo link using a viewer without owner privileges.
- Collect the required official contribution forms and teacher-signed minutes.
- Check names against the official student list; use Sejin Park for Member 3.
- Retain the final submission receipt. Do not mark these items complete without evidence.

## Personal contribution record

Record your actual work using: date, task, artifact/commit, result, reviewer and
evidence path. Do not backfill unperformed database runs, signatures or approvals.
