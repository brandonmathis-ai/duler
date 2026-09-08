# frozen_string_literal: true

module Import
  # Categorizes every canonical row (and every roster member) into a Plan.
  # rubocop:disable Metrics/ClassLength
  class Planner
    attr_reader :roster

    def initialize(roster = Member.all)
      @roster = roster
    end

    def plan(canonical_rows)
      members = query_members_for(canonical_rows)
      users_by_email = query_users_for(canonical_rows)
      matcher = Import::Matcher.new(members)

      records = canonical_rows.map do |row|
        entry_for(row, matcher, users_by_email)
      end

      records.concat(absence_entries_for(canonical_rows, records))

      Import::Plan.new(records: records)
    end

    private

    def query_members_for(canonical_rows)
      scopes = candidate_scopes_for(canonical_rows)
      return [] if scopes.empty?

      scopes.reduce(:or).to_a
    end

    def candidate_scopes_for(canonical_rows)
      [
        scope_for_external_ids(canonical_rows),
        scope_for_emails(canonical_rows)
      ].compact
    end

    def scope_for_external_ids(canonical_rows)
      external_ids = canonical_rows.filter_map { |row| value_for(row, :external_id).presence }
      @roster.where(external_id: external_ids) if external_ids.present?
    end

    def scope_for_emails(canonical_rows)
      emails = canonical_rows.filter_map { |row| value_for(row, :corporate_email).presence }
      @roster.where(corporate_email: emails) if emails.present?
    end

    def query_users_for(canonical_rows)
      emails = canonical_rows.filter_map { |row| value_for(row, :corporate_email).presence }
      return {} if emails.empty?

      User.where(login_email: emails).index_by(&:login_email)
    end

    def entry_for(row, matcher, users_by_email)
      return unprocessable_entry_for(row) if value_for(row, :issues).present?

      match = matcher.match(row)
      return conflict_entry_for(row, match.fetch(:candidates)) if match.fetch(:category) == :conflict

      member = match.fetch(:member)
      return new_entry_for(row, users_by_email) if member.nil?

      matched_entry_for(row, member)
    end

    def unprocessable_entry_for(row)
      Import::Plan::Entry.new(
        category: :unprocessable,
        match_key: match_key_for(row),
        after: incoming_attributes_for(row),
        source_rows: value_for(row, :source_rows),
        reasons: value_for(row, :issues)
      )
    end

    def conflict_entry_for(row, candidates)
      Import::Plan::Entry.new(
        category: :conflict,
        match_key: match_key_for(row),
        candidate_member_ids: candidates.map { |member| member_id_for(member) },
        after: incoming_attributes_for(row),
        source_rows: value_for(row, :source_rows),
        reasons: [:identity_conflict]
      )
    end

    def new_entry_for(row, users_by_email)
      user = users_by_email[value_for(row, :corporate_email)]
      category = user ? :new_with_account : :new_invite
      invite_status = user ? 'accepted' : 'pending'

      Import::Plan::Entry.new(
        category: category,
        match_key: match_key_for(row),
        user_id: user&.id,
        after: incoming_attributes_for(row).merge(invite_status: invite_status),
        source_rows: value_for(row, :source_rows)
      )
    end

    def matched_entry_for(row, member)
      before = member_attributes_for(member)
      after = incoming_attributes_for(row).merge(status: status_for(row))

      Import::Plan::Entry.new(**matched_entry_attributes(row, member, before, after))
    end

    def matched_entry_attributes(row, member, before, after)
      {
        category: category_for(before, after),
        match_key: match_key_for(row),
        matched_member_id: member_id_for(member),
        before: before,
        after: after,
        source_rows: value_for(row, :source_rows)
      }
    end

    def absence_entries_for(canonical_rows, records)
      external_ids = canonical_rows.filter_map { |row| value_for(row, :external_id).presence }
      accounted_ids = accounted_member_ids_for(records)

      absent_scope = @roster.where(status: 'active')
      absent_scope = absent_scope.where.not(external_id: external_ids) if external_ids.present?
      absent_scope = absent_scope.where.not(id: accounted_ids) if accounted_ids.present?

      absent_scope.map do |member|
        absence_entry_for(member)
      end
    end

    def accounted_member_ids_for(records)
      records.flat_map do |record|
        [record.matched_member_id, *record.candidate_member_ids]
      end.compact
    end

    def absence_entry_for(member)
      Import::Plan::Entry.new(
        category: :offboard_absent,
        match_key: "external_id:#{value_for(member, :external_id)}",
        matched_member_id: member_id_for(member),
        before: member_attributes_for(member),
        after: member_attributes_for(member).merge(status: 'terminated'),
        reasons: [:absent_from_snapshot]
      )
    end

    def category_for(before, after)
      return :offboard_terminated if before[:status] == 'active' && after[:status] == 'terminated'
      return :reactivate if before[:status] == 'terminated' && after[:status] == 'active'

      import_owned_attributes = %i[external_id first_name last_name corporate_email status]
      return :update if before.slice(*import_owned_attributes) != after.slice(*import_owned_attributes)

      :unchanged
    end

    def incoming_attributes_for(row)
      {
        external_id: value_for(row, :external_id),
        first_name: value_for(row, :first_name),
        last_name: value_for(row, :last_name),
        corporate_email: value_for(row, :corporate_email),
        status: status_for(row),
        assignments: assignments_for(row)
      }.compact
    end

    def assignments_for(row)
      active_positions_for(row).map do |position|
        { location_code: position.location_code, role: 'member' }
      end
    end

    def member_attributes_for(member)
      {
        external_id: value_for(member, :external_id),
        first_name: value_for(member, :first_name),
        last_name: value_for(member, :last_name),
        corporate_email: value_for(member, :corporate_email),
        status: value_for(member, :status),
        invite_status: value_for(member, :invite_status)
      }.compact
    end

    def status_for(row)
      active_positions_for(row).any? ? 'active' : 'terminated'
    end

    def active_positions_for(row)
      value_for(row, :positions).select { |position| position.status == 'active' }
    end

    def match_key_for(row)
      "external_id:#{value_for(row, :external_id)}"
    end

    def member_id_for(member)
      value_for(member, :id) || value_for(member, :membership_id)
    end

    def value_for(record, attribute)
      if record.respond_to?(attribute)
        record.public_send(attribute)
      else
        record[attribute]
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
