# Source systems package

This package builds three fictional banking source systems for the CommBank Customer 360 prototype in 32113 Advanced Database, Assignment 2. It creates three schemas in the Lab Environment PostgreSQL database, loads deterministic synthetic data, plants controlled data-quality problems, and validates the result.

It does not build the warehouse, `customer_xref`, or the reports. Those belong to the downstream team.

Owner: Qiushi Huang.

All people, accounts, transactions, and product names are synthetic. This is not Commonwealth Bank's real architecture, and these tables must not be loaded with real customer data.

## Project context

The wider prototype integrates customer records from three internal platforms into a Customer 360 warehouse, then supports three analytical outputs:

1. Customer 360
2. Transaction Analysis
3. Channel and Service Engagement

This package is only the source-system and synthetic-data component. The three schemas stay independent. There are no foreign keys between them. The same person uses a different id in each system, for example `C0001`, `P1001`, and `D1001`.

## Source systems

| System | Database | Schema | Tables | Grain |
|---|---|---|---|---|
| Core Banking | `lab` | `s1_core` | `customer`, `account`, `customer_account` | One customer, one account, or one ownership |
| Payments | `lab` | `s2_payments` | `payment_customer`, `transaction` | One payment profile, or one payment transaction |
| Digital and Service | `lab` | `s3_digital` | `digital_customer`, `activity`, `service_case` | One digital profile, one activity event, or one service case |

`customer_account` is an enforced relationship inside Core Banking. Each account has one `PRIMARY` owner. Payments `account_id` uses the core id format so it can be integrated later. It is not a foreign key.

PostgreSQL folds unquoted identifiers to lower case. Primary keys are enforced. Foreign keys are enforced only inside `s1_core.customer_account`. Orphan references such as `A99999`, `P0000`, and `D0000` are intentionally not foreign keys, because a foreign key would reject those fixture rows. `09_source_validation.sql` checks the remaining rules.

The logical model is in `source_er_diagram.md`. Column definitions are in `source_field_dictionary.csv`.

## File execution order

Run this from `lab-env/advanced-database-lab`, after `docker compose up -d`. These scripts use database `lab`. They do not create a database and they do not drop the warehouse prototype tables (`s1_core.customers`, `s2_payments.payers`, and the other tables already used by the 11-step run).

```powershell
$files = @(
  'workspace/source_systems/01_create_source_databases.sql',
  'workspace/source_systems/02_create_core_banking.sql',
  'workspace/source_systems/03_create_payments.sql',
  'workspace/source_systems/04_create_digital_service.sql',
  'workspace/source_systems/05_generate_core_data.sql',
  'workspace/source_systems/06_generate_payment_data.sql',
  'workspace/source_systems/07_generate_digital_data.sql',
  'workspace/source_systems/08_insert_edge_cases.sql',
  'workspace/source_systems/09_source_validation.sql'
)
foreach ($f in $files) {
  Get-Content $f -Raw | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab
  Write-Host ("exit={0}  {1}" -f $LASTEXITCODE, $f)
}
```

```text
1. 01_create_source_databases.sql
2. 02_create_core_banking.sql
3. 03_create_payments.sql
4. 04_create_digital_service.sql
5. 05_generate_core_data.sql
6. 06_generate_payment_data.sql
7. 07_generate_digital_data.sql
8. 08_insert_edge_cases.sql
9. 09_source_validation.sql
```

A full rebuild is the same sequence. `02` to `04` replace the tables. `05` to `07` truncate and reload. `08` deletes its own inserted fixture rows before inserting them again, so it can be re-run after `05` to `07`. `09` is read-only.

Do not run `08` before `05` to `07`. The edge-case script updates rows that the generators create.

The database role needs permission to create schemas and tables, and to insert, update, delete, and select in those schemas. `student` in the lab image can do this.

## Data volumes

Counts below are the final counts after `08_insert_edge_cases.sql`. `09_source_validation.sql` expects these exact numbers.

| Table | Rows | Notes |
|---|---:|---|
| `s1_core.customer` | 200 | `C0001` to `C0200` |
| `s1_core.account` | 300 | `A00001` to `A00300` |
| `s1_core.customer_account` | 300 | One owner row per account |
| `s2_payments.payment_customer` | 191 | 189 overlapping core customers, plus `P8888` and `P9999` |
| `s2_payments.transaction` | 2,002 | 2,000 clean rows, plus `T002001` and `T002002` |
| `s3_digital.digital_customer` | 186 | Overlapping core customers only |
| `s3_digital.activity` | 1,000 | `ACT000001` to `ACT001000` |
| `s3_digital.service_case` | 100 | `SC00001` to `SC00100` |

Account numbering:

- `A00001` to `A00100` are the first account of `C0001` to `C0100`.
- `A00101` to `A00200` are the second account of `C0001` to `C0100`.
- `A00201` to `A00300` are the only account of `C0101` to `C0200`.
- Account number `k` belongs to customer `k` when `k <= 100`, otherwise to customer `k - 100`.

