# frozen_string_literal: true

class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      t.string :filename
      t.string :provider
      t.string :status
      t.json :counts
      t.json :plan
      t.datetime :applied_at

      t.timestamps
    end
  end
end
