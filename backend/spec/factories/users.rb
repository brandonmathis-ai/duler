# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    personal_email { 'MyString' }
    login_email { 'MyString' }
  end
end
