# frozen_string_literal: true

class ImportBatch < ApplicationRecord
  has_many :import_records, dependent: :destroy
end
