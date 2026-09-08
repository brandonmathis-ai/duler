# frozen_string_literal: true

module Import
  # Value object: the categorized import records plus their counts.
  class Plan
    class Entry
      attr_reader :category, :match_key, :matched_member_id, :candidate_member_ids,
                  :user_id, :before, :after, :source_rows, :reasons

      # rubocop:disable-next Metrics/ParameterLists
      def initialize(category:, match_key:, matched_member_id: nil, candidate_member_ids: [],
                     user_id: nil, before: {}, after: {}, source_rows: [], reasons: [])
        @category = category
        @match_key = match_key
        @matched_member_id = matched_member_id
        @candidate_member_ids = candidate_member_ids
        @user_id = user_id
        @before = before
        @after = after
        @source_rows = source_rows
        @reasons = reasons
      end

      def attributes_to_apply
        after.slice(*changed_attribute_names)
      end

      def actionable?
        %i[new_invite new_with_account update offboard_terminated offboard_absent reactivate].include?(category)
      end

      private

      def changed_attribute_names
        after.except(:assignments).keys.reject { |key| before[key] == after[key] }
      end
    end

    attr_reader :records, :counts

    def initialize(records: [], counts: {})
      @records = records
      @counts = counts.presence || records.map(&:category).tally
      @approved = false
    end

    def approve!
      @approved = true
      self
    end

    def approved?
      @approved
    end

    def actionable_entries
      records.select(&:actionable?)
    end

    def accounted_member_ids
      records.flat_map do |record|
        [record.matched_member_id, *record.candidate_member_ids]
      end.compact.uniq
    end

    def invitation_actions
      records.select { |record| record.category == :new_invite }
    end

    def assignment_actions
      []
    end
  end
end
