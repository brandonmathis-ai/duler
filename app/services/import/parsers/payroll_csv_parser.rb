# frozen_string_literal: true

module Import
  module Parsers
    # Maps the payroll provider's CSV columns to canonical rows.
    class PayrollCsvParser < BaseParser
      def parse(_io)
        raise NotImplementedError, "#{self.class}#parse not yet implemented"
      end
    end
  end
end