Cross-system id formula, for core customer number `n`:

```text
core id    = C || LPAD(n, 4, '0')
payment id = P || LPAD(1000 + n, 4, '0')
digital id = D || LPAD(1000 + n, 4, '0')
```

Examples: `C0001` / `P1001` / `D1001`, and `C0010` / `P1010` / `D1010`.

No payment profile is created for core numbers `4, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200`.

No digital profile is created for core numbers `3, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195`.

`C0060`, `C0120`, and `C0180` are in both skip lists, so they exist only in Core Banking.

## ID formats

| Entity | Format | Example |
|---|---|---|
| Core customer | `C####` | `C0001` |
| Payment customer | `P####` | `P1001` |
| Digital customer | `D####` | `D1001` |
| Account | `A#####` | `A00001` |
| Transaction | `T######` | `T000001` |
| Activity | `ACT######` | `ACT000001` |
| Service case | `SC#####` | `SC00001` |
| Currency | `AUD` | `AUD` |
| Money | `NUMERIC(15,2)` | `25.01` |
| Date of birth | `DATE` | `1991-04-12` |
| Event timestamp | `TIMESTAMP` | `2026-01-01 00:17:00` |

`P0000` and `D0000` appear only as bad child references. They are not customer rows. `A99999` appears only as a bad account reference. It is not an account row.

## Synthetic-data assumptions

- `05` to `07` are literal `INSERT` statements. A full rebuild returns the same rows. The scripts do not use `RANDOM()`.
- The event window is 90 days: `2026-01-01 00:00:00` through `2026-03-31 23:59:00`, stored as `TIMESTAMP` without a time zone. Session time zone does not shift these values.
- A closed service case may end up to 96 hours after it was opened, so `closed_ts` can fall a few days after 31 March 2026.
- Bulk emails use `@example.test` and include the core customer id, so they are unique before the fixture edits.
- Bulk first-name and last-name pairs are unique across the 200 core customers. Fixture scripts then overwrite a few people.
- Addresses use eight real Australian state codes and one representative postcode each. Street names are fictional (`Synthetic Avenue`). Postcodes are text, so `0800` keeps its leading zero.
- Customer segment is `RETAIL`, `BUSINESS`, or `PREMIUM`. Customer status is `ACTIVE` or `INACTIVE`. Account status is `ACTIVE` or `CLOSED`. Those two status lists are different.
- Credit-card and home-loan balances are negative outstanding amounts. Transaction amounts are always positive. Direction is `transaction_type`.
- Product names start with `Synthetic`. They are not real CBA products.
- Customers `C0001` to `C0100` own two accounts. `C0101` to `C0200` own one.
- Clean transactions use a payment customer from the overlapping set and an account that same core customer owns.
- Activity channel is only `MOBILE` or `WEB`. `service_case` has no channel column. Reporting a case by channel would invent an attribution.
- `OPEN` and `IN_PROGRESS` cases have a null `closed_ts`. `CLOSED` cases have `closed_ts` after `opened_ts`.

## Deliberate data-quality problems

`05` to `07` load a clean population. `08_insert_edge_cases.sql` applies every defect below and labels it in comments.

| Id | What is wrong | Where to look |
|---|---|---|
| EC-01 | Same person, different source ids | `C0001`, `P1001`, `D1001` |
| EC-02 | Email differs only by case | `olivia.nguyen@example.test`, `Olivia.Nguyen@EXAMPLE.TEST`, `OLIVIA.NGUYEN@example.test` |
| EC-03 | Leading and trailing spaces | Payment first name ` John `; digital last name ` Smith ` |
| EC-04 | Phone format differs | `0412345678`, `+61 412 345 678`, `0412 345 678` on `C0002` / `P1002` / `D1002` |
| EC-05 | Optional phone is null | `C0005`, `P1005`, `D1005`. Match on date of birth and `isla.williams.c0005@example.test` |
| EC-06 | Payment customer with no core person | `P9999`, Quinn Harper |
| EC-07 | Duplicate business reference | `T000100` and `T002001` both use `BREF-000100` |
| EC-08 | Account id does not exist | `T000250.account_id = A99999` |
| EC-09 | Name is not a unique identity | `C0011` and `C0012` are both Alex Nguyen, with different date of birth and email. `P8888` uses the same name and matches neither |
| EC-10 | Name case and the gmail case pair | `C0010` / `P1010` / `D1010`, including `john.smith@gmail.com` and `John.Smith@GMAIL.COM` |
| EC-11 | Activity customer does not exist | `ACT000050` points at `D0000` |
| EC-12 | Service-case customer does not exist | `SC00020` points at `D0000` |
| EC-13 | Transaction customer does not exist | `T002002` points at `P0000` |
| EC-14 | No digital profile | `C0003` / `P1003`, and no `D1003` |
| EC-15 | No payment profile | `C0004` / `D1004`, and no `P1004` |

