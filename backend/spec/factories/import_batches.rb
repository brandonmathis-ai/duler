# frozen_string_literal: true

FactoryBot.define do
  factory :import_batch do
    filename { 'MyString' }
    provider { 'MyString' }
    status { 'MyString' }
    counts { '' }
    plan { '' }
    applied_at { '2026-09-01 17:11:33' }
  end
end
