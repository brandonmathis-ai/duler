import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import './App.css'
import { applyImport, previewImport } from './api/imports'
import { ApplyPanel } from './components/ApplyPanel'
import { FileUpload } from './components/FileUpload'
import { ImportRecordList } from './components/ImportRecordList'
import { ImportSummary } from './components/ImportSummary'
import type { ImportPlan } from './types/imports'

function App() {
  const [file, setFile] = useState<File>()
  const [plan, setPlan] = useState<ImportPlan>()
  const [selections, setSelections] = useState<Record<string, number>>({})
  const [offboardsConfirmed, setOffboardsConfirmed] = useState(false)
  const [appliedPlan, setAppliedPlan] = useState<ImportPlan>()

  const previewMutation = useMutation({
    mutationFn: previewImport,
    onSuccess: (nextPlan, nextFile) => {
      setFile(nextFile)
      setPlan(nextPlan)
      setSelections({})
      setOffboardsConfirmed(false)
    },
  })
  const applyMutation = useMutation({
    mutationFn: ({ upload, resolutions }: { upload: File; resolutions: Record<string, number> }) =>
      applyImport(upload, resolutions),
    onSuccess: (nextPlan) => setAppliedPlan(nextPlan),
  })

  const error = previewMutation.error || applyMutation.error
  const conflicts = plan?.records.filter((record) => record.category === 'conflict') ?? []
  const allConflictsResolved = conflicts.every((record) => selections[record.key] !== undefined)
  const offboardsPresent = Boolean(
    plan?.records.some(
      (record) => record.category === 'offboard_terminated' || record.category === 'offboard_absent',
    ),
  )

  function discardPlan() {
    setFile(undefined)
    setPlan(undefined)
    setSelections({})
    setOffboardsConfirmed(false)
    previewMutation.reset()
    applyMutation.reset()
  }

  function startNewUpload() {
    discardPlan()
    setAppliedPlan(undefined)
  }

  return (
    <main className="import-container">
      <header className="page-header">
        <p className="eyebrow">Duler</p>
        <p>Roster reconciliation</p>
      </header>
      {error && (
        <p className="error-message" role="alert">
          {error.message}
        </p>
      )}
      {appliedPlan ? (
        <section className="success-card" aria-labelledby="success-title">
          <p className="eyebrow">Import applied</p>
          <h1 id="success-title">Roster changes have been applied</h1>
          <p>{appliedPlan.summary.actionable} planned actions were applied successfully.</p>
          <button type="button" onClick={startNewUpload}>
            Upload another file
          </button>
        </section>
      ) : plan && file ? (
        <>
          <section className="review-heading" aria-labelledby="review-title">
            <p className="eyebrow">Reviewing {file.name}</p>
            <h1 id="review-title">No changes have been applied</h1>
            <p>Confirm this plan before Duler updates your roster.</p>
          </section>
          <ImportSummary summary={plan.summary} />
          <ImportRecordList
            records={plan.records}
            selections={selections}
            onSelect={(key, memberId) => setSelections((current) => ({ ...current, [key]: memberId }))}
          />
          <ApplyPanel
            plan={plan}
            allConflictsResolved={allConflictsResolved}
            offboardsPresent={offboardsPresent}
            offboardsConfirmed={offboardsConfirmed}
            onConfirmOffboards={setOffboardsConfirmed}
            onApply={() => applyMutation.mutate({ upload: file, resolutions: selections })}
            onDiscard={discardPlan}
            isPending={applyMutation.isPending}
          />
        </>
      ) : (
        <FileUpload onReview={(upload) => previewMutation.mutate(upload)} isPending={previewMutation.isPending} />
      )}
    </main>
  )
}

export default App
