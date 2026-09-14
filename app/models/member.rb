# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true
  has_many :assignments, dependent: :destroy

  enum :status, { active: 'active', terminated: 'terminated', inactive: 'inactive' }

  scope :eligible_for_modification, -> { where.not(status: 'inactive') }
end
