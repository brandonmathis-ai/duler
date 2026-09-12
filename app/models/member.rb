# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true
  has_many :assignments, dependent: :destroy
end
