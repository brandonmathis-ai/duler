import type { FormEvent } from 'react'

interface FileUploadProps {
  onReview: (file: File) => void
  isPending: boolean
}

export function FileUpload({ onReview, isPending }: FileUploadProps) {
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const file = new FormData(event.currentTarget).get('file')
    if (file instanceof File && file.size > 0) onReview(file)
  }

  return (
    <section className="upload-card" aria-labelledby="upload-title">
      <p className="eyebrow">Payroll import</p>
      <h1 id="upload-title">Review roster changes before applying them</h1>
      <p>
        Upload a payroll CSV to preview proposed changes. Reviewing the file does not modify your roster.
      </p>
      <form onSubmit={submit} className="upload-form">
        <label htmlFor="payroll-file">Payroll CSV</label>
        <input id="payroll-file" name="file" type="file" accept=".csv,text/csv" required />
        <button type="submit" disabled={isPending}>
          {isPending ? 'Preparing review...' : 'Review import'}
        </button>
      </form>
    </section>
  )
}
