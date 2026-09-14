# Duler — HRIS Member Sync (Take-Home)

This repository root is a Rails 8 app that serves both the API and the Vite + React + TypeScript frontend.

## How I read the brief

- The payroll export is the source of truth for the current employee snapshot.
- A row is matched by external ID first, then corporate email. A disagreement between those identifiers is a conflict, not a guess.
- A missing employee is an offboard candidate, but applying that plan terminates the member rather than deleting history or assignments.
- Repeated employees in the CSV represent multiple property positions and are grouped by external ID. Rows without an external ID stay separate so an invalid row cannot hide another.
- The sample has one organization and no authentication boundary; production would supply the current organization from the signed-in user.

## Development

```sh
bundle install
npm install
bin/rails db:prepare
bin/dev
```

Open the app shown by `bin/dev`, then upload [`sample-import.csv`](./sample-import.csv) to review the example payroll export. `db:prepare` loads the Sunset Hotels sample roster needed to preview the sample import, including the deliberate Sam Rivera identity conflict. If you need to start over, run `bin/rails db:reset` by itself; Rails runs seeds during setup/reset, so do not run `db:seed` again afterward.

## Reconcile structure

- **Parsing** converts the provider CSV into canonical employee and position rows, including source row numbers and validation issues.
- **Matching** indexes the eligible roster by external ID and email, with explicit conflict results instead of fuzzy matching.
- **Planning** accounts for every file row and active roster member, classifying new members, updates, offboards, unchanged records, conflicts, and unprocessable rows before any write.
- **Applying** is a thin, approved-plan transaction. It reparses and replans the original CSV on apply, batches safe writes, preserves terminated members, and avoids duplicate assignments.

The categories make the admin decision visible: actionable changes are separate from records that need review or cannot be processed. A second HRIS format would add another parser that emits the same canonical row objects; matching, planning, applying, and the screen would stay provider-independent. Re-running the same file is safe because matching is identity-based, updates are sparse, and assignments are inserted only when the member/location pair is absent.

## Import review and conflict screen

- Uploading creates a preview only; no roster data changes until you approve the plan.
- Each record shows its proposed before/after values, source rows, and reconciliation reason.
- When payroll identifiers point to different memberships, select exactly which membership receives payroll values.
- Planned offboarding requires an explicit confirmation and changes a member's status rather than deleting them.
- Candidate memberships not selected during conflict resolution remain untouched.

The admin can trust the screen because it is a preview, not an implicit write; every file row and roster absence is accounted for; and source rows, reasons, and before/after values are shown. Conflicts show the incoming payroll identity beside each candidate membership and require an explicit selection. Offboards are visibly separate and require confirmation, while rejected candidates are left untouched.

The preview API returns a summary object (total, actionable, conflict, unprocessable, and per-category counts) plus a `records` array. Each record contains its category, match key, before/after values, field-level changes, source row numbers, reasons, and candidate memberships when identity is ambiguous. This shape lets the UI render both the high-level review counts and the exact evidence needed to resolve a conflict without recomputing business rules in React. Applying sends the original CSV and selected membership IDs; the server reparses and replans it rather than trusting a browser-provided plan.

## Rollout

- **Milestone 1 — dry-run import:** ship the parser, canonical model, planner, preview endpoint, and structured logs/metrics for malformed and unprocessable rows.
- **Milestone 2 — guarded apply:** add authentication and organization scoping, approval/audit records, idempotency keys, and an explicit offboard confirmation in the production workflow.
- **Milestone 3 — nightly operation:** add a background job, provider-specific upload adapter, retry/alerting, and an operator report for conflicts that need human action.
- I would hand the other engineer the parser adapter, upload/job plumbing, and observability after the canonical row contract and planner fixtures are agreed. I would keep the matching and planning rules until their edge cases are covered by reviewable examples.
- The biggest risks are incorrect identity matches, a bad payroll snapshot causing mass offboarding, and duplicate/retried imports. No nightly rollout should proceed until preview sampling, organization isolation, idempotency, and recovery/audit behavior are proven.

## What I cut

- One payroll CSV provider only; there is no second HRIS adapter.
- No persisted import history, scheduled job, authentication, organization picker, or notification system.
- No destructive duplicate merge workflow; conflict resolution chooses the membership for this import and leaves the other memberships for a separate operational decision.
- No exhaustive payroll-provider validation or large-roster performance tuning beyond indexed lookups and batched writes.

## Loom

Loom walkthrough: [recording link to add before submission](https://www.loom.com/).
