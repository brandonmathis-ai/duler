import type { ImportRecord } from '../types/imports'
import { assignments, display } from '../utils/formatters'
import { AssignmentList } from './AssignmentList'
import { CandidateOption } from './CandidateOption'

interface ConflictProps {
  record: ImportRecord
  selected?: number
  onSelect: (memberId: number) => void
}

export function Conflict({ record, selected, onSelect }: ConflictProps) {
  const fullName = [record.after.first_name, record.after.last_name].filter(Boolean).join(' ') || record.key

  return (
    <fieldset>
      <legend>Choose the membership to receive payroll values</legend>
      <div className="incoming">
        <strong>Uploaded payroll row (CSV - source of truth)</strong>
        <span>
          {fullName}
          {record.after.corporate_email && ` - ${record.after.corporate_email}`}
        </span>
        <span>External ID: {display(record.after.external_id)}</span>
        <span>Assignments: <AssignmentList items={assignments(record.after.assignments)} /></span>
      </div>
      <p className="muted">Choose which existing Duler membership should receive these CSV values.</p>
      <div className="candidates">
        {record.candidates.map((candidate) => (
          <CandidateOption
            key={candidate.member_id}
            candidate={candidate}
            recordKey={record.key}
            after={record.after}
            isSelected={selected === candidate.member_id}
            onSelect={onSelect}
          />
        ))}
      </div>
      <p className="muted">Other candidate memberships will not be changed.</p>
    </fieldset>
  )
}
