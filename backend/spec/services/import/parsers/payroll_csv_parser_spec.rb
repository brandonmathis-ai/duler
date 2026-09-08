# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::Parsers::PayrollCsvParser do
  describe '#parse' do
    it 'maps a current payroll staff row into one canonical row' do
      canonical_rows = described_class.new.parse(StringIO.new(current_staff_csv))

      expect(canonical_rows).to contain_exactly(a_hash_including(current_staff_row))
    end

    it 'keeps an inactive payroll row explicit in the canonical data' do
      canonical_rows = described_class.new.parse(StringIO.new(terminated_staff_csv))

      expect(canonical_rows).to contain_exactly(a_hash_including(terminated_staff_row))
    end
  end

  def current_staff_csv
    payroll_csv_for(
      '1001,DT,Active,03/01/2026,Maria,Gomez,maria.gomez@sunsethotels.com,maria.gomez@example.com,no,555-0101'
    )
  end

  def terminated_staff_csv
    payroll_csv_for(
      '1002,UP,Terminated,02/15/2026,Nina,Patel,nina.patel@sunsethotels.com,nina.patel@example.com,no,555-0102'
    )
  end

  def payroll_csv_for(row)
    <<~CSV
      external_id,location_code,position_status,position_start_date,first_name,last_name,work_email,personal_email,use_personal_email_for_notification,home_phone
      #{row}
    CSV
  end

  def current_staff_row
    {
      external_id: '1001',
      location_code: 'DT',
      position_status: 'active',
      first_name: 'Maria',
      last_name: 'Gomez',
      corporate_email: 'maria.gomez@sunsethotels.com'
    }
  end

  def terminated_staff_row
    {
      external_id: '1002',
      location_code: 'UP',
      position_status: 'terminated',
      first_name: 'Nina',
      last_name: 'Patel',
      corporate_email: 'nina.patel@sunsethotels.com'
    }
  end
end
