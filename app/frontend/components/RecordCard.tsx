import { categoryLabels } from '../constants/imports'
import type { ImportRecord } from '../types/imports'
import { locationCodes } from '../utils/formatters'
import { Conflict } from './Conflict'
import { Diff } from './Diff'

interface RecordCardProps {
  record: ImportRecord
  selected?: number
  onSelect: (memberId: number) => void
}

export function RecordCard({ record, selected, onSelect }: RecordCardProps) {
  const beforeLocations = locationCodes(record.before.assignments)
  const afterLocations = locationCodes(record.after.assignments)
  const changes = [...record.changes]
  if (beforeLocations.join() !== afterLocations.join()) {
    changes.push({
      field: 'locations',
      before: beforeLocations.join(', ') || 'None',
      after: afterLocations.join(', ') || 'None',
    })
  }

  return (
    <article>
      <header className="record-heading">
        <div>
          <h3>{[record.after.first_name, record.after.last_name].filter(Boolean).join(' ') || record.key}</h3>
          <p>{record.after.corporate_email || 'No corporate email'}</p>
        </div>
        <span className="badge">{categoryLabels[record.category]}</span>
      </header>
      <p className="muted">
        Source rows: {record.source_rows.join(', ') || 'Not in upload'}
        {record.reasons.length > 0 && ` | ${record.reasons.join(', ')}`}
      </p>
      {record.category !== 'unchanged' && changes.length > 0 && (
        <dl>
          {changes.map((change) => (
            <div key={change.field}>
              <dt>{change.field.replaceAll('_', ' ')}</dt>
              <dd><Diff before={change.before} after={change.after} /></dd>
            </div>
          ))}
        </dl>
      )}
      {record.category === 'conflict' && (
        <Conflict record={record} selected={selected} onSelect={onSelect} />
      )}
    </article>
  )
}
