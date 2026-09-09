# frozen_string_literal: true

# rubocop:disable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations, Metrics/MethodLength

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe Import::Applier do
  describe '#apply' do
    context 'with an approved mixed plan' do
      it 'terminates payroll-terminated members' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        expect(roster[:david].reload.status).to eq('terminated')
      end

      it 'terminates members absent from file' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        expect(roster[:absent].reload.status).to eq('terminated')
      end

      it 'creates pending invites for new hires' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        aisha = Member.find_by!(external_id: '1004')
        expect(aisha).to have_attributes(
          first_name: 'Aisha',
          last_name: 'Bello',
          corporate_email: 'aisha.bello@sunsethotels.com',
          status: 'active',
          invite_status: 'pending',
          user_id: nil
        )
      end

      it 'creates members linked to known users' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        sam = Member.find_by!(external_id: '1005')
        expect(sam).to have_attributes(
          corporate_email: 'sam.rivera@sunsethotels.com',
          invite_status: 'accepted',
          user_id: roster[:sam_user].id
        )
      end

      it 'applies file-owned attribute updates' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        robert = roster[:robert].reload
        expect(robert.corporate_email).to eq('robert.chen@sunsethotels.com')
        expect(robert.first_name).to eq('Robert')
      end

      it 'preserves duler-owned assignments' do
        roster = seed_roster
        create(:assignment, member: roster[:robert], location_code: 'DT', role: 'admin')

        Import::Applier.new.apply(update_plan(roster))

        assignment = roster[:robert].assignments.reload.sole
        expect(assignment).to have_attributes(location_code: 'DT', role: 'admin')
      end

      it 'creates assignments not yet stored' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        expect(assignment_state(roster[:maria])).to contain_exactly(%w[DT member], %w[UP member])
      end

      it 'adds new locations alongside existing ones' do
        roster = seed_roster
        create(:assignment, member: roster[:maria], location_code: 'DT', role: 'member')

        Import::Applier.new.apply(update_plan(roster))

        expect(assignment_state(roster[:maria])).to contain_exactly(%w[DT member], %w[UP member])
      end

      it 'skips unresolved identity conflicts' do
        roster = seed_roster

        Import::Applier.new.apply(update_plan(roster))

        frank = roster[:frank].reload
        priya = roster[:priya].reload
        expect(frank).to have_attributes(first_name: 'Frank', corporate_email: 'frank.w@oldmail.com')
        expect(priya).to have_attributes(first_name: 'Priya', external_id: '1099')
      end

      it 'adds only the two new members' do
        roster = seed_roster
        plan = update_plan(roster)

        expect { Import::Applier.new.apply(plan) }.to change(Member, :count).by(2)
      end

      it 'is idempotent when re-applied' do
        roster = seed_roster
        plan = update_plan(roster)
        Import::Applier.new.apply(plan)

        expect { Import::Applier.new.apply(plan) }.not_to change(Member, :count)
      end
    end

    context 'when the plan is not approved' do
      it 'raises and writes nothing' do
        roster = seed_roster
        plan = update_plan(roster, approved: false)

        expect { Import::Applier.new.apply(plan) }
          .to raise_error(Import::Applier::UnapprovedPlanError)
          .and not_change(Member, :count)
      end
    end
  end

  def seed_roster
    {
      maria: create(:member, external_id: '1001', first_name: 'Maria', last_name: 'Gomez',
                             corporate_email: 'maria.gomez@sunsethotels.com', status: 'active'),
      david: create(:member, external_id: '1002', first_name: 'David', last_name: 'Okafor',
                             corporate_email: 'david.okafor@sunsethotels.com', status: 'active'),
      absent: create(:member, external_id: '1006', first_name: 'Lena', last_name: 'Park',
                              corporate_email: 'lena.park@sunsethotels.com', status: 'active'),
      robert: create(:member, external_id: '1003', first_name: 'Robert', last_name: 'Chen',
                              corporate_email: 'robert.c@oldmail.com', status: 'active'),
      frank: create(:member, external_id: '1007', first_name: 'Frank', last_name: 'Wright',
                             corporate_email: 'frank.w@oldmail.com', status: 'active'),
      priya: create(:member, external_id: '1099', first_name: 'Priya', last_name: 'Nair',
                             corporate_email: 'priya.nair@sunsethotels.com', status: 'active'),
      sam_user: create(:user, first_name: 'Sam', last_name: 'Rivera')
    }
  end

  def assignment_state(member)
    member.assignments.reload.order(:location_code).map { |assignment| [assignment.location_code, assignment.role] }
  end

  def update_plan(roster, approved: true)
    plan = Import::Plan.new(records: mixed_entries(roster))
    approved ? plan.approve! : plan
  end

  def mixed_entries(roster)
    [
      new_invite_entry,
      new_with_account_entry(roster[:sam_user]),
      update_entry(roster[:robert]),
      new_assignment_entry(roster[:maria]),
      offboard_terminated_entry(roster[:david]),
      offboard_absent_entry(roster[:absent]),
      conflict_entry(roster[:frank], roster[:priya])
    ]
  end

  def new_invite_entry
    Import::Plan::Entry.new(
      category: :new_invite,
      match_key: 'external_id:1004',
      after: {
        external_id: '1004', first_name: 'Aisha', last_name: 'Bello',
        corporate_email: 'aisha.bello@sunsethotels.com', status: 'active',
        invite_status: 'pending'
      }
    )
  end

  def new_with_account_entry(user)
    Import::Plan::Entry.new(
      category: :new_with_account,
      match_key: 'external_id:1005',
      user_id: user.id,
      after: {
        external_id: '1005', first_name: 'Sam', last_name: 'Rivera',
        corporate_email: 'sam.rivera@sunsethotels.com', status: 'active',
        invite_status: 'accepted'
      }
    )
  end

  def update_entry(member)
    Import::Plan::Entry.new(
      category: :update,
      match_key: 'external_id:1003',
      matched_member_id: member.id,
      before: { corporate_email: 'robert.c@oldmail.com' },
      after: { corporate_email: 'robert.chen@sunsethotels.com' }
    )
  end

  def new_assignment_entry(member)
    Import::Plan::Entry.new(
      category: :update,
      match_key: 'external_id:1001',
      matched_member_id: member.id,
      before: {},
      after: {
        assignments: [{ location_code: 'DT', role: 'member' }, { location_code: 'UP', role: 'member' }]
      }
    )
  end

  def offboard_terminated_entry(member)
    Import::Plan::Entry.new(
      category: :offboard_terminated,
      match_key: 'external_id:1002',
      matched_member_id: member.id,
      before: { status: 'active' },
      after: { status: 'terminated' }
    )
  end

  def offboard_absent_entry(member)
    Import::Plan::Entry.new(
      category: :offboard_absent,
      match_key: 'external_id:1006',
      matched_member_id: member.id,
      before: { status: 'active' },
      after: { status: 'terminated' },
      reasons: [:absent_from_snapshot]
    )
  end

  def conflict_entry(frank, priya)
    Import::Plan::Entry.new(
      category: :conflict,
      match_key: 'external_id:1007',
      candidate_member_ids: [frank.id, priya.id],
      after: {
        external_id: '1007', first_name: 'Priya', last_name: 'Nair',
        corporate_email: 'priya.nair@sunsethotels.com', status: 'active'
      },
      reasons: [:identity_conflict]
    )
  end
end

# rubocop:enable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations, Metrics/MethodLength
