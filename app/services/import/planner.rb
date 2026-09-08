# frozen_string_literal: true

module Import
  # Categorizes every canonical row (and every roster member) into a Plan.
  class Planner
    def plan(_canonical_rows, _roster)
      raise NotImplementedError, "#{self.class}#plan not yet implemented"
    end
  end
end
