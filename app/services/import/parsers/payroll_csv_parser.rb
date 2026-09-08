# frozen_string_literal: true

module Import
  IncomingEmployee = Data.define(
    :external_id,
    :first_name,
    :last_name,
    :corporate_email,
    :positions,
    :source_rows,
    :issues
  )

  IncomingPosition = Data.define(:location_code, :status, :source_row, :issues)

  module Parsers
    # Maps the payroll provider's CSV columns to canonical rows.
    class PayrollCsvParser
      VALID_POSITION_STATUSES = %w[active terminated].freeze

      def parse(io)
        grouped_rows = CSV.new(io, headers: true).each.with_index(2).group_by do |row, source_row|
          external_id = field(row, 'external_id')
          external_id.presence || "source_row:#{source_row}"
        end

        grouped_rows.values.map { |rows| incoming_employee_for(rows) }
      end

      private

      def incoming_employee_for(rows)
        first_row, = rows.first
        positions = rows.map { |row, source_row| incoming_position_for(row, source_row) }

        Import::IncomingEmployee.new(
          **person_attributes_for(first_row),
          positions: positions,
          source_rows: rows.map(&:second),
          issues: employee_issues_for(first_row, positions)
        )
      end

      def person_attributes_for(row)
        {
          external_id: field(row, 'external_id'),
          first_name: normalize_name(field(row, 'first_name')),
          last_name: normalize_name(field(row, 'last_name')),
          corporate_email: field(row, 'work_email', 'corporate_email')&.downcase
        }
      end

      def normalize_name(name)
        name&.tr('’‘`', "'''")
      end

      def incoming_position_for(row, source_row)
        status = field(row, 'position_status').to_s.downcase
        issues = []
        issues << :invalid_position_status unless VALID_POSITION_STATUSES.include?(status)

        Import::IncomingPosition.new(
          location_code: field(row, 'location_code')&.upcase,
          status: status,
          source_row: source_row,
          issues: issues
        )
      end

      def employee_issues_for(row, positions)
        issues = positions.flat_map(&:issues)
        issues << :missing_external_id if field(row, 'external_id').blank?
        issues.uniq
      end

      def field(row, *names)
        raw = names.filter_map { |name| row[name] }.first
        return if raw.blank?

        raw.strip.unicode_normalize.presence
      end
    end
  end
end
