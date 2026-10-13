# End-to-end demonstration plan

Use a real screen recording with narration. This file is a rehearsal plan, not video evidence.
Record the selected final branch and commit, show Compose service status, execute the
actual rebuild and display its PASS result and current batch. Do not splice an old PASS
screen into a different code version.

Suggested 10-minute presentation (maximum stated in brief: 15 minutes):
1. Liangchen, 1.5 min: problem, three sources, architecture and single run command.
2. Qiushi, 1.5 min: source schemas, synthetic counts and intentional bad rows.
3. Sejin, 2 min: C0001/P1001/D1001 to one customer_key; ambiguous/unmatched and R3 evidence.
4. Yutong, 2 min: staged classifications; 2002=1807+3+192; rejected IDs; repeatability.
5. Mohsin, 3 min: CloudBeaver R1/R2/R3, browser charts, CSVs, T9-T13 and negative rollback log.
All five members must participate in the presentation and prepare for cross-module Q&A.

Recording steps:
- Start the chosen screen recorder; include your terminal and browser, narration enabled.
- Show the code version and run the full build rather than only opening static tables.
- Open the latest evidence directory via LATEST_EVIDENCE.txt and show both fingerprints.
- Query one customer and a rejected transaction; show the three report questions.
- Stop recording, replay it, check legible SQL/results and audible narration.
- Upload to the group's selected location; test its link from an account without owner rights.
- Record the final URL and access-check time in your real submission materials.

Practice questions: Why no name-only match? Why R3 count zero? What is a fact grain?
Why aggregate facts before joining? Where did the other 195 transactions go? Does this
amount mean net cash flow? What survives a restart? Which source does a report read?
