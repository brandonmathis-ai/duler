import type { Assignment } from '../types/imports'

interface AssignmentListProps {
  items: Assignment[]
}

export function AssignmentList({ items }: AssignmentListProps) {
  return items.length ? (
    <span className="tags">
      {items.map((item) => (
        <span key={`${item.location_code}-${item.role}`}>{item.location_code}</span>
      ))}
    </span>
  ) : (
    <span className="muted">None</span>
  )
}
