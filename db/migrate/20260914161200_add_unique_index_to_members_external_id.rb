# frozen_string_literal: true

class AddUniqueIndexToMembersExternalId < ActiveRecord::Migration[8.0]
  def change
    remove_index :members, :external_id
    add_index :members, %i[organization_id external_id], unique: true, where: 'external_id IS NOT NULL'
  end
end
