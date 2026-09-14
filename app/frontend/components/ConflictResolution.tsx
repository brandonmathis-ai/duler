import type { Assignment, ImportRecord } from '../types/imports'
import { ValueDiff } from './ValueDiff'

interface ConflictResolutionProps {
  record: ImportRecord
  selectedMemberId?: number
  onSelect: (key: string, memberId: number) => void
}

function matchingIdentifiers(record: ImportRecord, candidate: ImportRecord['candidates'][number]) {
  const matches = []
  if (candidate.external_id && candidate.external_id === record.after.external_id) {
    matches.push('Matches CSV external ID')
  }
  if (candidate.corporate_email && candidate.corporate_email === record.after.corporate_email) {
    matches.push('Matches CSV email')
  }
  return matches
}

const profileFields = [
  ['external_id', 'External ID'],
  ['first_name', 'First name'],
  ['last_name', 'Last name'],
  ['corporate_email', 'Email'],
  ['status', 'Status'],
] as const

function displayValue(value: unknown) {
  return value == null || value === '' ? 'Not set' : String(value)
}

function plannedUpdates(record: ImportRecord, candidate: ImportRecord['candidates'][number]) {
  return profileFields.flatMap(([field, label]) => {
    const before = candidate[field]
    const after = record.after[field]
    return before === after ? [] : [{ label, before: displayValue(before), after: displayValue(after) }]
  })
}

function uploadedAssignments(record: ImportRecord): Assignment[] {
  const assignments = record.after.assignments
  if (!Array.isArray(assignments)) return []

  return assignments.filter(
    (assignment): assignment is Assignment =>
      typeof assignment === 'object' &&
      assignment !== null &&
      'location_code' in assignment &&
      'role' in assignment &&
      typeof assignment.location_code === 'string' &&
      typeof assignment.role === 'string',
  )
}

function AssignmentTags({ assignments }: { assignments: Assignment[] }) {
  if (assignments.length === 0) return <span className="assignment-empty">None</span>

  return (
    <span className="assignment-tags">
      {assignments.map((assignment) => (
        <span className="assignment-tag" key={`${assignment.location_code}-${assignment.role}`}>
          {assignment.location_code}
        </span>
      ))}
    </span>
  )
}

export function ConflictResolution({ record, selectedMemberId, onSelect }: ConflictResolutionProps) {
  const payrollAssignments = uploadedAssignments(record)

  return (
    <fieldset className="conflict-resolution">
      <legend>Choose the membership to receive payroll values</legend>
      <div className="incoming-values">
        <strong>Uploaded payroll row (CSV - source of truth)</strong>
        <span>
          {String(record.after.first_name)} {String(record.after.last_name)} -{' '}
          {String(record.after.corporate_email)}
        </span>
        <span>External ID: {String(record.after.external_id)}</span>
        <span className="assignment-row">
          Assignments: <AssignmentTags assignments={payrollAssignments} />
        </span>
      </div>
      <p className="candidate-intro">Choose which existing Duler membership should receive these CSV values.</p>
      <div className="candidate-grid">
        {record.candidates.map((candidate) => {
          const matches = matchingIdentifiers(record, candidate)
          const updates = plannedUpdates(record, candidate)
          const selected = selectedMemberId === candidate.member_id

          return (
            <label className="candidate-card" key={candidate.member_id}>
              <input
                type="radio"
                name={`resolution-${record.key}`}
                checked={selected}
                onChange={() => onSelect(record.key, candidate.member_id)}
              />
              <span>
                <strong>Existing Duler membership</strong>
                <span className="candidate-name">
                  {candidate.first_name} {candidate.last_name}
                </span>
                <span className="identifier-matches">{matches.join(' + ')}</span>
                <span>External ID: {candidate.external_id || 'Not set'}</span>
                <span>Email: {candidate.corporate_email || 'Not set'}</span>
                <span>
                  {candidate.status} / {candidate.invite_status} /{' '}
                  {candidate.account_present ? 'Account present' : 'No account'}
                </span>
                <span className="assignment-row">
                  Assignments: <AssignmentTags assignments={candidate.assignments} />
                </span>
                <span className="candidate-action">Apply payroll values to this membership</span>
                {selected && (
                  <span className="planned-updates">
                    <strong>Planned update</strong>
                    {updates.length > 0 ? (
                      <ul>
                        {updates.map((update) => (
                          <li key={update.label}>
                            <span className="planned-update-label">{update.label}</span>
                            <ValueDiff before={update.before} after={update.after} />
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <span>Profile values already match the CSV.</span>
                    )}
                  </span>
                )}
              </span>
            </label>
          )
        })}
      </div>
      <p className="helper-text">Other candidate memberships will not be changed.</p>
    </fieldset>
  )
}
