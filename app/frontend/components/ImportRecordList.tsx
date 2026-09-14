import { ConflictResolution } from './ConflictResolution'
import { ValueDiff } from './ValueDiff'
import type { ImportCategory, ImportRecord } from '../types/imports'

const categoryLabels: Record<ImportCategory, string> = {
  new_invite: 'New member',
  new_with_account: 'New member with account',
  update: 'Update',
  reactivate: 'Reactivate',
  offboard_terminated: 'Offboard',
  offboard_absent: 'Offboard absent member',
  unchanged: 'Unchanged',
  conflict: 'Identity conflict',
  unprocessable: 'Unprocessable',
}

const riskOrder: Record<ImportCategory, number> = {
  conflict: 0,
  unprocessable: 1,
  offboard_terminated: 2,
  offboard_absent: 2,
  new_invite: 3,
  new_with_account: 3,
  update: 3,
  reactivate: 3,
  unchanged: 4,
}

interface ImportRecordListProps {
  records: ImportRecord[]
  selections: Record<string, number>
  onSelect: (key: string, memberId: number) => void
}

function displayValue(value: unknown) {
  if (Array.isArray(value)) return value.map((item) => JSON.stringify(item)).join(', ') || 'None'
  return value == null || value === '' ? 'Not set' : String(value)
}

function recordName(record: ImportRecord) {
  return [record.after.first_name, record.after.last_name].filter(Boolean).join(' ') || record.key
}

interface RecordDetailsProps {
  record: ImportRecord
  selections: Record<string, number>
  onSelect: (key: string, memberId: number) => void
}

function RecordHeader({ record }: Pick<RecordDetailsProps, 'record'>) {
  return (
    <div className="record-heading">
      <div>
        <h3>{recordName(record)}</h3>
        <p>{String(record.after.corporate_email || 'No corporate email')}</p>
      </div>
      <span className={`badge badge-${record.category}`}>{categoryLabels[record.category]}</span>
    </div>
  )
}

function RecordDetails({ record, selections, onSelect }: RecordDetailsProps) {
  return (
    <>
      <p className="record-meta">
        Source rows: {record.source_rows.join(', ') || 'Not in upload'}
        {record.reasons.length > 0 && ` | ${record.reasons.join(', ')}`}
      </p>
      {record.category !== 'unchanged' && record.changes.length > 0 && (
        <dl className="change-list">
          {record.changes.map((change) => (
            <div key={change.field}>
              <dt>{change.field.replaceAll('_', ' ')}</dt>
              <dd>
                <ValueDiff before={displayValue(change.before)} after={displayValue(change.after)} />
              </dd>
            </div>
          ))}
        </dl>
      )}
      {record.category === 'conflict' && (
        <ConflictResolution
          record={record}
          selectedMemberId={selections[record.key]}
          onSelect={onSelect}
        />
      )}
    </>
  )
}

export function ImportRecordList({ records, selections, onSelect }: ImportRecordListProps) {
  const unchanged = records.filter((record) => record.category === 'unchanged')
  const actionable = records
    .filter((record) => record.category !== 'unchanged')
    .sort((left, right) => riskOrder[left.category] - riskOrder[right.category])

  return (
    <section aria-labelledby="records-title">
      <h2 id="records-title">Record review</h2>
      <div className="record-list">
        {actionable.map((record) => (
          <article className="record-card" key={record.key}>
            <RecordHeader record={record} />
            <RecordDetails record={record} selections={selections} onSelect={onSelect} />
          </article>
        ))}
        {unchanged.length > 0 && (
          <details className="unchanged-section">
            <summary>
              <span>Unchanged</span>
              <span className="unchanged-count">{unchanged.length} members</span>
            </summary>
            <div className="unchanged-list">
              {unchanged.map((record) => (
                <details className="record-card" key={record.key}>
                  <summary>
                    <RecordHeader record={record} />
                  </summary>
                  <div className="record-details">
                    <RecordDetails record={record} selections={selections} onSelect={onSelect} />
                  </div>
                </details>
              ))}
            </div>
          </details>
        )}
      </div>
    </section>
  )
}
