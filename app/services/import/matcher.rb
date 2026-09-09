# frozen_string_literal: true

module Import
  # Resolves a canonical row to an existing member (or nil) via identity precedence:
  # external_id > corporate_email.
  class Matcher
    attr_reader :roster

    def initialize(roster = [])
      @roster = roster
      @index = build_index(roster)
    end

    def match(canonical_row)
      external_matches = lookup(:external_id, value_for(canonical_row, :external_id))
      email_matches = lookup(:corporate_email, value_for(canonical_row, :work_email))

      conflict = conflict_match(external_matches, email_matches)
      return conflict if conflict

      return single_match(external_matches.first, 'external_id') if external_matches.one?
      return single_match(email_matches.first, 'corporate_email') if email_matches.one?

      { category: :new, member: nil, match_key: nil }
    end

    private

    # Builds a lookup table keyed by identity_key(:external_id, value) and
    # identity_key(:corporate_email, value) so matches are O(1) hash lookups
    # instead of linear scans over the roster.
    def build_index(roster)
      index = Hash.new { |h, k| h[k] = [] }

      roster.each do |member|
        external_id = value_for(member, :external_id)
        index[identity_key(:external_id, external_id)] << member if external_id.present?

        email = value_for(member, :corporate_email)
        index[identity_key(:corporate_email, email)] << member if email.present?
      end

      index
    end

    def lookup(attribute, value)
      return [] if value.blank?

      @index[identity_key(attribute, value)]
    end

    def identity_key(attribute, value)
      "#{attribute}:#{value.to_s.downcase}"
    end

    def conflict_match(external_matches, email_matches)
      return unless external_matches.any? && email_matches.any?
      return if external_matches.intersect?(email_matches)

      { category: :conflict, candidates: (external_matches + email_matches).uniq,
        member: nil, match_key: 'external_id' }
    end

    def single_match(member, match_key)
      { category: :match, member: member, match_key: match_key }
    end

    def value_for(record, attribute)
      if record.respond_to?(attribute)
        record.public_send(attribute)
      elsif record.respond_to?(:[])
        record[attribute]
      end
    end
  end
end
