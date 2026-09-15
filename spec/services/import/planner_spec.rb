# frozen_string_literal: true

# rubocop:disable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations

require 'rails_helper'

RSpec.describe Import::Planner do
  let(:organization) { create(:organization, name: 'Sunset Hotels') }

  describe '#initialize' do
    context 'when initialized' do
      it 'leaves roster unqueried' do
        create(:member, organization:, external_id: '1001', first_name: 'Maria',
                        last_name: 'Gomez', corporate_email: 'maria@example.com')

        planner = Import::Planner.new(organization)

        expect(planner.roster).to be_a(ActiveRecord::Relation)
        expect(planner.roster.klass).to eq(Member)
        expect(planner.roster).not_to be_loaded
      end
    end
  end

  describe '#plan' do
    context 'when employee has no membership or account' do
      it 'plans a new invitation' do
        csv = StringIO.new(aisha_active_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1004')

        expect(entry).to have_attributes(
          category: :new_invite,
          matched_member_id: nil
        )
        expect(entry.after).to include(
          external_id: '1004',
          corporate_email: 'aisha.bello@sunsethotels.com',
          status: 'active',
          invite_status: 'pending'
        )
      end
    end

    context 'when an existing employee has a new corporate email' do
      it 'plans an update entry' do
        member = create(:member, organization:, external_id: '1003', first_name: 'Robert',
                                 last_name: 'Chen', corporate_email: 'robert.c@oldmail.com',
                                 status: 'active')
        csv = StringIO.new(robert_new_email_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1003')

        expect(entry).to have_attributes(
          category: :update,
          matched_member_id: member.id
        )
        expect(entry.before).to include(corporate_email: 'robert.c@oldmail.com')
        expect(entry.after).to include(corporate_email: 'robert.chen@sunsethotels.com')
        expect(entry.attributes_to_apply).to eq(corporate_email: 'robert.chen@sunsethotels.com')
      end
    end

    context 'when an existing employee has no external id in database but has one in payroll' do
      it 'matches by corporate email and plans an update for external id' do
        member = create(:member, organization:, external_id: nil, first_name: 'Sam',
                                 last_name: 'Rivera', corporate_email: 'sam.rivera@sunsethotels.com',
                                 status: 'active')
        csv = StringIO.new(sam_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1005')

        expect(entry).to have_attributes(
          category: :update,
          matched_member_id: member.id
        )
        expect(entry.before[:external_id]).to be_nil
        expect(entry.after).to include(external_id: '1005')
        expect(entry.attributes_to_apply).to eq(external_id: '1005')
      end
    end

    context 'when employee appears in two property rows' do
      it 'produces one update entry' do
        member = create(:member, organization:, external_id: '1001', first_name: 'Maria',
                                 last_name: 'Gomez', corporate_email: 'maria@oldmail.com',
                                 status: 'active')
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entries = entries_for(plan, external_id: '1001')

        expect(entries.size).to eq(1)
        expect(entries.first).to have_attributes(
          category: :update,
          matched_member_id: member.id
        )
        expect(entries.first.source_rows).to contain_exactly(2, 6)
        expect(entries.first.attributes_to_apply).to eq(corporate_email: 'maria.gomez@sunsethotels.com')
      end
    end

    context 'when payroll explicitly reports termination' do
      it 'plans offboard termination' do
        member = create(:member, organization:, external_id: '1002', first_name: 'David',
                                 last_name: 'Okafor', status: 'active',
                                 corporate_email: 'david.okafor@sunsethotels.com')
        csv = StringIO.new(david_terminated_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1002')

        expect(entry).to have_attributes(
          category: :offboard_terminated,
          matched_member_id: member.id
        )
        expect(entry.before).to include(status: 'active')
        expect(entry.after).to include(status: 'terminated')
        expect(entry.source_rows).to contain_exactly(2)
      end
    end

    context 'when an employee is dropped from the snapshot' do
      it 'plans offboard for absent member' do
        member = create(:member, organization:, external_id: '1006', first_name: 'Nina',
                                 last_name: 'Patel', status: 'active',
                                 corporate_email: 'nina.patel@sunsethotels.com')
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1006')

        expect(employees.map(&:external_id)).not_to include('1006')
        expect(entry).to have_attributes(
          category: :offboard_absent,
          matched_member_id: member.id
        )
        expect(entry.before).to include(status: 'active')
        expect(entry.after).to include(status: 'terminated')
        expect(entry.source_rows).to be_empty
        expect(entry.reasons).to include(:absent_from_snapshot)
      end
    end

    context 'when payroll details already match the roster' do
      it 'plans an unchanged entry' do
        member = create(:member, organization:, external_id: '2001', first_name: 'John',
                                 last_name: 'Smith', status: 'active',
                                 corporate_email: 'john.smith@sunsethotels.com')
        create(:assignment, member: member, location_code: 'DT', role: 'member')
        csv = StringIO.new(john_unchanged_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '2001')

        expect(entry.category).to eq(:unchanged)
        expect(entry.attributes_to_apply).to be_empty
      end
    end

    context 'when an import has mixed employee outcomes' do
      it 'accounts for all rows and members' do
        robert = create(:member, organization:, external_id: '1003', first_name: 'Robert',
                                 last_name: 'Chen', status: 'active',
                                 corporate_email: 'robert.c@oldmail.com')
        maria = create(:member, organization:, external_id: '1001', first_name: 'Maria',
                                last_name: 'Gomez', status: 'active',
                                corporate_email: 'maria@oldmail.com')
        david = create(:member, organization:, external_id: '1002', first_name: 'David',
                                last_name: 'Okafor', status: 'active',
                                corporate_email: 'david.okafor@sunsethotels.com')
        nina = create(:member, organization:, external_id: '1006', first_name: 'Nina',
                               last_name: 'Patel', status: 'active',
                               corporate_email: 'nina.patel@sunsethotels.com')
        john = create(:member, organization:, external_id: '2001', first_name: 'John',
                               last_name: 'Smith', status: 'active',
                               corporate_email: 'john.smith@sunsethotels.com')
        create(:assignment, member: robert, location_code: 'DT', role: 'admin')
        create(:assignment, member: maria, location_code: 'DT', role: 'member')
        create(:assignment, member: maria, location_code: 'UP', role: 'member')
        create(:assignment, member: john, location_code: 'DT', role: 'member')
        roster = [robert, maria, david, nina, john]
        csv = StringIO.new(six_row_payroll_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(plan.records.size).to eq(6)
        expect(plan.counts).to eq(
          new_invite: 1,
          update: 2,
          offboard_terminated: 1,
          unchanged: 1,
          offboard_absent: 1
        )
        expect(plan.records.flat_map(&:source_rows)).to contain_exactly(2, 3, 4, 5, 6, 7)
        expect(plan.records.filter_map(&:matched_member_id)).to match_array(roster.map(&:id))
      end
    end

    context 'when plan is computed but not applied' do
      it 'does not modify roster data' do
        member = create(:member, organization:, external_id: '1003', first_name: 'Robert',
                                 last_name: 'Chen', status: 'active',
                                 corporate_email: 'robert.c@oldmail.com')
        create(:assignment, member: member, location_code: 'DT', role: 'admin')
        csv = StringIO.new(six_row_payroll_csv)
        before = persisted_roster_state

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        Import::Planner.new(organization).plan(employees)

        expect(persisted_roster_state).to eq(before)
      end
    end

    context 'when new employee has a global account' do
      it 'plans a new member with account' do
        user = create(:user, login_email: 'aisha.bello@sunsethotels.com',
                             personal_email: 'aisha@example.com')
        csv = StringIO.new(aisha_active_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(entry_for(plan, external_id: '1004')).to have_attributes(
          category: :new_with_account,
          user_id: user.id
        )
        expect(plan.invitation_actions).to be_empty
      end
    end

    context 'when employee belongs to another org' do
      it 'plans a new organization member' do
        other_organization = create(:organization, name: 'Other Hotels')
        create(:member, organization: other_organization, external_id: '1004',
                        corporate_email: 'aisha.bello@sunsethotels.com')
        csv = StringIO.new(aisha_active_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(entry_for(plan, external_id: '1004').category).to eq(:new_invite)
      end
    end

    context 'when two employees share the same name' do
      it 'matches each by external id' do
        first = create(:member, organization:, external_id: '1003', first_name: 'Robert',
                                last_name: 'Chen', corporate_email: 'robert.chen@sunsethotels.com')
        second = create(:member, organization:, external_id: '3007', first_name: 'Robert',
                                 last_name: 'Chen', corporate_email: 'r.chen@sunsethotels.com')
        csv = StringIO.new(two_roberts_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(entry_for(plan, external_id: '1003').matched_member_id).to eq(first.id)
        expect(entry_for(plan, external_id: '3007').matched_member_id).to eq(second.id)
      end
    end

    context 'when external id and email match different members' do
      it 'flags an identity conflict' do
        pending = create(:member, organization:, external_id: '1005', first_name: 'Sam',
                                  last_name: 'Rivera', corporate_email: 'srivera@sunsethotels.com',
                                  status: 'active', invite_status: 'pending', user: nil)
        accepted_user = create(:user)
        accepted = create(:member, organization:, external_id: nil, first_name: 'Sam',
                                   last_name: 'Rivera', status: 'active',
                                   corporate_email: 'sam.rivera@sunsethotels.com',
                                   invite_status: 'accepted', user: accepted_user)
        candidates = [pending, accepted]
        csv = StringIO.new(sam_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1005')

        expect(entry.category).to eq(:conflict)
        expect(entry.candidate_member_ids).to match_array(candidates.map(&:id))
        expect(plan.actionable_entries).to be_empty
        expect(plan.accounted_member_ids).to match_array(candidates.map(&:id))
      end
    end

    context 'when terminated employee returns active' do
      it 'plans an update with all file-owned changes' do
        member = create(:member, organization:, external_id: '1002', first_name: 'David',
                                 last_name: 'Okafor', status: 'terminated',
                                 corporate_email: 'david@oldmail.com')
        csv = StringIO.new(david_active_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '1002')

        expect(entry).to have_attributes(
          category: :update,
          matched_member_id: member.id
        )
        expect(entry.before).to include(status: 'terminated')
        expect(entry.after).to include(
          status: 'active',
          corporate_email: 'david.okafor@sunsethotels.com'
        )
        expect(entry.attributes_to_apply).to eq(
          corporate_email: 'david.okafor@sunsethotels.com',
          status: 'active'
        )
      end
    end

    context 'when payroll omits all assignment locations' do
      it 'plans an empty assignment list' do
        member = create(:member, organization:, external_id: '2001', first_name: 'John',
                                 last_name: 'Smith', status: 'active',
                                 corporate_email: 'john.smith@sunsethotels.com')
        create(:assignment, member:, location_code: 'DT', role: 'member')
        csv = StringIO.new(
          payroll_csv_for(
            ['2001,,Active,05/01/2026,John,Smith,john.smith@sunsethotels.com,john@example.com,no,555-0201']
          )
        )

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)
        entry = entry_for(plan, external_id: '2001')

        expect(entry.category).to eq(:update)
        expect(entry.after[:assignments]).to eq([])
      end
    end

    context 'when payroll adds a new assignment location' do
      it 'plans an update entry' do
        member = create(:member, organization:, external_id: '2001', first_name: 'John',
                                 last_name: 'Smith', status: 'active',
                                 corporate_email: 'john.smith@sunsethotels.com')
        create(:assignment, member: member, location_code: 'DT', role: 'admin')
        csv = StringIO.new(john_new_location_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(entry_for(plan, external_id: '2001').category).to eq(:update)
        expect(entry_for(plan, external_id: '2001').attributes_to_apply).to eq({})
      end
    end

    context 'when payroll locations already match the roster' do
      it 'plans an unchanged entry even with a different Duler role' do
        member = create(:member, organization:, external_id: '2001', first_name: 'John',
                                 last_name: 'Smith', status: 'active',
                                 corporate_email: 'john.smith@sunsethotels.com')
        create(:assignment, member: member, location_code: 'DT', role: 'admin')
        csv = StringIO.new(john_unchanged_csv)

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(entry_for(plan, external_id: '2001').category).to eq(:unchanged)
        expect(entry_for(plan, external_id: '2001').attributes_to_apply).to be_empty
      end
    end

    context 'when determining absence entries' do
      it 'queries absent active members' do
        create(:member, organization:, external_id: '1001', status: 'active')
        absent = create(:member, organization:, external_id: '1002', status: 'active')
        terminated = create(:member, organization:, external_id: '1003', status: 'terminated')
        rows = ['1001,DT,Active,03/01/2026,Maria,Gomez,maria.gomez@sunsethotels.com,maria@example.com,no,555-0101']
        csv = StringIO.new(payroll_csv_for(rows))

        employees = Import::Parsers::PayrollCsvParser.new.parse(csv)
        plan = Import::Planner.new(organization).plan(employees)

        expect(plan.records).to include(
          have_attributes(
            category: :offboard_absent,
            matched_member_id: absent.id
          )
        )
        expect(plan.records.map(&:matched_member_id)).not_to include(terminated.id)
      end
    end
  end

  def entry_for(plan, external_id:)
    entries_for(plan, external_id: external_id).sole
  end

  def entries_for(plan, external_id:)
    plan.records.select do |record|
      record.after[:external_id] == external_id || record.before[:external_id] == external_id
    end
  end

  def persisted_roster_state
    {
      members: Member.order(:id).map { |member| member.attributes.except('created_at', 'updated_at') },
      assignments: Assignment.order(:id).map { |assignment| assignment.attributes.except('created_at', 'updated_at') }
    }
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

  def aisha_active_csv
    payroll_csv_for(
      ['1004,UP,Active,04/15/2026,Aisha,Bello,aisha.bello@sunsethotels.com,aisha@example.com,no,555-0104']
    )
  end

  def robert_new_email_csv
    payroll_csv_for(
      ['1003,DT,Active,02/01/2026,Robert,Chen,robert.chen@sunsethotels.com,robert.chen@example.com,no,555-0103']
    )
  end

  def john_new_location_csv
    payroll_csv_for(
      [
        '2001,DT,Active,05/01/2026,John,Smith,john.smith@sunsethotels.com,john@example.com,no,555-0201',
        '2001,UP,Active,05/01/2026,John,Smith,john.smith@sunsethotels.com,john@example.com,no,555-0202'
      ]
    )
  end

  def david_terminated_csv
    payroll_csv_for(
      ['1002,DT,Terminated,01/01/2025,David,Okafor,david.okafor@sunsethotels.com,david@example.com,no,555-0102']
    )
  end

  def john_unchanged_csv
    payroll_csv_for(
      ['2001,DT,Active,05/01/2026,John,Smith,john.smith@sunsethotels.com,john@example.com,no,555-0201']
    )
  end

  def two_roberts_csv
    payroll_csv_for(
      [
        '1003,DT,Active,02/01/2026,Robert,Chen,robert.chen@sunsethotels.com,robert.chen@example.com,no,555-0103',
        '3007,DT,Active,02/01/2026,Robert,Chen,r.chen@sunsethotels.com,robert.other@example.com,no,555-0307'
      ]
    )
  end

  def sam_csv
    payroll_csv_for(
      ['1005,DT,Active,02/01/2026,Sam,Rivera,sam.rivera@sunsethotels.com,sam@example.com,no,555-0105']
    )
  end

  def david_active_csv
    payroll_csv_for(
      ['1002,DT,Active,01/01/2025,David,Okafor,david.okafor@sunsethotels.com,david@example.com,no,555-0102']
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
