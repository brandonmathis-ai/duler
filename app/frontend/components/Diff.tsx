import { display } from '../utils/formatters'

interface DiffProps {
  before: unknown
  after: unknown
}

export function Diff({ before, after }: DiffProps) {
  return (
    <span className="diff">
      <span>{display(before)}</span> → <strong>{display(after)}</strong>
    </span>
  )
}
