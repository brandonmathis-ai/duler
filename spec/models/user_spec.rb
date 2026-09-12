# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe '#members' do
    it 'supports multiple memberships' do
      user = create(:user)
      first_member = create(:member, user: user)
      second_member = create(:member, user: user)

      expect(user.members).to contain_exactly(first_member, second_member)
    end

    it 'provides organizations' do
      user = create(:user)
      member = create(:member, user: user)

      expect(user.organizations).to contain_exactly(member.organization)
    end
  end
end
