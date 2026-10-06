# Group message and individual task cards

> Repository: https://github.com/liangchenwang-1-alt/32113-a2-group5
> How to use this file: copy section 1 into the group chat. Section 2 has the individual cards - send
> each person their own, or paste them all in the same message. Section 3 is my own step-by-step.
> Everything here is in English because that is the language of the group and of the report.

---

## 1. Message to paste in the group chat

```
Hi all - our A2 prototype is on GitHub now: https://github.com/liangchenwang-1-alt/32113-a2-group5
It is public, so just open the link - nothing to install.

Two things I need from each of you:

1) Send me the email address you want to use for GitHub, so I can add you as a collaborator on the
   repo. If you don't have a GitHub account yet, create a free one at https://github.com/signup with
   that email - it takes two minutes. (If you would rather not be added, you can still contribute:
   fork the repo, make your change and open a Pull Request.)

2) Run the prototype once on your own computer and tell me it works. You need Docker Desktop
   (workbook section 1.1.1):
       git clone https://github.com/liangchenwang-1-alt/32113-a2-group5.git
       # open a terminal in the folder of the cloned repo that contains run-lab.ps1
       powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start
       powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1     -> must end with OVERALL: PASS
   then send me the file produced by:
       powershell -NoProfile -ExecutionPolicy Bypass -File .\export-sync-info.ps1

What is already working end to end: 3 source schemas, the integrated warehouse (4 dimensions + 3 facts
+ customer identity xref + rejection audit), ETL and reconciliation (7 settled transactions -> 6 loaded,
1 orphan RECORDED instead of dropped, AUD 1835.50 reconciled on both sides), report views R1-R6, a
dashboard, and a passing end-to-end test matrix T1-T13.

This week each of you has ONE deliverable - your individual card is in this message / I will send yours
directly. Please push by Sunday 11 October, 23:59, or tell me early if that is not realistic.

Two rules: never commit the data\ folder, and never run "docker compose down -v".
```

### Short version (if you only want the emails first)

```
Hi all - please send me the email address you use (or will use) for GitHub, so I can add you as a
collaborator to our A2 repo: https://github.com/liangchenwang-1-alt/32113-a2-group5
If you don't have a GitHub account yet, just create a free one at https://github.com/signup with that
email. I will add you and you will get an invitation by email - please accept it.
```

---

## 2. Individual task cards

### Common rules (send with every card)

```
Rules for this week:
- Only edit the files listed in your card.
- After your change, run .\verify-e2e.ps1 locally. It must still end with OVERALL: PASS.
- Then: git add -A ; git commit -m "..." ; git push
- If you need to change a shared file (docker-compose.yml, contracts\*.md), say so in the chat first.
- WARNING for Qiushi: expanding the data changes the 7 table fingerprints. That is expected, but please
  tell the group, because I have to re-run the demo and update the numbers in our documents.
```

### 2.1 Md Mohsin Himel Mozumder - Architecture, integration and release coordination

```
Your deliverable: the solution architecture, as one file we can put straight into the report.

File to add: lab-env/advanced-data-lab/workspace/contracts/ARCHITECTURE.md
(exact path: lab-env/advanced-database-lab/workspace/contracts/ARCHITECTURE.md)

Content:
1) A diagram of the data flow: source systems -> staging/ETL -> integrated warehouse -> reports.
   Mermaid is fine (GitHub renders it automatically). Every arrow must correspond to something that
   actually exists in the SQL - no invented components.
2) 8-12 lines of text under the diagram: what moves where, what is transformed at each hop, and where
   customer identity resolution happens.

Acceptance: for each arrow I can point at the exact SQL file or statement that implements it, and the
file is committed. Ask me if you want me to walk you through the -- comments in the part3 SQL files.
```

### 2.2 Qiushi Huang - Source systems and synthetic data

```
Your deliverable: more realistic synthetic data, still fully deterministic.

Files you own:
  workspace/part3_warehouse_etl/01_source_ddl.sql
  workspace/part3_warehouse_etl/90_fixtures_sources.sql

Current state: 5 customers, 5 accounts, 8 transactions (7 settled), 6 digital activities, 4 service cases.

Target: at least 20 customers, 30 accounts, 60 transactions, 20 activities, 15 service cases.
Rules: literal INSERT statements only - no random(), no now() - so that two runs produce identical rows.
Keep the existing identity edge cases and add at least three new ones, for example: one email shared by
two different people, a payer with no email at all, and a transaction referencing an account that does
not exist in the core banking system.

Also update the row counts quoted in the testing documents under part5_reports_testing (the test matrix
and the report specification) if they change, or add one line saying "updated on <date>, see the new
fingerprint".

Acceptance: verify-e2e.ps1 still ends with OVERALL: PASS, R1/R2/R3 still return data, and you tell the
group that the fingerprints changed.
```

### 2.3 Sejin Park - Warehouse and customer identity integration

