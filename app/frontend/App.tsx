import { useMemo, useState, type FormEvent } from 'react'
import './App.css'
import { requestImport } from './api/imports'
import { RecordCard } from './components/RecordCard'
import { categoryLabels, riskOrder, summaryItems } from './constants/imports'
import type { ImportPlan } from './types/imports'

function App() {
  const [file, setFile] = useState<File>()
  const [plan, setPlan] = useState<ImportPlan>()
  const [appliedPlan, setAppliedPlan] = useState<ImportPlan>()
  const [selections, setSelections] = useState<Record<string, number>>({})
  const [offboardsConfirmed, setOffboardsConfirmed] = useState(false)
  const [pending, setPending] = useState<'preview' | 'apply'>()
  const [error, setError] = useState('')

  function reset() {
    setFile(undefined)
    setPlan(undefined)
    setSelections({})
    setOffboardsConfirmed(false)
    setError('')
  }

  async function preview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const upload = new FormData(event.currentTarget).get('file')
    if (!(upload instanceof File) || upload.size === 0) return

    setPending('preview')
    setError('')
    try {
      setPlan(await requestImport('/api/imports/preview', upload))
      setFile(upload)
      setSelections({})
      setOffboardsConfirmed(false)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Import request failed')
    } finally {
      setPending(undefined)
    }
  }

  async function apply() {
    if (!file) return
    setPending('apply')
    setError('')
    try {
      setAppliedPlan(await requestImport('/api/imports/apply', file, selections))
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Import request failed')
    } finally {
      setPending(undefined)
    }
  }

  const conflicts = useMemo(
    () => plan?.records.filter((record) => record.category === 'conflict') ?? [],
    [plan],
  )
  const offboardsPresent = useMemo(
    () => plan?.records.some((record) => record.category.startsWith('offboard_')) ?? false,
    [plan],
  )
  const canApply =
    conflicts.every((record) => selections[record.key] !== undefined) &&
    (!offboardsPresent || offboardsConfirmed)
  const records = useMemo(
    () =>
      plan?.records
        .filter((record) => record.category !== 'unchanged')
        .sort((a, b) => riskOrder.indexOf(a.category) - riskOrder.indexOf(b.category)) ?? [],
    [plan],
  )
  const unchanged = useMemo(
    () => plan?.records.filter((record) => record.category === 'unchanged') ?? [],
    [plan],
  )

  return (
    <main>
      <header className="page-header"><strong>Duler</strong><span>Roster reconciliation</span></header>
      {error && <p className="error" role="alert">{error}</p>}

      {appliedPlan ? (
        <section>
          <p>Import applied</p>
          <h1>Roster changes have been applied</h1>
          <p>{appliedPlan.summary.actionable} planned actions were applied successfully.</p>
          <button onClick={() => { reset(); setAppliedPlan(undefined) }}>Upload another file</button>
        </section>
      ) : plan && file ? (
        <>
          <section>
            <p>Reviewing {file.name}</p>
            <h1>No changes have been applied</h1>
            <p>Confirm this plan before Duler updates your roster.</p>
          </section>

          <section>
            <h2>Planned changes</h2>
            <dl className="summary">
              {summaryItems.map(([category, label]) => (
                <div key={category}><dt>{label}</dt><dd>{plan.summary.categories[category] ?? 0}</dd></div>
              ))}
            </dl>
          </section>

          <section>
            <h2>Record review</h2>
            <div className="records">
              {records.map((record) => (
                <RecordCard
                  key={record.key}
                  record={record}
                  selected={selections[record.key]}
                  onSelect={(memberId) =>
                    setSelections((prev) => ({ ...prev, [record.key]: memberId }))
                  }
                />
              ))}
              {unchanged.length > 0 && (
                <details>
                  <summary>Unchanged <span className="muted">{unchanged.length} members</span></summary>
                  {unchanged.map((record) => (
                    <details className="unchanged" key={record.key}>
                      <summary className="record-heading">
                        <span>
                          {[record.after.first_name, record.after.last_name].filter(Boolean).join(' ') || record.key}
                          <small>{record.after.corporate_email || 'No corporate email'}</small>
                        </span>
                        <span className="badge">{categoryLabels[record.category]}</span>
                      </summary>
                      <p className="muted">
                        Source rows: {record.source_rows.join(', ') || 'Not in upload'}
                        {record.reasons.length > 0 && ` | ${record.reasons.join(', ')}`}
                      </p>
                    </details>
                  ))}
                </details>
              )}
            </div>
          </section>

          <section>
            <h2>Approve this import</h2>
            <p>
              {plan.summary.actionable} actions are ready. {plan.summary.conflicts} conflict
              {plan.summary.conflicts === 1 ? '' : 's'} must be resolved before applying.
            </p>
            {offboardsPresent && (
              <label>
                <input
                  type="checkbox"
                  checked={offboardsConfirmed}
                  onChange={(event) => setOffboardsConfirmed(event.target.checked)}
                />{' '}
                I confirm the planned offboardings.
              </label>
            )}
            <div className="buttons">
              <button className="secondary" onClick={reset} disabled={pending === 'apply'}>Discard plan</button>
              <button onClick={apply} disabled={!canApply || pending === 'apply'}>
                {pending === 'apply' ? 'Applying import...' : 'Approve and apply'}
              </button>
            </div>
          </section>
        </>
      ) : (
        <section>
          <p>Payroll import</p>
          <h1>Review roster changes before applying them</h1>
          <p>Upload a payroll CSV to preview proposed changes. Reviewing the file does not modify your roster.</p>
          <form onSubmit={preview}>
            <label htmlFor="payroll-file">Payroll CSV</label>
            <input id="payroll-file" name="file" type="file" accept=".csv,text/csv" required />
            <button disabled={pending === 'preview'}>
              {pending === 'preview' ? 'Preparing review...' : 'Review import'}
            </button>
          </form>
        </section>
      )}
    </main>
  )
}

export default App
