import type { ImportPlan } from '../types/imports'

export async function requestImport(
  path: string,
  file: File,
  resolutions?: Record<string, number>,
): Promise<ImportPlan> {
  const body = new FormData()
  body.append('file', file)
  if (resolutions) body.append('resolutions', JSON.stringify(resolutions))

  const response = await fetch(path, { method: 'POST', body })
  const data = (await response.json()) as ImportPlan | { error?: string }
  if (!response.ok) {
    throw new Error('error' in data ? data.error || 'Import request failed' : 'Import request failed')
  }
  return data as ImportPlan
}
