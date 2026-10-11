# Package verification

Prepared for Liangchen Wang, Member 1, on 12 October 2026 (Sydney date).

Seven offline Python tests passed:

1. Equal fingerprints accepted; changed or empty fingerprints rejected.
2. SQL process failure preserved in logs and raised to the caller.
3. Missing input files prevented any database command.
4. Reset flag required before database work.
5. psql meta-commands preserved and ON_ERROR_STOP enabled.
6. Build stopped at the first execution failure.
7. Simulated two-build success and mismatch produced the correct summary and exit code.

The diagram was rendered from SVG to PNG and visually checked for readable text and
layout. These checks do not execute the SQL assertions or validate the lab database.
No live end-to-end PASS, new matching totals or database fingerprints were produced.

To repeat the offline tests from the package root:

```text
python -m unittest discover -s tests -v
```
