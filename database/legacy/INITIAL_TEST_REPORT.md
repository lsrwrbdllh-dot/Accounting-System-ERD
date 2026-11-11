# SQLite schema validation — 2026-11-04

The schema in `database/schema.sql` was recreated as a SQLite database and tested locally.

## Results
- 11 application tables created successfully.
- 11 triggers created successfully.
- 4 default units and 7 document types inserted.
- 24 focused checks passed, including duplicate/empty units, missing parent FK, invoice line FK, movement uniqueness, posted-document immutability, and journal balancing.
- `PRAGMA integrity_check` returned `ok`.
- `PRAGMA foreign_key_check` returned no violations.

## Important discovered design gap
The database currently allows updating `Trans.Status` from `Draft` to `Posted` without automatically creating inventory movements or journal entries. The example test confirmed this is possible. Do not use this as a production posting mechanism. Application-level atomic posting, stock validation, and source validation are still required.

## Limitations
This was a focused schema smoke test, not full accounting acceptance testing. It does not prove financial correctness, concurrency safety, complete posting, inventory valuation, or multi-warehouse functionality. The SQLite binary database used for testing was generated locally; this report does not claim the binary was uploaded to GitHub.
