interface ValueDiffProps {
  before: string
  after: string
}

export function ValueDiff({ before, after }: ValueDiffProps) {
  return (
    <span className="value-diff">
      <span className="value-diff-before">
        {before}
      </span>
      <span className="value-diff-arrow" aria-hidden="true">
        →
      </span>
      <span className="value-diff-after">
        <strong>{after}</strong>
      </span>
    </span>
  )
}
