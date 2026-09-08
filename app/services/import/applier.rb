# frozen_string_literal: true

module Import
  # Applies an approved Plan to the database. Thin and idempotent.
  class Applier
    def apply(_plan)
      raise NotImplementedError, "#{self.class}#apply not yet implemented"
    end
  end
end
