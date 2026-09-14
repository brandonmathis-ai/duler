# frozen_string_literal: true

organization = Organization.find_or_create_by!(name: 'Sunset Hotels')
roster = JSON.parse(Rails.root.join('current-roster.json').read).fetch('members')

roster.each do |entry|
  user_attributes = entry['user']
  user = if user_attributes
           User.find_or_create_by!(login_email: entry['corporate_email']) do |record|
             record.personal_email = user_attributes['personal_email'].presence
           end
         end

  member = organization.members.find_or_initialize_by(
    external_id: entry['external_id'],
    corporate_email: entry['corporate_email']
  )
  member.assign_attributes(
    user:,
    first_name: entry['first_name'],
    last_name: entry['last_name'],
    status: entry['status'],
    invite_status: entry['invite_status']
  )
  member.save!

  entry.fetch('assignments').each do |assignment|
    member.assignments.find_or_create_by!(location_code: assignment['location_code']) do |record|
      record.role = assignment['role']
    end
  end
end

Rails.logger.info("Seeded #{organization.members.count} members for #{organization.name}.")