```
Your deliverable: the conceptual and logical data model for the report, plus one more deterministic
identity matching rule.

Files you own:
  workspace/part3_warehouse_etl/02_warehouse_ddl.sql
  workspace/part3_warehouse_etl/03_identity_xref.sql

1) Write the model documentation the report needs:
   - conceptual model: entities and relationships, no physical detail
   - logical model: table, keys, data types, GRAIN, and null rules
   Every column must match the DDL exactly, because the report will be checked against the SQL.
   Put it in: workspace/contracts/DATA_MODEL.md
   Include one sentence per fact table stating its grain (1 row = ...) - this is what stops the reports
   from multiplying amounts when they join.
2) Add one more deterministic identity rule (for example an exact match on phone, or on
   name + date of birth + state where that combination is unique). Explain in the comments why matching
   on name alone is still forbidden.

Acceptance: tests T4, T9 and T10 still PASS (T9 = account attribution agrees with customer_xref;
T10 = service cases are never attributed to a channel), and verify-e2e.ps1 still prints OVERALL: PASS.
```

### 2.4 Yutong Wang - Transaction and activity ETL; reconciliation

```
Your deliverable: the ETL rules written down, plus one new reconciliation check.

Files you own:
  workspace/part3_warehouse_etl/04_etl_load_facts.sql
  workspace/part3_warehouse_etl/05_reconciliation.sql

1) Document the loading rules where the report can use them:
   - which rows are loaded and which are rejected, and why
   - what happens to a row whose customer identity cannot be resolved: it must still be loaded with
     customer_key = NULL, never dropped - that is exactly what keeps the transaction count reconciling
   Put it in: workspace/part3_warehouse_etl/ETL_RULES.md
2) Add one more reconciliation check, for example per-channel amount conservation
   (sum over all channels = warehouse total), or activity count reconciliation.

Acceptance: T1 / T1b / T5 still PASS - count 7 - 1 = 6, amounts 1835.50 = 1835.50, and two consecutive
runs produce identical table fingerprints. verify-e2e.ps1 must still print OVERALL: PASS.
```

### 2.5 Liangchen Wang (me) - Reports, end-to-end tests and demo coordination

```
- Report views R1-R6, the three use-case reports and the dashboard (done; will be re-run after the
  others change the data)
- End-to-end test matrix T1-T13 and the recorded demo link (T8)
- Presentation schedule, Q&A preparation, contribution record (export-contributions.ps1)
```

---

## 3. My own step-by-step (from here to "they can push")

**Step 1 - Send the message**
Copy section 1 into the group chat. No email address is needed to *share* the repo: it is public, so
anyone with the link can read it.

**Step 2 - Collect their emails**
Wait for each person to reply with an email. Any email works - it does not have to be a GitHub one yet.
If someone does not have a GitHub account, the invitation email will walk them through creating one.

**Step 3 - Add them as collaborators**
Open: https://github.com/liangchenwang-1-alt/32113-a2-group5/settings/access
Click **Add people** -> type their **email address** -> role **Write** (enough to push) -> **Add**.

**Step 4 - Tell them to accept**
GitHub sends an invitation email to that address. They must open it and click
**View invitation -> Accept invitation**. Until they do, they cannot push (the Settings page shows them
as *Pending invitation*).

**Step 5 - Verify they got in**
Reload the Collaborators page: you should see four names plus yourself. Check who is still *Pending*
and remind those people.

**Step 6 - Watch the work arrive**
After they push, either run `git pull` in your local folder, or open
https://github.com/liangchenwang-1-alt/32113-a2-group5/commits to see who committed what and when.
For the appendix, run the contribution script in your local copy of the repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\export-contributions.ps1
```

**Step 7 - Keep the evidence**
Screenshot the Collaborators page and the group chat (task allocation + who replied). A2 brief
p.4 (viii)a asks for evidence of "tasks allocated and performed", so those screenshots go into the
appendix.

**If someone refuses to use GitHub**
They can still contribute without being added: **fork** the repo, make their change in their own copy,
and open a **Pull Request**. You review and merge it. Or, as a last resort, they send you the changed
file and you commit it for them - but then there is no commit history for their contribution, which
weakens the appendix evidence.

---

## 4. Deadline and escalation

- Individual deliverables: **Sunday 11 October 2026, 23:59** (A2 itself is due 16 October, 23:59).
- The A2 brief requires group issues to be reported to the tutor **at least one week before the due
  date**. If nothing has arrived by 11 October, send the tutor a short status note on **Monday
  12 October** - that still satisfies "at least one week". Later than that may not be considered.
- The note should state facts only: the shared repository, the running prototype baseline, what each
  member was asked to own, the deadline given, and what you have done yourself.

---

## 5. Check before sending

- [ ] Repository link opens in a private/incognito window (proves it is reachable by anyone)
- [ ] The names and roles in the cards match the group plan table
- [ ] The deadline in the message matches the one in the cards (Sunday 11 October, 23:59)
- [ ] You are ready to add collaborators as soon as the emails arrive
