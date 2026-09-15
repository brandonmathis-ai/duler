import { conflictFields } from '../constants/imports'
import type { Candidate, MemberAttributes } from '../types/imports'
import { AssignmentList } from './AssignmentList'
import { Diff } from './Diff'

interface CandidateOptionProps {
  candidate: Candidate
  recordKey: string
  after: MemberAttributes
  isSelected: boolean
  onSelect: (memberId: number) => void
}

export function CandidateOption({
  candidate,
  recordKey,
  after,
  isSelected,
  onSelect,
}: CandidateOptionProps) {
  const matches = [
    candidate.external_id === after.external_id && candidate.external_id && 'Matches CSV external ID',
    candidate.corporate_email === after.corporate_email &&
      candidate.corporate_email &&
      'Matches CSV email',
  ].filter(Boolean)
  const updates = conflictFields.filter(([field]) => candidate[field] !== after[field])

  return (
    <label>
      <input
        type="radio"
        name={`resolution-${recordKey}`}
        checked={isSelected}
        onChange={() => onSelect(candidate.member_id)}
      />
      <span>
        <strong>Existing Duler membership</strong>
        <b>{candidate.first_name} {candidate.last_name}</b>
        <small>{matches.join(' + ')}</small>
        <span>External ID: {candidate.external_id || 'Not set'}</span>
        <span>Email: {candidate.corporate_email || 'Not set'}</span>
        <span>
          {candidate.status} / {candidate.invite_status} /{' '}
          {candidate.account_present ? 'Account present' : 'No account'}
        </span>
        <span>Assignments: <AssignmentList items={candidate.assignments} /></span>
        <strong className="action">Apply payroll values to this membership</strong>
        {isSelected && (
          <span className="updates">
            <strong>Planned update</strong>
            {updates.length ? (
              <ul>
                {updates.map(([field, label]) => (
                  <li key={field}>
                    {label}: <Diff before={candidate[field]} after={after[field]} />
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
}
