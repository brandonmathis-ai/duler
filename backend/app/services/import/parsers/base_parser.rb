# frozen_string_literal: true

module Import
  module Parsers
    # Canonical row contract that every provider-specific parser must emit.
    class BaseParser
      def parse(_io)
        raise NotImplementedError, "#{self.class} must implement #parse"
      end
    end
  end
end
