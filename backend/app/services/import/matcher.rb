# frozen_string_literal: true

module Import
  # Resolves a canonical row to an existing member (or nil) via identity precedence:
  # external_id > corporate_email > name (weak, review-flagged only).
  class Matcher
    def match(_canonical_row)
      raise NotImplementedError, "#{self.class}#match not yet implemented"
    end
  end
end
