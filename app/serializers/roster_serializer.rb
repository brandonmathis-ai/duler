# frozen_string_literal: true

# Renders the roster in the shape the admin UI consumes: one entry per member,
# with the person's login account and their per-property assignments inlined.
class RosterSerializer
  def initialize(members)
    @members = members
  end

  def as_json(*)
    { members: @members.map { |member| member_json(member) } }
  end

  private

  def member_json(member)
    person_json(member).merge(
      user: user_json(member.user),
      assignments: member.assignments.map { |assignment| assignment_json(assignment) }
    )
  end

  def person_json(member)
    {
      membership_id: "mbr_#{member.id}",
      external_id: member.external_id,
      corporate_email: member.corporate_email,
      first_name: member.first_name,
      last_name: member.last_name,
      status: member.status,
      invite_status: member.invite_status
    }
  end

  def user_json(user)
    return if user.nil?

    { id: "usr_#{user.id}", personal_email: user.personal_email.to_s }
  end

  def assignment_json(assignment)
    { location_code: assignment.location_code, role: assignment.role }
  end
end
