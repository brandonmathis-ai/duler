# frozen_string_literal: true

FactoryBot.define do
  factory :import_record do
    import_batch { nil }
    category { 'MyString' }
    match_key { 'MyString' }
    matched_member_id { 'MyString' }
    before { '' }
    after { '' }
    unprocessable_reason { 'MyString' }
  end
end
