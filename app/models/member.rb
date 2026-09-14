# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true
  has_many :assignments, dependent: :destroy

  enum :status, { active: 'active', terminated: 'terminated', inactive: 'inactive' }

  validates :external_id, uniqueness: { scope: :organization_id }, allow_nil: true

  scope :eligible_for_modification, -> { where.not(status: 'inactive') }
end
