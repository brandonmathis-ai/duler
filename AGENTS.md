# AGENTS.md

Guidance for AI coding agents working on this repository.

## Project Overview

Duler is an HRIS member sync application that ingests payroll exports and reconciles them with hotel staff rosters.

- **Backend:** Ruby on Rails 8 (Ruby 3.3, SQLite3, RSpec, Puma)
- **Frontend:** React 19, TypeScript, Vite (`vite_rails`), TanStack Query, Oxlint
- **Core Domain:** `app/services/import/` (parsing -> matching -> planning -> applying) and models (`Member`, `User`, `Assignment`, `ImportBatch`, `ImportRecord`)

## Key Commands

### Setup & Run
- `bundle install` — Install Ruby dependencies
- `npm install` — Install frontend dependencies
- `bin/dev` — Start Rails and Vite dev servers concurrently

### Testing & Validation
- `bundle exec rspec` — Run backend RSpec test suite
- `npm run build` — Run TypeScript typecheck (`tsc -b`) and Vite production build

### Linting & Formatting
- `bin/rubocop` (or `bundle exec rubocop`) — Run RuboCop on Ruby files
- `npm run lint` — Run Oxlint on frontend TypeScript/React files

## Agent Instructions & Guidelines

1. **Mandatory Linting:** Always run `bin/rubocop` and `npm run lint` before completing work, and resolve any violations.
2. **Verification:** Ensure tests and builds pass (`bundle exec rspec` and `npm run build`) before considering tasks complete.
3. **Data Integrity:** Never hard-delete roster members; departures/offboardings must be handled via status updates (e.g., `terminated`).
4. **Architecture Boundaries:** Preserve the separation of concerns in the reconcile pipeline:
   - **Parsing:** Extract canonical rows from source data (`app/services/import/parsers/`)
   - **Matching:** Match file records to existing roster members (`app/services/import/matcher.rb`)
   - **Planning:** Compute proposed changes before writing (`app/services/import/planner.rb`)
   - **Applying:** Execute planned changes safely and idempotently (`app/services/import/applier.rb`)
