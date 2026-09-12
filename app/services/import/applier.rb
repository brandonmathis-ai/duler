# frozen_string_literal: true

module Import
  # Applies an approved Plan to the database. Thin and idempotent.
  class Applier
    class UnapprovedPlanError < StandardError; end

    def apply(plan)
      raise UnapprovedPlanError, 'plan must be approved before applying' unless plan.approved?

      ActiveRecord::Base.transaction do
        organization_id = Organization.find(plan.organization_id).id
        entries = plan.actionable_entries
        members = resolve_members(entries, organization_id)
        id_by_external_id = create_members(entries, members, organization_id)
        update_members(entries, members)
        create_assignments(entries, id_by_external_id, members)
      end
      plan
    end

    private

    def resolve_members(entries, organization_id)
      member_ids = entries.filter_map(&:matched_member_id).uniq
      return {} if member_ids.empty?

      members = Member.where(organization_id: organization_id, id: member_ids).index_by(&:id)
      missing_ids = member_ids - members.keys
      return members if missing_ids.empty?

      raise ActiveRecord::RecordNotFound,
            "members #{missing_ids.join(', ')} do not belong to organization #{organization_id}"
    end

    # Returns a map of external_id to id for every newly created member.
    def create_members(entries, members, organization_id)
      creates = entries.reject { |entry| members[entry.matched_member_id] }
      existing_new_members = resolve_new_members(creates, organization_id)
      new_members = insert_new_members(new_entries(creates, existing_new_members), organization_id)
      new_members.merge(existing_new_members)
    end

    def new_entries(entries, existing_members)
      entries.reject { |entry| existing_members.key?(entry.after[:external_id]) }
    end

    def insert_new_members(entries, organization_id)
      group_by_attribute_keys(entries).each_with_object({}) do |group, id_by_external_id|
        ids = insert_member_group(group, organization_id)
        group.zip(ids).each { |entry, id| id_by_external_id[entry.after[:external_id]] = id }
      end
    end

    def resolve_new_members(entries, organization_id)
      external_ids = entries.filter_map { |entry| entry.after[:external_id] }.uniq
      return {} if external_ids.empty?

      Member
        .where(organization_id: organization_id, external_id: external_ids)
        .pluck(:external_id, :id)
        .to_h
    end

    # Batched writes skip model validations; the approved Plan and organization
    # lookup establish the required data first.
    def insert_member_group(group, organization_id)
      rows = group.map do |entry|
        member_attributes_for(entry).merge(organization_id: organization_id)
      end
      Member.insert_all(rows).rows.flatten # rubocop:disable Rails/SkipsModelValidations
    end

    # Each distinct attribute set is one relation#update, which maintains updated_at.
    # Sparse after hashes are grouped by identical attributes so an update never
    # clears attributes it doesn't mention.
    def update_members(entries, members)
      pairs = entries.filter_map do |entry|
        member = members[entry.matched_member_id]
        [member, member_attributes_for(entry)] if member
      end
      pairs.group_by(&:last).each do |attributes, group|
        Member.where(id: group.map { |member, _| member.id }).update(attributes)
      end
    end

    # Adds every file-listed location the member doesn't already have, in one insert.
    def create_assignments(entries, id_by_external_id, members)
      member_ids = member_ids_for(entries, id_by_external_id, members)
      taken = existing_assignment_pairs(member_ids.values)
      rows = entries.flat_map do |entry|
        new_assignment_rows(entry, member_ids[entry_key(entry)], taken)
      end
      Assignment.insert_all(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
    end

    # Existing entries use their planned member id. New entries use the id returned
    # by the member insert.
    def member_ids_for(entries, id_by_external_id, members)
      entries.each_with_object({}) do |entry, member_ids|
        member_id = members[entry.matched_member_id]&.id || id_by_external_id[entry_key(entry)]
        member_ids[entry_key(entry)] = member_id
      end
    end

    def entry_key(entry)
      entry.matched_member_id || entry.after[:external_id]
    end

    def new_assignment_rows(entry, member_id, taken)
      return [] if member_id.nil?

      Array(entry.after[:assignments]).filter_map do |assignment|
        location = assignment[:location_code]
        next if location.blank? || taken.include?([member_id, location])

        taken.add([member_id, location])
        { member_id: member_id, location_code: location, role: assignment[:role] }
      end
    end

    def existing_assignment_pairs(member_ids)
      Assignment.where(member_id: member_ids.compact).pluck(:member_id, :location_code).to_set
    end

    def member_attributes_for(entry)
      attributes = entry.after.except(:assignments).dup
      attributes[:user_id] = entry.user_id if entry.user_id.present?
      attributes
    end

    # insert_all requires every row in a batch to share the same keys, so entries are
    # grouped by identical attribute-key set.
    def group_by_attribute_keys(entries)
      entries.group_by { |entry| member_attributes_for(entry).keys.sort }.values
    end
  end
end
