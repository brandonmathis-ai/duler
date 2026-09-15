# frozen_string_literal: true

module Import
  # Categorizes every canonical row (and every roster member) into a Plan.
  # rubocop:disable Metrics/ClassLength
  class Planner
    attr_reader :organization, :roster

    def initialize(organization)
      @organization = organization
      @roster = organization.members.eligible_for_modification
    end

    def plan(canonical_rows)
      members = query_members_for(canonical_rows)
      users_by_email = query_users_for(canonical_rows)
      matcher = Import::Matcher.new(members)

      records = canonical_rows.map do |row|
        build_entry_for(row, matcher, users_by_email)
      end

      records.concat(absence_entries_for(records))

      Import::Plan.new(organization_id: organization.id, records: records)
    end

    def resolved_entry_for(conflict_entry, member)
      before = member_attributes_for(member)

      Import::Plan::Entry.new(
        category: category_for(before, conflict_entry.after),
        match_key: conflict_entry.match_key,
        matched_member_id: member_id_for(member),
        candidate_member_ids: conflict_entry.candidate_member_ids,
        **resolved_entry_attributes(conflict_entry, before)
      )
    end

    private

    def query_members_for(canonical_rows)
      scopes = [
        scope_for_external_ids(canonical_rows),
        scope_for_emails(canonical_rows)
      ].compact

      return [] if scopes.empty?

      scopes.reduce(:or).to_a
    end

    def scope_for_external_ids(canonical_rows)
      external_ids = canonical_rows.filter_map { |row| row.external_id.presence }
      @roster.where(external_id: external_ids) if external_ids.present?
    end

    def scope_for_emails(canonical_rows)
      emails = canonical_rows.filter_map { |row| row.work_email.presence }
      @roster.where(corporate_email: emails) if emails.present?
    end

    def query_users_for(canonical_rows)
      emails = canonical_rows.filter_map { |row| row.work_email.presence }
      return {} if emails.empty?

      User.where(login_email: emails).index_by(&:login_email)
    end

    # Builds a plan entry by converting the matcher's conflict,
    # new-member, or existing-member result into a record.
    def build_entry_for(row, matcher, users_by_email)
      match = matcher.match(row)
      return conflict_entry_for(row, match.fetch(:candidates)) if match.fetch(:category) == :conflict

      member = match.fetch(:member)
      return new_entry_for(row, users_by_email) if member.nil?

      matched_entry_for(row, member)
    end

    def conflict_entry_for(row, candidates)
      Import::Plan::Entry.new(
        category: :conflict,
        match_key: match_key_for(row),
        candidate_member_ids: candidates.map { |member| member_id_for(member) },
        after: incoming_attributes_for(row),
        source_rows: row.source_rows,
        reasons: [:identity_conflict]
      )
    end

    def new_entry_for(row, users_by_email)
      user = users_by_email[row.work_email]
      category = user ? :new_with_account : :new_invite
      invite_status = user ? 'accepted' : 'pending'

      Import::Plan::Entry.new(
        category: category,
        match_key: match_key_for(row),
        user_id: user&.id,
        after: incoming_attributes_for(row).merge(invite_status: invite_status),
        source_rows: row.source_rows
      )
    end

    def matched_entry_for(row, member)
      before = member_attributes_for(member)
      after = incoming_attributes_for(row).merge(status: status_for(row))

      Import::Plan::Entry.new(
        category: category_for(before, after),
        match_key: match_key_for(row),
        matched_member_id: member_id_for(member),
        before: before,
        after: after,
        source_rows: row.source_rows
      )
    end

    # Absent = every active roster member not already accounted for by a
    # built record (matched, a conflict candidate, or held by an
    # unprocessable row). This is the inverse of what the plan already
    # applies, rather than a second, independent identity check.
    def absence_entries_for(records)
      accounted_ids = Import::Plan.new(
        organization_id: organization.id,
        records: records
      ).accounted_member_ids
      absent_scope = @roster.where(status: 'active')
      absent_scope = absent_scope.where.not(id: accounted_ids) if accounted_ids.present?

      absent_scope.map { |member| absence_entry_for(member) }
    end

    def absence_entry_for(member)
      Import::Plan::Entry.new(
        category: :offboard_absent,
        match_key: "external_id:#{member.external_id}",
        matched_member_id: member_id_for(member),
        before: member_attributes_for(member),
        after: member_attributes_for(member).merge(status: 'terminated'),
        reasons: [:absent_from_snapshot]
      )
    end

    def category_for(before, after)
      status_category = status_category_for(before, after)
      return status_category if status_category

      import_owned_attributes = %i[external_id first_name last_name corporate_email status]
      return :update if before.slice(*import_owned_attributes) != after.slice(*import_owned_attributes)
      return :update if assignment_changed?(before, after)

      :unchanged
    end

    def status_category_for(before, after)
      return :offboard_terminated if before[:status] == 'active' && after[:status] == 'terminated'

      nil
    end

    def assignment_changed?(before, after)
      before[:assignments].pluck(:location_code).uniq.sort !=
        after[:assignments].pluck(:location_code).uniq.sort
    end

    def incoming_attributes_for(row)
      {
        external_id: row.external_id,
        first_name: row.first_name,
        last_name: row.last_name,
        corporate_email: row.work_email,
        status: status_for(row),
        assignments: assignments_for(row)
      }.compact
    end

    def assignments_for(row)
      active_positions_for(row).filter_map do |position|
        next if position.location_code.blank?

        { location_code: position.location_code, role: 'member' }
      end
    end

    def member_attributes_for(member)
      {
        external_id: member.external_id,
        first_name: member.first_name,
        last_name: member.last_name,
        corporate_email: member.corporate_email,
        status: member.status,
        invite_status: member.invite_status,
        assignments: member_assignment_attributes_for(member)
      }.compact
    end

    def member_assignment_attributes_for(member)
      member.assignments.order(:location_code).map do |assignment|
        { location_code: assignment.location_code, role: assignment.role }
      end
    end

    def resolved_entry_attributes(conflict_entry, before)
      {
        before:,
        after: conflict_entry.after,
        source_rows: conflict_entry.source_rows,
        reasons: conflict_entry.reasons
      }
    end

    def status_for(row)
      active_positions_for(row).any? ? 'active' : 'terminated'
    end

    def active_positions_for(row)
      row.positions.select { |position| position.status == 'active' }
    end

    def match_key_for(row)
      "external_id:#{row.external_id}"
    end

    def member_id_for(member)
      member.id
    end
    # rubocop:enable Metrics/ClassLength
  end
end
