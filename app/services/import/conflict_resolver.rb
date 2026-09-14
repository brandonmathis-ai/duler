# frozen_string_literal: true

module Import
  # Converts each selected identity conflict into a normal entry without
  # changing the losing candidate memberships.
  class ConflictResolver
    def initialize(organization)
      @organization = organization
    end

    def resolve(plan, resolutions)
      resolved_plan(plan, resolutions)
    end

    private

    def resolved_plan(plan, selections)
      records = plan.records.map { |record| resolve_record(record, selections) }
      Import::Plan.new(organization_id: plan.organization_id, records:)
    end

    def resolve_record(record, selections)
      return record unless record.category == :conflict

      member = @organization.members.eligible_for_modification.find_by(id: selections.fetch(record.match_key))
      Import::Planner.new(@organization).resolved_entry_for(record, member)
    end
  end
end
