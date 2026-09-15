import type { Assignment } from '../types/imports'

export function display(value: unknown): string {
  if (Array.isArray(value)) return value.map((item) => JSON.stringify(item)).join(', ') || 'None'
  return value == null || value === '' ? 'Not set' : String(value)
}

export function isAssignment(value: unknown): value is Assignment {
  return (
    typeof value === 'object' &&
    value !== null &&
    'location_code' in value &&
    'role' in value &&
    typeof value.location_code === 'string' &&
    typeof value.role === 'string'
  )
}

export function assignments(value: unknown): Assignment[] {
  return Array.isArray(value) ? value.filter(isAssignment) : []
}

export function locationCodes(value: unknown): string[] {
  return [...new Set(assignments(value).map((item) => item.location_code))].sort()
}
