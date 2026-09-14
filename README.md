# Duler — HRIS Member Sync (Take-Home)

Repo layout: this repository root is a Rails 8 app that serves both the API and the Vite + React + TS frontend.

## Development

```sh
bundle install
npm install
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

Open the app shown by `bin/dev`, then upload [`sample-import.csv`](./sample-import.csv) to review the example payroll export.
`db:seed` loads the Sunset Hotels sample roster needed to preview the sample import, including the deliberate Sam Rivera identity conflict.

## Import review

- Uploading creates a preview only; no roster data changes until you approve the plan.
- Each record shows its proposed before/after values, source rows, and reconciliation reason.
- When payroll identifiers point to different memberships, select exactly which membership receives payroll values.
- Planned offboarding requires an explicit confirmation and changes a member's status rather than deleting them.
- Candidate memberships not selected during conflict resolution remain untouched.

The preview API returns summary counts, every planned record, incoming values, and candidate memberships so the UI can make reconciliation decisions transparent before it writes. Applying sends the original CSV and the selected membership IDs; the server reparses and replans it rather than trusting a browser-provided plan.

This is intentionally a thin workflow: it has no persisted import plan or history, destructive duplicate merge, authentication or organization selector, background job, or frontend test framework. Conflict resolution selects the membership updated by this import; duplicate membership cleanup is a separate operational workflow.
