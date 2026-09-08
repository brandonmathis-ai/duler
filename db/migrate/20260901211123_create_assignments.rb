# frozen_string_literal: true

class CreateAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :assignments do |t|
      t.references :member, null: false, foreign_key: true
      t.string :location_code
      t.string :role

      t.timestamps
    end
  end
end
