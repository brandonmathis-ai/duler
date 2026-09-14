import type { ImportPlan } from '../types/imports'

interface ApplyPanelProps {
  plan: ImportPlan
  allConflictsResolved: boolean
  offboardsPresent: boolean
  offboardsConfirmed: boolean
  onConfirmOffboards: (confirmed: boolean) => void
  onApply: () => void
  onDiscard: () => void
  isPending: boolean
}

export function ApplyPanel({
  plan,
  allConflictsResolved,
  offboardsPresent,
  offboardsConfirmed,
  onConfirmOffboards,
  onApply,
  onDiscard,
  isPending,
}: ApplyPanelProps) {
  const disabled = !allConflictsResolved || (offboardsPresent && !offboardsConfirmed) || isPending

  return (
    <section className="apply-panel" aria-labelledby="approval-title">
      <h2 id="approval-title">Approve this import</h2>
      <p>
        {plan.summary.actionable} actions are ready. {plan.summary.conflicts} conflict
        {plan.summary.conflicts === 1 ? '' : 's'} must be resolved before applying.
      </p>
      {offboardsPresent && (
        <label className="confirm-offboards">
          <input
            type="checkbox"
            checked={offboardsConfirmed}
            onChange={(event) => onConfirmOffboards(event.target.checked)}
          />
          I confirm the planned offboardings.
        </label>
      )}
      <div className="button-row">
        <button type="button" className="secondary-button" onClick={onDiscard} disabled={isPending}>
          Discard plan
        </button>
        <button type="button" onClick={onApply} disabled={disabled}>
          {isPending ? 'Applying import...' : 'Approve and apply'}
        </button>
      </div>
    </section>
  )
}
