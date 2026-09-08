# frozen_string_literal: true

FactoryBot.define do
  factory :assignment do
    member
    location_code { Faker::Address.unique.state_abbr }
    role { Faker::Job.position.downcase }
  end
end
