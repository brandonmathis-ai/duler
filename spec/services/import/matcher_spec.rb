# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::Matcher do
  describe '#match' do
    it 'prefers the stable payroll external id over email or name' do
      match = Import::Matcher.new(roster_with_changed_email).match(changed_email_payroll_row)

      expect(match).to include(member: changed_email_member, match_key: 'external_id')
    end

    it 'requires admin review when the only possible match is a duplicate name' do
      match = described_class.new(roster_with_duplicate_names).match(name_only_payroll_row)

      expect(match).to include(category: :conflict)
    end
  end

  def changed_email_payroll_row
    {
      external_id: '1003',
      first_name: 'Robert',
      last_name: 'Chen',
      corporate_email: 'robert.chen@sunsethotels.com'
    }
  end

  def changed_email_member
    {
      membership_id: 'mbr_1003',
      external_id: '1003',
      corporate_email: 'old.email@sunsethotels.com',
      first_name: 'Robert',
      last_name: 'Chen'
    }
  end

  def roster_with_changed_email
    [changed_email_member]
  end

  def name_only_payroll_row
    {
      external_id: nil,
      first_name: 'Sam',
      last_name: 'Rivera',
      corporate_email: 'sam.rivera@sunsethotels.com'
    }
  end

  def roster_with_duplicate_names
    [
      first_sam_rivera_member,
      second_sam_rivera_member
    ]
  end

  def first_sam_rivera_member
    member_named_sam(
      'mbr_1005',
      '1005',
      'srivera@sunsethotels.com'
    )
  end

  def second_sam_rivera_member
    member_named_sam(
      'mbr_2005',
      '2005',
      'sam.rivera@example.com'
    )
  end

  def member_named_sam(membership_id, external_id, corporate_email)
    {
      membership_id: membership_id,
      external_id: external_id,
      corporate_email: corporate_email,
      first_name: 'Sam',
      last_name: 'Rivera'
    }
  end
end
