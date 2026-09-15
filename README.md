# Duler — HRIS Member Sync (Take-Home)

This repository root is a Rails 8 app that serves both the API and the Vite + React + TypeScript frontend.

## How I Read the Brief

These bullets summarize my interpretation of the task and the assumptions used in this implementation.

- The payroll export is the source of truth for the current employee snapshot.
- A row is matched by external ID first, then corporate email. A disagreement between those identifiers is a conflict, not a guess.
- A missing employee is an offboard candidate; we set their status to terminated.
- Repeated employees in the CSV represent multiple property positions and are grouped by external ID. Rows without an external ID stay separate so an invalid row cannot hide another.
- The sample has one organization and no authentication boundary; production would supply the current organization from the signed-in user.

## Development

```sh
bundle install
npm install
bin/rails db:prepare
bin/dev
```

Open the app at `localhost:3000` and upload CSV roster files via the homepage.

## Reconciliation Architecture

- **Parsing:** Validates CSV data, raises an error if any row is missing critical information, and then supplies a set of canonical rows to a `Planner` object.
- **Matching:** Matches canonical rows to eligible roster members by external ID first and corporate email second. If those identifiers point to different memberships, it returns an explicit conflict instead of guessing.
- **Planning:** Accounts for every CSV file row. It produces a plan object containing a list of entries that describe the before and after state of every modification to be made to a member. Conflicts are organized separately within the plan for the user to resolve.
- **Approval:** The frontend displays the plan and the conflicts to resolve. The user resolves conflicts, visually verifies the information, and clicks Approve. Upon approval, the same CSV is resubmitted with a metadata object detailing how to resolve conflicts.
- **Application:** Once an import plan is approved, the requested conflict resolutions are applied to the plan generated from the CSV. The resolved plan is then passed to the applier, which makes the database updates in one large transaction.

The plan categories make the outcome of each record explicit: `new_invite` and `new_with_account` distinguish whether a new member needs an invitation; `update` and the offboard categories identify actionable roster changes; `unchanged` shows records that need no write; and `conflict` and `unprocessable` keep records that need review separate from safe actions. This lets the admin understand what will happen without inferring business rules from raw data. A second HRIS provider would add a provider-specific parser that maps its file format to the same canonical rows; matching, planning, applying, and the frontend would remain provider-independent. Re-running the same file is safe because matching uses stable identities, updates only write planned changes, assignments are not duplicated, and the approved plan is applied inside one transaction.

## Conflict Screen and API

- The screen previews the import before any roster data changes, so review is separate from approval.
- Summary counts show the scope of new members, updates, offboards, unchanged records, conflicts, and unprocessable rows.
- Each record shows its category, source row, reason, and before/after values so the admin can understand the proposed action.
- Conflicts show the incoming payroll identity beside each candidate membership and require an explicit selection instead of guessing.
- Offboards require explicit confirmation, and a rejected conflict candidate is left unchanged.

The preview API returns a `summary` object with total, actionable, conflict, unprocessable, and per-category counts, plus a `records` array. Each record includes its category, match key, before/after values, field-level changes, source row numbers, reasons, and candidate memberships when identity is ambiguous. This shape gives the UI both high-level counts for the review summary and the record-level evidence needed to display changes and resolve conflicts without duplicating business rules in React. Applying sends the original CSV and selected membership IDs; the server reparses and replans the file rather than trusting a browser-provided plan.

## Rollout

- **Milestone 1 — agree on the contract:** define the preview/apply API response, conflict-resolution payload, error states, and acceptance examples together before splitting implementation work.
- **Milestone 2 — parallel implementation:** one engineer owns the frontend for viewing, understanding, and approving proposed changes; the other owns the backend parser, matching, planning, conflict resolution, and application logic.
- **Milestone 3 — integration and guarded release:** connect both surfaces, test representative imports and conflicts end to end, and ship preview first before enabling production apply.
- The first release should prioritize a reliable dry-run preview, explicit conflict resolution, safe offboarding, and auditable before/after details. Scheduled imports, background processing, and additional HRIS providers can follow.
- The main risks are incorrect identity matches, a bad payroll snapshot causing mass offboarding, and duplicate or retried imports. The API contract, fixture scenarios, and review workflow should be agreed before implementation begins.
- I would own the backend reconciliation rules and application transaction, while the other engineer would own the review and approval UI. We would jointly review the API contract, integration behavior, and release criteria.
- Handoff requires the contract and example payloads to be documented, backend and frontend tests to cover the agreed scenarios, the preview to work against the real API, conflicts and offboards to require safe user action, and the end-to-end flow to be verified before either side is considered complete.

## Issues to note

- CSV ingestion could require additional validation. Often, users provide CSVs that are malformed or contain invalid characters. I put some light CSV validation in place, but it may need to be improved.
- Import plans are not persisted; they are generated directly from the CSV and held entirely in memory. This could cause issues for exceptionally large CSVs, but that is out of scope for the current implementation.
- The import process runs fully inline as part of request execution rather than in a separate active job or background job. Long-running imports could result in undesirable behavior, so it may be wise to move this to a queue or worker system.
- Our current database, SQLite, locks the entire database on write, which means that a very long-running import could cause issues for end users. For a production-style system, I would probably choose Postgres. I would likely perform updates in batches with a shared batch ID across all of them. If any sub-batch failed, the entire batch would be rolled back. Further evaluation would be necessary to understand typical production import sizes.

## Loom

https://www.loom.com/share/88a125840445499d8dc5a98df94b3283
