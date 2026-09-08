# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    transient do
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
    end

    personal_email { Faker::Internet.email(name: "#{first_name} #{last_name}", domain: 'example.com') }
    login_email { Faker::Internet.email(name: "#{first_name} #{last_name}", domain: 'sunsethotels.com') }
  end
end
