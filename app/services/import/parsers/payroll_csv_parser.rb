# frozen_string_literal: true

module Import
  IncomingEmployee = Data.define(
    :external_id,
    :first_name,
    :last_name,
    :work_email,
    :positions,
    :source_rows
  )

  IncomingPosition = Data.define(:location_code, :status, :source_row)

  module Parsers
    # Maps the payroll provider's CSV columns to canonical rows.
    class PayrollCsvParser
      class ParseError < StandardError; end

      VALID_POSITION_STATUSES = %w[active terminated].freeze

      def parse(io)
        grouped_rows = Hash.new { |hash, key| hash[key] = [] }
        source_row = 1

        # Streams the CSV row-by-row
        CSV.new(utf8_io(io), headers: true).each do |row|
          source_row += 1
          next if blank_row?(row)

          validate_row!(row, source_row)
          grouped_rows[field(row, 'external_id')] << [row, source_row]
        end

        grouped_rows.values.map { |rows| incoming_employee_for(rows) }
      end

      private

      def validate_row!(row, source_row)
        raise ParseError, "missing external_id on row #{source_row}" if field(row, 'external_id').blank?

        status = field(row, 'position_status').to_s.downcase
        return if VALID_POSITION_STATUSES.include?(status)

        raise ParseError, "invalid position_status '#{status}' on row #{source_row}"
      end

      def utf8_io(io)
        io.set_encoding(Encoding::UTF_8)
        io
      end

      # Trailing newlines and separator rows carry no employee at all, so they
      # are dropped rather than reported as unprocessable.
      def blank_row?(row)
        row.fields.all?(&:blank?)
      end

      def incoming_employee_for(rows)
        first_row, = rows.first
        positions = rows.map { |row, source_row| incoming_position_for(row, source_row) }

        Import::IncomingEmployee.new(
          **person_attributes_for(first_row),
          positions: positions,
          source_rows: rows.map(&:second)
        )
      end

      def person_attributes_for(row)
        {
          external_id: field(row, 'external_id'),
          first_name: field(row, 'first_name'),
          last_name: field(row, 'last_name'),
          work_email: field(row, 'work_email')&.downcase
        }
      end

      def incoming_position_for(row, source_row)
        status = field(row, 'position_status').to_s.downcase

        Import::IncomingPosition.new(
          location_code: field(row, 'location_code')&.upcase,
          status: status,
          source_row: source_row
        )
      end

      def field(row, *names)
        raw = names.filter_map { |name| row[name] }.first
        return if raw.blank?

        raw.strip.unicode_normalize.presence
      end
    end
  end
end
