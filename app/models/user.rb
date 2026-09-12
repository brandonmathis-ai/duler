# frozen_string_literal: true

class User < ApplicationRecord
  has_many :members, dependent: :nullify
  has_many :organizations, through: :members
end
