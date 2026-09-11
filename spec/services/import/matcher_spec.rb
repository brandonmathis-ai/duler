# frozen_string_literal: true

require 'rails_helper'

PayrollRow = Struct.new(
  :external_id,
  :first_name,
  :last_name,
  :work_email,
  :positions,
  :source_rows,
  :issues,
  keyword_init: true
)

RSpec.describe Import::Matcher do
  describe '#match' do
    it 'prefers the stable payroll external id over email' do
      match = described_class.new(roster_with_changed_email).match(changed_email_payroll_row)

      expect(match).to include(member: changed_email_member, match_key: 'external_id')
    end

    it 'matches by corporate email when external id is absent' do
      match = described_class.new(roster_with_legacy_member).match(legacy_member_payroll_row)

      expect(match).to include(member: legacy_member, match_key: 'corporate_email')
    end

    it 'flags an identity conflict when external id and corporate email match different members' do
      match = described_class.new(conflicting_roster).match(conflict_payroll_row)

      expect(match).to include(category: :conflict, candidates: conflicting_roster)
    end

    it 'treats employee as new when external id and email do not match, even if name matches' do
      match = described_class.new([first_sam_rivera_member]).match(new_employee_same_name_payroll_row)

      expect(match).to include(category: :new, member: nil, match_key: nil)
    end
  end

  def changed_email_payroll_row
    PayrollRow.new(
      external_id: '1003',
      first_name: 'Robert',
      last_name: 'Chen',
      work_email: 'robert.chen@sunsethotels.com',
      positions: [],
      source_rows: ['row-1'],
      issues: []
    )
  end

  def changed_email_member
    @changed_email_member ||= Member.new(
      external_id: '1003',
      corporate_email: 'old.email@sunsethotels.com',
      first_name: 'Robert',
      last_name: 'Chen'
    )
  end

  def roster_with_changed_email
    [changed_email_member]
  end

  def legacy_member_payroll_row
    PayrollRow.new(
      external_id: nil,
      first_name: 'Sam',
      last_name: 'Rivera',
      work_email: 'sam.rivera@sunsethotels.com',
      positions: [],
      source_rows: ['row-2'],
      issues: []
    )
  end

  def legacy_member
    @legacy_member ||= Member.new(
      external_id: nil,
      corporate_email: 'sam.rivera@sunsethotels.com',
      first_name: 'Sam',
      last_name: 'Rivera'
    )
  end

  def roster_with_legacy_member
    [legacy_member]
  end

  def conflict_payroll_row
    PayrollRow.new(
      external_id: '1005',
      first_name: 'Sam',
      last_name: 'Rivera',
      work_email: 'sam.rivera@sunsethotels.com',
      positions: [],
      source_rows: ['row-3'],
      issues: []
    )
  end

  def conflicting_roster
    [external_id_sam, email_only_sam]
  end

  def external_id_sam
    @external_id_sam ||= member_named_sam('1005', 'srivera@sunsethotels.com')
  end

  def email_only_sam
    @email_only_sam ||= member_named_sam(nil, 'sam.rivera@sunsethotels.com')
  end

  def new_employee_same_name_payroll_row
    PayrollRow.new(
      external_id: '9999',
      first_name: 'Sam',
      last_name: 'Rivera',
      work_email: 'sam.rivera.new@sunsethotels.com',
      positions: [],
      source_rows: ['row-4'],
      issues: []
    )
  end

  def first_sam_rivera_member
    @first_sam_rivera_member ||= member_named_sam('1005', 'srivera@sunsethotels.com')
  end

  def member_named_sam(external_id, corporate_email)
    Member.new(
      external_id: external_id,
      corporate_email: corporate_email,
      first_name: 'Sam',
      last_name: 'Rivera'
    )
  end
end
