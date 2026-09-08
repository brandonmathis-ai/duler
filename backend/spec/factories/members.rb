# frozen_string_literal: true

FactoryBot.define do
  factory :member do
    external_id { 'MyString' }
    corporate_email { 'MyString' }
    first_name { 'MyString' }
    last_name { 'MyString' }
    status { 'MyString' }
    invite_status { 'MyString' }
    user { nil }
  end
end
