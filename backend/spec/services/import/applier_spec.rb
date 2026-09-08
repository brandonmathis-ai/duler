# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::Applier do
  describe '#apply' do
    it 'terminates an absent member without deleting roster history' do
      member = create_active_absent_member

      described_class.new.apply(offboard_absent_plan(member.id))

      expect(Member.count).to eq(1)
      expect(member.reload.status).to eq('terminated')
    end

    it 'refreshes file-owned fields without overwriting Duler-owned assignments or roles' do
      member = create_robert_member
      create_downtown_admin_assignment_for(member)

      described_class.new.apply(email_update_plan(member.id))

      expect(member_state(member)).to eq(['robert.chen@sunsethotels.com', 'DT', 'admin'])
    end

    it 'is safe to re-run the same empty plan without creating duplicate members' do
      expect 2.times { described_class.new.apply(empty_plan) }.not_to change(Member, :count)
    end
  end

  def create_active_absent_member
    create(
      :member,
      external_id: '1006',
      status: 'active'
    )
  end

  def create_robert_member
    create(
      :member,
      external_id: '1003',
      corporate_email: 'robert.c@oldmail.com'
    )
  end

  def create_downtown_admin_assignment_for(member)
    create(
      :assignment,
      member: member,
      location_code: 'DT',
      role: 'admin'
    )
  end

  def offboard_absent_plan(member_id)
    plan_payload(
      records: [offboard_absent_record(member_id)],
      counts: { offboard_absent: 1 }
    )
  end

  def email_update_plan(member_id)
    plan_payload(
      records: [email_update_record(member_id)],
      counts: { update: 1 }
    )
  end

  def empty_plan
    plan_payload(records: [], counts: { unchanged: 1 })
  end

  def plan_payload(records:, counts:)
    Struct.new(
      :records,
      :counts,
      keyword_init: true
    ).new(records: records, counts: counts)
  end

  def offboard_absent_record(member_id)
    {
      category: :offboard_absent,
      match_key: 'external_id:1006',
      matched_member_id: member_id,
      after: { status: 'terminated' }
    }
  end

  def email_update_record(member_id)
    {
      category: :update,
      match_key: 'external_id:1003',
      matched_member_id: member_id,
      after: { corporate_email: 'robert.chen@sunsethotels.com' }
    }
  end

  def member_state(member)
    member.reload
    assignment = member.assignments.sole

    [member.corporate_email, assignment.location_code, assignment.role]
  end
end
