# frozen_string_literal: true

class ImportRecord < ApplicationRecord
  belongs_to :import_batch
end
