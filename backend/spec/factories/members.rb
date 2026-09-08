# frozen_string_literal: true

FactoryBot.define do
  factory :member do
    sequence(:external_id) { |number| (1000 + number).to_s }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    corporate_email { Faker::Internet.email(name: "#{first_name} #{last_name}", domain: 'sunsethotels.com') }
    status { 'active' }
    invite_status { 'pending' }
    user { nil }
  end
end
