# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Member do
  describe '#organization' do
    it 'requires an organization' do
      member = build(:member, organization: nil)

      member.validate

      expect(member.errors.of_kind?(:organization, :blank)).to be(true)
    end
  end
end
