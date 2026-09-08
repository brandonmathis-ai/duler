# frozen_string_literal: true

class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.string :external_id
      t.string :corporate_email
      t.string :first_name
      t.string :last_name
      t.string :status
      t.string :invite_status
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :members, :external_id
    add_index :members, :corporate_email
  end
end
