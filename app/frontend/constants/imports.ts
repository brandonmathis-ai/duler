import type { ImportCategory } from '../types/imports'

export const categoryLabels: Record<ImportCategory, string> = {
  new_invite: 'New member',
  new_with_account: 'New member with account',
  update: 'Update',
  offboard_terminated: 'Offboard',
  offboard_absent: 'Offboard absent member',
  unchanged: 'Unchanged',
  conflict: 'Identity conflict',
  unprocessable: 'Unprocessable',
}

export const summaryItems: Array<[ImportCategory, string]> = [
  ['new_invite', 'New members'],
  ['update', 'Updates'],
  ['offboard_terminated', 'Payroll offboards'],
  ['offboard_absent', 'Absent offboards'],
  ['unchanged', 'Unchanged'],
  ['conflict', 'Conflicts'],
]

export const riskOrder: ImportCategory[] = [
  'conflict',
  'unprocessable',
  'offboard_terminated',
  'offboard_absent',
  'new_invite',
  'new_with_account',
  'update',
]

export const conflictFields = [
  ['external_id', 'External ID'],
  ['first_name', 'First name'],
  ['last_name', 'Last name'],
  ['corporate_email', 'Email'],
  ['status', 'Status'],
] as const
