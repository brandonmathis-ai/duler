# frozen_string_literal: true

FactoryBot.define do
  factory :import_batch do
    filename { "payroll-#{Faker::Date.backward(days: 30).strftime('%Y-%m-%d')}.csv" }
    provider { 'payroll_csv' }
    status { 'planned' }
    counts { {} }
    plan { [] }
    applied_at { nil }
  end
end
