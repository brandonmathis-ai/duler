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

## RULES
1. DO NOT run tests unless instructed to do so.

## Agent Instructions & Guidelines

1. **Mandatory Linting:** Always run `bin/rubocop` and `npm run lint` before completing work, and resolve any violations.
2. **Verification:** Ensure tests and builds pass (`bundle exec rspec` and `npm run build`) before considering tasks complete.
3. **Data Integrity:** Never hard-delete roster members; departures/offboardings must be handled via status updates (e.g., `terminated`).
4. **Architecture Boundaries:** Preserve the separation of concerns in the reconcile pipeline:
   - **Parsing:** Extract canonical rows from source data (`app/services/import/parsers/`)
   - **Matching:** Match file records to existing roster members (`app/services/import/matcher.rb`)
   - **Planning:** Compute proposed changes before writing (`app/services/import/planner.rb`)
   - **Applying:** Execute planned changes safely and idempotently (`app/services/import/applier.rb`)

## Test Structure

- Use a shallow `describe "when ..."` for the scenario and `it "..."` for the expected behavior.
- Keep each example self-contained: setup, exercise, and verification belong inside `it`, separated by blank lines. Prefer explicit local variables and a little duplication over nested contexts, `let`, `before`, `subject`, or shared examples that hide the test's flow.
- Reference the class under test explicitly do not use `described_class` in specs or test pseudocode.
- Keep factories minimal; opt into extra associations with traits only when needed.
- Do not change shared factory defaults unless absolutely necessary; prefer explicit values in the spec that needs them.
- Use deterministic, explicit test data instead of random values or Faker; cover unusual inputs deliberately.
- In feature/system specs, interact with and assert user-visible text rather than CSS classes, IDs, or DOM structure. Prefer `I18n.t` for translated labels.

```ruby
describe "when user signed in with their GitHub account" do
  it "doesn't show the credentials edition button" do
    user = create(:user, :from_github)

    visit root_path(as: user)
    click_on I18n.t("menu.edit_account")

    expect(page).not_to(
      have_content I18n.t("edit_account.password")
    )
  end
end
```
