export type ImportCategory =
  | 'new_invite'
  | 'new_with_account'
  | 'update'
  | 'offboard_terminated'
  | 'offboard_absent'
  | 'unchanged'
  | 'conflict'
  | 'unprocessable'

export interface Assignment {
  location_code: string
  role: string
}

export interface Candidate {
  member_id: number
  external_id: string | null
  first_name: string | null
  last_name: string | null
  corporate_email: string | null
  status: string | null
  invite_status: string | null
  account_present: boolean
  assignments: Assignment[]
}

export interface ImportChange {
  field: string
  before: unknown
  after: unknown
}

export interface MemberAttributes {
  external_id?: string | null
  first_name?: string | null
  last_name?: string | null
  corporate_email?: string | null
  status?: string | null
  invite_status?: string | null
  assignments?: Assignment[]
  [key: string]: unknown
}

export interface ImportRecord {
  key: string
  category: ImportCategory
  before: MemberAttributes
  after: MemberAttributes
  changes: ImportChange[]
  source_rows: number[]
  reasons: string[]
  candidates: Candidate[]
}

export interface ImportSummary {
  total: number
  actionable: number
  conflicts: number
  unprocessable: number
  categories: Partial<Record<ImportCategory, number>>
}

export interface ImportPlan {
  summary: ImportSummary
  records: ImportRecord[]
}
