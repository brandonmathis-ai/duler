# frozen_string_literal: true

module Import
  # Value object: the categorized import records plus their counts.
  class Plan
    attr_reader :records, :counts

    def initialize(records: [], counts: {})
      @records = records
      @counts = counts
    end
  end
end
