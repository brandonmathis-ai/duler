import type { ImportPlan } from '../types/imports'

async function requestImport(
  path: string,
  file: File,
  resolutions?: Record<string, number>,
): Promise<ImportPlan> {
  const body = new FormData()
  body.append('file', file)

  if (resolutions) {
    body.append('resolutions', JSON.stringify(resolutions))
  }

  const response = await fetch(path, { method: 'POST', body })
  const payload = (await response.json()) as ImportPlan | { error?: string }
  if (!response.ok) {
    throw new Error('error' in payload ? payload.error || 'Import request failed' : 'Import request failed')
  }

  return payload as ImportPlan
}

export function previewImport(file: File) {
  return requestImport('/api/imports/preview', file)
}

export function applyImport(file: File, resolutions: Record<string, number>) {
  return requestImport('/api/imports/apply', file, resolutions)
}
