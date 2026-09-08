# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :personal_email
      t.string :login_email

      t.timestamps
    end
  end
end
