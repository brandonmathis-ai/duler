# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::Planner do
  describe '#plan' do
    it 'accounts for every roster member and import row in documented categories' do
      plan = described_class.new.plan(
        mixed_payroll_rows,
        existing_roster
      )

      expect(plan.counts).to include(expected_mixed_counts)
    end

    it 'keeps one person with multiple property rows as one planned member change' do
      plan = plan_for_maria_multi_property_rows

      expect(maria_assignment_locations(plan)).to contain_exactly('DT', 'UP')
    end

    it 'plans a membership creation without an invite when the person already has a global user account' do
      create_maria_user

      plan = plan_for_maria_account_row

      expect(plan.counts).to include(new_with_account: 1)
    end
  end

  def plan_for_maria_multi_property_rows
    described_class.new.plan(
      maria_multi_property_rows,
      []
    )
  end

  def plan_for_maria_account_row
    described_class.new.plan(
      maria_account_row,
      []
    )
  end

  def create_maria_user
    create(
      :user,
      login_email: 'maria.gomez@sunsethotels.com'
    )
  end

  def existing_roster
    [
      john_smith_roster_member,
      robert_chen_roster_member,
      nina_patel_roster_member,
      first_sam_rivera_roster_member,
      second_sam_rivera_roster_member
    ]
  end

  def mixed_payroll_rows
    [
      john_smith_payroll_row,
      robert_chen_payroll_row,
      omar_diaz_terminated_payroll_row,
      maria_gomez_downtown_payroll_row,
      maria_gomez_uptown_payroll_row,
      priya_nair_unprocessable_payroll_row,
      sam_rivera_payroll_row
    ]
  end

  def maria_multi_property_rows
    [
      maria_gomez_downtown_payroll_row,
      maria_gomez_uptown_payroll_row
    ]
  end

  def maria_account_row
    [
      payroll_row(
        '4001',
        'Maria',
        'Gomez',
        'maria.gomez@sunsethotels.com'
      )
    ]
  end

  def expected_mixed_counts
    {
      unchanged: 1,
      update: 1,
      offboard_terminated: 1,
      offboard_absent: 1,
      new_invite: 1,
      conflict: 1,
      unprocessable: 1
    }
  end

  def roster_member(membership_id, external_id, corporate_email, first_name, last_name)
    {
      membership_id: membership_id,
      external_id: external_id,
      corporate_email: corporate_email,
      first_name: first_name,
      last_name: last_name,
      status: 'active',
      invite_status: 'accepted',
      assignments: [{ location_code: 'DT', role: 'member' }]
    }
  end

  def john_smith_roster_member
    roster_member(
      'mbr_2001',
      '2001',
      'john.smith@sunsethotels.com',
      'John',
      'Smith'
    )
  end

  def robert_chen_roster_member
    roster_member(
      'mbr_1003',
      '1003',
      'robert.c@oldmail.com',
      'Robert',
      'Chen'
    )
  end

  def nina_patel_roster_member
    roster_member(
      'mbr_1006',
      '1006',
      'nina.patel@sunsethotels.com',
      'Nina',
      'Patel'
    )
  end

  def first_sam_rivera_roster_member
    roster_member(
      'mbr_1005',
      '1005',
      'srivera@sunsethotels.com',
      'Sam',
      'Rivera'
    )
  end

  def second_sam_rivera_roster_member
    roster_member(
      'mbr_2005',
      nil,
      'sam.rivera@sunsethotels.com',
      'Sam',
      'Rivera'
    )
  end

  def payroll_row(external_id, first_name, last_name, corporate_email, overrides = {})
    {
      external_id: external_id,
      location_code: 'DT',
      position_status: 'Active',
      first_name: first_name,
      last_name: last_name,
      corporate_email: corporate_email
    }.merge(overrides)
  end

  def john_smith_payroll_row
    payroll_row(
      '2001',
      'John',
      'Smith',
      'john.smith@sunsethotels.com'
    )
  end

  def robert_chen_payroll_row
    payroll_row(
      '1003',
      'Robert',
      'Chen',
      'robert.chen@sunsethotels.com'
    )
  end

  def omar_diaz_terminated_payroll_row
    payroll_row(
      '1002',
      'Omar',
      'Diaz',
      'omar.diaz@sunsethotels.com',
      position_status: 'Terminated'
    )
  end

  def maria_gomez_downtown_payroll_row
    payroll_row(
      '1001',
      'Maria',
      'Gomez',
      'maria.gomez@sunsethotels.com',
      location_code: 'DT'
    )
  end

  def maria_gomez_uptown_payroll_row
    payroll_row(
      '1001',
      'Maria',
      'Gomez',
      'maria.gomez@sunsethotels.com',
      location_code: 'UP'
    )
  end

  def priya_nair_unprocessable_payroll_row
    payroll_row(
      '1007',
      'Priya',
      'Nair',
      'priya.nair@sunsethotels.com',
      location_code: ''
    )
  end

  def sam_rivera_payroll_row
    payroll_row(
      '1005',
      'Sam',
      'Rivera',
      'sam.rivera@sunsethotels.com'
    )
  end

  def maria_assignment_locations(plan)
    new_invite_record_for(
      plan,
      'external_id:1001'
    )[:after][:assignments].pluck(:location_code)
  end

  def new_invite_record_for(plan, match_key)
    plan.records.find do |record|
      record[:category] == :new_invite && record[:match_key] == match_key
    end
  end
end
