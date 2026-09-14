# frozen_string_literal: true

def seed_identity_for(entry)
  if entry['external_id'].present?
    { external_id: entry['external_id'] }
  else
    { corporate_email: entry['corporate_email'] }
  end
end

def seed_user_for(entry)
  user_attributes = entry['user']
  return unless user_attributes

  User.create!(
    login_email: entry['corporate_email'],
    personal_email: user_attributes['personal_email'].presence
  )
end

def seed_member_attributes(entry)
  {
    user: seed_user_for(entry),
    corporate_email: entry['corporate_email'],
    first_name: entry['first_name'],
    last_name: entry['last_name'],
    status: entry['status'],
    invite_status: entry['invite_status']
  }
end

def seed_member_for(organization, entry)
  organization.members.create!(seed_identity_for(entry).merge(seed_member_attributes(entry)))
end

def ensure_empty_database!
  return unless [Assignment, ImportBatch, ImportRecord, Member, Organization, User].any?(&:exists?)

  raise <<~MESSAGE.squish
    Cannot run seeds because the database already contains data. If you just ran db:prepare or db:reset,
    the sample roster may already be seeded. To start over, run bin/rails db:reset once; do not run
    db:seed again afterward.
  MESSAGE
end

ensure_empty_database!

organization = Organization.create!(name: 'Sunset Hotels')
roster = JSON.parse(Rails.root.join('current-roster.json').read).fetch('members')

roster.each do |entry|
  member = seed_member_for(organization, entry)
  entry.fetch('assignments').each do |assignment|
    member.assignments.create!(
      location_code: assignment['location_code'],
      role: assignment['role']
    )
  end
end

Rails.logger.info("Seeded #{organization.members.count} members for #{organization.name}.")
