# frozen_string_literal: true

module Import
  # Resolves a canonical row to an existing member (or nil) via identity precedence:
  # external_id > corporate_email.
  class Matcher
    attr_reader :roster

    def initialize(roster = [])
      @roster = roster
    end

    def match(canonical_row)
      external_matches = matches_by_external_id(canonical_row)
      email_matches = matches_by_email(canonical_row)

      conflict = conflict_match(external_matches, email_matches)
      return conflict if conflict

      return single_match(external_matches.first, 'external_id') if external_matches.one?
      return single_match(email_matches.first, 'corporate_email') if email_matches.one?

      { category: :new, member: nil, match_key: nil }
    end

    private

    def matches_by_external_id(row)
      id = value_for(row, :external_id)
      return [] if id.blank?

      roster.select { |m| value_for(m, :external_id).to_s == id.to_s }
    end

    def matches_by_email(row)
      email = value_for(row, :work_email)
      return [] if email.blank?

      roster.select { |m| value_for(m, :corporate_email).to_s.casecmp?(email.to_s) }
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
