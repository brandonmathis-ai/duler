# frozen_string_literal: true

class AddOrganizationToMembers < ActiveRecord::Migration[8.1]
  def change
    # No existing member rows require a transitional default or backfill.
    # rubocop:disable-next Rails/NotNullColumn
    add_reference :members, :organization, null: false, foreign_key: true
    add_index :members, %i[organization_id user_id],
              unique: true,
              where: 'user_id IS NOT NULL'
  end
end
