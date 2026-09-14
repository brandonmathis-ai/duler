import type { ImportCategory, ImportSummary as Summary } from '../types/imports'

const summaryItems: Array<[ImportCategory, string]> = [
  ['new_invite', 'New members'],
  ['new_with_account', 'New members with accounts'],
  ['update', 'Updates'],
  ['reactivate', 'Reactivations'],
  ['offboard_terminated', 'Payroll offboards'],
  ['offboard_absent', 'Absent offboards'],
  ['unchanged', 'Unchanged'],
  ['conflict', 'Conflicts'],
  ['unprocessable', 'Unprocessable'],
]

export function ImportSummary({ summary }: { summary: Summary }) {
  return (
    <section aria-labelledby="summary-title">
      <h2 id="summary-title">Planned changes</h2>
      <dl className="summary-grid">
        {summaryItems.map(([category, label]) => (
          <div key={category}>
            <dt>{label}</dt>
            <dd>{summary.categories[category] ?? 0}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}
