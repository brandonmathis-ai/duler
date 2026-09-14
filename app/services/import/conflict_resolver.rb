# frozen_string_literal: true

module Import
  # Converts each selected identity conflict into a normal entry without
  # changing the losing candidate memberships.
  class ConflictResolver
    class InvalidResolutionError < StandardError; end

    def initialize(organization)
      @organization = organization
    end

    def resolve(plan, resolutions)
      validate_plan_organization!(plan)
      selections = normalize_resolutions(resolutions)
      conflicts = plan.records.select { |record| record.category == :conflict }
      validate_selection_keys!(conflicts, selections)

      resolved_plan(plan, selections)
    end

    private

    def validate_plan_organization!(plan)
      return if plan.organization_id == @organization.id

      raise InvalidResolutionError, 'plan does not belong to this organization'
    end

    def normalize_resolutions(resolutions)
      return resolutions.to_h.transform_keys(&:to_s) if resolutions.respond_to?(:to_h)

      raise InvalidResolutionError, 'resolutions must be an object'
    end

    def validate_selection_keys!(conflicts, selections)
      expected_keys = conflicts.map(&:match_key).sort
      return if selections.keys.sort == expected_keys

      raise InvalidResolutionError, 'every current conflict must have exactly one selection'
    end

    def candidate_for!(record, selected_id)
      member = @organization.members.find_by(id: selected_id)
      valid = member && record.candidate_member_ids.include?(member.id)
      return member if valid

      raise InvalidResolutionError, "invalid selection for #{record.match_key}"
    end

    def resolved_plan(plan, selections)
      records = plan.records.map { |record| resolve_record(record, selections) }
      Import::Plan.new(organization_id: plan.organization_id, records:)
    end

    def resolve_record(record, selections)
      return record unless record.category == :conflict

      member = candidate_for!(record, selections.fetch(record.match_key))
      Import::Planner.new(@organization).resolved_entry_for(record, member)
    end
  end
end