`expected_results.csv` is the customer-matching fixture for `customer_xref`. It has one row per core customer, plus `P8888` and `P9999`.

| `expected_outcome` | Meaning |
|---|---|
| `MATCH` | At least one other source belongs to this core person. A blank payment or digital id means that source has no profile. |
| `CORE_ONLY` | The person exists only in Core Banking. |
| `UNMATCHED` | The payment customer has no core person. |
| `AMBIGUOUS` | The name matches more than one core person, and date of birth plus email do not. |

`expected_group` is `E####` for every core customer. It is blank for `P8888` and `P9999`.

Do not match on name alone. `C0011` and `C0012` share Alex Nguyen.

## Validation steps

Run `09_source_validation.sql` after the edge-case script. It returns three result sets.

1. Scorecard. Every row should be `PASS`.
   - `CLEAN` means the check should find no problem.
   - `FIXTURE` means a deliberate defect should be present in the expected count. A fixture pass means the edge case exists.
2. The duplicate business reference and the bad account, payment-customer, activity, and service-case references.
3. The controlled identity rows side by side, including the blank payment or digital ids and the two payment-only customers.

Filter the scorecard with `WHERE result = 'FAIL'` if any row fails. Do not treat a fixture row as bad data that should be deleted before handoff. The downstream reject handling needs those rows.

The scorecard covers row counts, key uniqueness, id formats, ownership integrity, required nulls, the 90-day window, `opened_ts <= closed_ts`, currency, domains, and the separation between clean references and intentional bad references.

## Alignment with the current warehouse contract

Adopted from the 11 October alignment note:

- The scripts run in the Lab Environment on PostgreSQL, database `lab`.
- The three sources are schemas `s1_core`, `s2_payments`, and `s3_digital`, not three databases. A foreign-data wrapper can wait until after the demo.
- `service_case` has no channel. R4 should keep reporting cases by status only.
- `05` to `07` are literal inserts, so two runs load the same rows.

Still open, because changing them would remove edge cases the handover asked to keep, or would replace the running warehouse tables:

- Names stay `first_name` and `last_name`. `EC-03` and `EC-10` depend on one part of the name. `dim_customer.full_name` can be built downstream.
- The payments profile stays `payment_customer`, not `payers`.
- Ids stay `C0001` / `P1001` / `D1001`, not `C001` / `P001` / `U001`.
- Volumes stay at the project-plan figures above. The current prototype's smaller fixture is a separate run.
- These tables do not replace `s1_core.customers` or `s2_payments.payers`. Liangchen adds them to the 11-step run after the contract is frozen.

## Known limitations

- PostgreSQL enforces primary keys, and it enforces the two foreign keys on `s1_core.customer_account`.
- There are no foreign keys between the three schemas. Orphan fixture ids are not foreign keys either.
- A small number of transactions can reference a `CLOSED` account. Closure is a status, not an event history.
- Device type and activity channel are cycled independently.
- Bulk customers are adults with fictional `@example.test` emails. Only the John Smith fixture uses a gmail address, and that address is synthetic.
- `P9999` and `P8888` have no transactions. `T002002` is a transaction whose payment customer does not exist.
- Service cases can close slightly outside the 90-day event window.
- The scripts do not create a warehouse, role, or database grant.
- Re-running `02`, `03`, or `04` drops the loaded rows. Continue from `05` after replacing tables.

## Handoff notes for the warehouse and ETL team

Use this folder as the source contract:

```text
source_systems/
expected_results.csv
source_field_dictionary.csv
README_source_systems.md
```

Suggested consumption order:

1. Run `01` through `09` and confirm the scorecard is all `PASS`.
2. Snapshot each source table into staging. Keep the source ids. Do not merge the three customer tables on id.
3. Normalise email with `LOWER(TRIM(email))`, names with `TRIM` and a consistent case, and phone numbers to one digit format before matching. `0412345678` and `+61 412 345 678` are the same number.
4. Build `customer_xref` from date of birth plus normalised email or phone. Test it against `expected_results.csv`.
5. Send these rows to reject handling instead of dropping them silently:
   - `source_transaction_ref = BREF-000100` (duplicate business reference)
   - `account_id = A99999`
   - `payment_customer_id = P0000`
   - `digital_customer_id = D0000` on `ACT000050` and `SC00020`
6. Keep `P9999` as an unmatched payment customer. Do not attach `P8888` to `C0011` or `C0012` on the name Alex Nguyen.
7. Treat a missing payment or digital id in `expected_results.csv` as a real gap, not as a failed load. `C0003` has no digital profile. `C0004` has no payment profile. `C0060`, `C0120`, and `C0180` exist only in Core Banking.

Identity attributes available in all three customer tables are `first_name`, `last_name`, `date_of_birth`, `email`, and `phone`. Email and phone are nullable. Names are not unique.
