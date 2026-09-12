# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :members, dependent: :restrict_with_exception
  has_many :users, through: :members

  validates :name, presence: true
end
