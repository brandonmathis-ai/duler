# frozen_string_literal: true

FactoryBot.define do
  factory :import_record do
    transient do
      external_id { Faker::Number.unique.number(digits: 4).to_s }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      corporate_email { Faker::Internet.email(name: "#{first_name} #{last_name}", domain: 'sunsethotels.com') }
    end

    import_batch
    category { 'new_invite' }
    match_key { "external_id:#{external_id}" }
    matched_member_id { nil }
    before { {} }
    after do
      {
        external_id: external_id,
        first_name: first_name,
        last_name: last_name,
        corporate_email: corporate_email
      }
    end
    unprocessable_reason { nil }
  end
end
