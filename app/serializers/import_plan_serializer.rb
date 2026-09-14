# frozen_string_literal: true

class ImportPlanSerializer
  def initialize(plan, organization)
    @plan = plan
    @organization = organization
    @candidates_by_id = candidate_members_by_id
  end

  def as_json(*)
    { summary: summary_json, records: @plan.records.map { |record| record_json(record) } }
  end

  private

  def summary_json
    categories = @plan.records.map(&:category).tally.transform_keys(&:to_s)
    {
      total: @plan.records.size,
      actionable: @plan.actionable_entries.size,
      conflicts: categories.fetch('conflict', 0),
      unprocessable: categories.fetch('unprocessable', 0),
      categories:
    }
  end

  def record_json(record)
    {
      key: record.match_key,
      category: record.category,
      before: record.before,
      after: record.after,
      changes: changes_for(record),
      source_rows: record.source_rows,
      reasons: record.reasons,
      candidates: record.candidate_member_ids.filter_map { |id| candidate_json(@candidates_by_id[id]) }
    }
  end

  def changes_for(record)
    record.attributes_to_apply.map do |key, value|
      { field: key, before: record.before[key], after: value }
    end
  end

  def candidate_members_by_id
    ids = @plan.records.flat_map(&:candidate_member_ids).uniq
    @organization.members.includes(:user, :assignments).where(id: ids).index_by(&:id)
  end

  def candidate_json(member)
    return if member.nil?

    candidate_attributes(member).merge(
      account_present: member.user.present?,
      assignments: member.assignments.map { |assignment| assignment_json(assignment) }
    )
  end

  def candidate_attributes(member)
    {
      member_id: member.id,
      external_id: member.external_id,
      first_name: member.first_name,
      last_name: member.last_name,
      corporate_email: member.corporate_email,
      status: member.status,
      invite_status: member.invite_status
    }
  end

  def assignment_json(assignment)
    { location_code: assignment.location_code, role: assignment.role }
  end
end
