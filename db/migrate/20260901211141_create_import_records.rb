# frozen_string_literal: true

class CreateImportRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :import_records do |t|
      t.references :import_batch, null: false, foreign_key: true
      t.string :category
      t.string :match_key
      t.string :matched_member_id
      t.json :before
      t.json :after
      t.string :unprocessable_reason

      t.timestamps
    end

    add_index :import_records, :category
  end
end
