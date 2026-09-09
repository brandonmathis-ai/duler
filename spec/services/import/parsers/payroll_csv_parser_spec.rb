# frozen_string_literal: true

# rubocop:disable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations

require 'rails_helper'

RSpec.describe Import::Parsers::PayrollCsvParser do
  describe '#parse' do
    context 'when CSV has multiple rows per person' do
      it 'returns canonical incoming employees' do
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)

        expect(employees).to be_an(Array)
        expect(employees.size).to eq(5)
        expect(employees).to all(be_a(Import::IncomingEmployee))
        expect(employees.map(&:external_id)).to contain_exactly('1001', '1002', '1003', '1004', '2001')
      end
    end

    context 'when parsing provider fields' do
      it 'maps fields and normalizes status' do
        row = '1003,dt,ACTIVE,02/01/2026,Jean-Luc,O’Connor,Jean-Luc.OConnor@Sunset.com,,no,555-0103'
        csv = StringIO.new(payroll_csv_for([row]))

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        employee = employees.sole

        expect(employee).to have_attributes(
          external_id: '1003',
          first_name: 'Jean-Luc',
          last_name: 'O’Connor',
          work_email: 'jean-luc.oconnor@sunset.com'
        )
        expect(employee.positions).to contain_exactly(
          have_attributes(location_code: 'DT', status: 'active')
        )
      end
    end

    context 'when person has nonadjacent rows' do
      it 'groups positions and source rows' do
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        maria = employees.find { |employee| employee.external_id == '1001' }

        expect(maria.positions).to contain_exactly(
          have_attributes(location_code: 'DT', status: 'active'),
          have_attributes(location_code: 'UP', status: 'active')
        )
        expect(maria.source_rows).to contain_exactly(2, 6)
      end
    end

    context 'when position is terminated' do
      it 'preserves terminated status' do
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        david = employees.find { |employee| employee.external_id == '1002' }

        expect(david.positions).to contain_exactly(
          have_attributes(location_code: 'DT', status: 'terminated')
        )
      end
    end

    context 'when fields contain surrounding whitespace' do
      it 'strips whitespace from all fields' do
        row = ' 1005 , DT , Active ,04/12/2026,  Sam  ,  Rivera  ,  sam.rivera@sunsethotels.com  ,,no,555-0105'
        csv = StringIO.new(payroll_csv_for([row]))

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        sam = employees.sole

        expect(sam).to have_attributes(
          external_id: '1005',
          first_name: 'Sam',
          last_name: 'Rivera',
          work_email: 'sam.rivera@sunsethotels.com'
        )
        expect(sam.positions).to contain_exactly(
          have_attributes(location_code: 'DT', status: 'active')
        )
      end
    end

    context 'when optional fields contain whitespace only' do
      it 'normalizes blank fields to nil' do
        row = '1007,   ,Active,07/01/2026,Priya,Nair,priya.nair@sunsethotels.com,,no,555-0107'
        csv = StringIO.new(payroll_csv_for([row]))

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        priya = employees.sole

        expect(priya.positions.sole.location_code).to be_nil
      end
    end
  end

  def six_row_payroll_csv
    payroll_csv_for(
      [
        '1001,DT,Active,03/01/2026,Maria,Gomez,maria.gomez@sunsethotels.com,maria.gomez@example.com,no,555-0101',
        '1004,UP,Active,04/15/2026,Aisha,Bello,aisha.bello@sunsethotels.com,aisha@example.com,no,555-0104',
        '1003,DT,Active,02/01/2026,Robert,Chen,robert.chen@sunsethotels.com,robert.chen@example.com,no,555-0103',
        '1002,DT,Terminated,01/01/2025,David,Okafor,david.okafor@sunsethotels.com,david@example.com,no,555-0102',
        '1001,UP,Active,03/01/2026,Maria,Gomez,maria.gomez@sunsethotels.com,maria.gomez@example.com,no,555-0101',
        '2001,DT,Active,05/01/2026,John,Smith,john.smith@sunsethotels.com,john@example.com,no,555-0201'
      ]
    )
  end

  def payroll_csv_for(rows)
    <<~CSV
      external_id,location_code,position_status,position_start_date,first_name,last_name,work_email,personal_email,use_personal_email_for_notification,home_phone
      #{rows.join("\n")}
    CSV
  end
end

# rubocop:enable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations
