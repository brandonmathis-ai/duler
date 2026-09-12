# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

# End-to-end exercise of the brief's scenario: the roster shipped in
# current-roster.json, one night of sample-import.csv, and the roster the API
# serves once the resulting plan is applied.
RSpec.describe 'Payroll import flow', type: :request do
  it 'plans every roster member and every file row' do
    seed_roster_from_fixture

    plan = Import::Planner.new(organization).plan(parse_sample_import)

    expect(plan.counts).to eq(
      new_invite: 3,
      offboard_terminated: 1,
      update: 1,
      conflict: 1,
      unchanged: 7,
      offboard_absent: 1
    )
  end

  it 'categorizes each file row by external id' do
    seed_roster_from_fixture

    plan = Import::Planner.new(organization).plan(parse_sample_import)
    categories = plan.records.to_h { |record| [record.match_key, record.category] }

    expect(categories).to eq(
      'external_id:1001' => :new_invite,
      'external_id:1002' => :offboard_terminated,
      'external_id:1003' => :update,
      'external_id:1004' => :new_invite,
      'external_id:1005' => :conflict,
      'external_id:1006' => :offboard_absent,
      'external_id:1007' => :new_invite,
      'external_id:2001' => :unchanged,
      'external_id:2002' => :unchanged,
      'external_id:2003' => :unchanged,
      'external_id:2004' => :unchanged,
      'external_id:2005' => :unchanged,
      'external_id:2006' => :unchanged,
      'external_id:3007' => :unchanged
    )
  end

  it 'serves the fixture roster before the import' do
    seed_roster_from_fixture

    get '/api/roster'

    expect(normalize(response.parsed_body['members'])).to match_array(
      normalize(fixture_roster['members'])
    )
  end

  it 'leaves the roster untouched while only planning' do
    seed_roster_from_fixture
    before_body = (get '/api/roster') && response.parsed_body

    Import::Planner.new(organization).plan(parse_sample_import)
    get '/api/roster'

    expect(response.parsed_body).to eq(before_body)
  end

  it 'serves the reconciled roster after applying' do
    seed_roster_from_fixture

    apply_sample_import
    get '/api/roster'

    expect(normalize(response.parsed_body['members'])).to match_array(expected_roster_after)
  end

  it 'keeps both conflicting Sam Rivera members untouched' do
    seed_roster_from_fixture

    apply_sample_import
    get '/api/roster'
    samples = response.parsed_body['members'].select { |member| member['last_name'] == 'Rivera' }

    expect(samples).to contain_exactly(
      a_hash_including('external_id' => '1005', 'corporate_email' => 'srivera@sunsethotels.com',
                       'status' => 'active', 'invite_status' => 'pending', 'user' => nil),
      a_hash_including('external_id' => nil, 'corporate_email' => 'sam.rivera@sunsethotels.com',
                       'status' => 'active', 'invite_status' => 'accepted')
    )
  end

  it 'never deletes a departed member' do
    seed_roster_from_fixture

    apply_sample_import
    get '/api/roster'
    departed = response.parsed_body['members'].select { |member| member['status'] == 'terminated' }

    expect(departed.pluck('external_id')).to match_array(%w[1002 1006])
  end

  it 'stays idempotent on a re-run' do
    seed_roster_from_fixture
    apply_sample_import
    get '/api/roster'
    first_run = normalize(response.parsed_body['members'])

    apply_sample_import
    get '/api/roster'

    expect(normalize(response.parsed_body['members'])).to match_array(first_run)
  end

  # The roster before the import, exactly as shipped with the brief.
  def fixture_roster
    JSON.parse(Rails.root.join('current-roster.json').read)
  end

  def seed_roster_from_fixture
    organization
    fixture_roster['members'].each { |member| seed_member(member) }
  end

  def seed_member(member)
    user = member['user'] && User.create!(personal_email: member['user']['personal_email'])
    record = Member.create!(
      organization: organization,
      user: user,
      **member.slice('external_id', 'corporate_email', 'first_name', 'last_name',
                     'status', 'invite_status').symbolize_keys
    )
    member['assignments'].each do |assignment|
      record.assignments.create!(assignment.slice('location_code', 'role'))
    end
  end

  def parse_sample_import
    Rails.root.join('sample-import.csv').open do |file|
      Import::Parsers::PayrollCsvParser.new.parse(file)
    end
  end

  def apply_sample_import
    plan = Import::Planner.new(organization).plan(parse_sample_import)

    Import::Applier.new.apply(plan.approve!)
  end

  def organization
    @organization ||= Organization.create!(name: 'Sunset Hotels')
  end

  # Database ids are generated, so members are compared on their natural key
  # (corporate email) with the opaque ids dropped. Account linkage is still
  # asserted through the user's personal email.
  def normalize(members)
    members.map do |member|
      member.except('membership_id').merge('user' => member['user']&.except('id'))
    end
  end

  # Members the import did not touch at all.
  def untouched_membership_ids
    %w[mbr_5041 mbr_5042 mbr_3007 mbr_2001 mbr_2002 mbr_2003 mbr_2004 mbr_2005 mbr_2006]
  end

  def expected_roster_after
    untouched = untouched_membership_ids
    unchanged = fixture_roster['members'].select do |member|
      untouched.include?(member['membership_id'])
    end

    normalize(unchanged) + expected_changed_entries
  end

  def expected_changed_entries # rubocop:disable Metrics/MethodLength
    [
      # 1002 reported Terminated by payroll; kept for history.
      roster_entry(external_id: '1002', first_name: 'David', last_name: 'Okafor',
                   corporate_email: 'david.okafor@sunsethotels.com', status: 'terminated',
                   personal_email: 'd.okafor@gmail.com', locations: %w[DT]),
      # 1003 refreshed from the file: corporate email moved off oldmail.com.
      roster_entry(external_id: '1003', first_name: 'Robert', last_name: 'Chen',
                   corporate_email: 'robert.chen@sunsethotels.com', status: 'active',
                   personal_email: 'rchen@gmail.com', locations: %w[DT], role: 'admin'),
      # 1006 dropped off the file entirely.
      roster_entry(external_id: '1006', first_name: 'Nina', last_name: 'Patel',
                   corporate_email: 'nina.patel@sunsethotels.com', status: 'terminated',
                   personal_email: 'nina.p@gmail.com', locations: %w[DT]),
      # New hires: no login account yet, so each is invited.
      roster_entry(external_id: '1001', first_name: 'Maria', last_name: 'Gomez',
                   corporate_email: 'maria.gomez@sunsethotels.com', status: 'active',
                   invite_status: 'pending', locations: %w[DT UP]),
      roster_entry(external_id: '1004', first_name: 'Aisha', last_name: 'Bello',
                   corporate_email: 'aisha.bello@sunsethotels.com', status: 'active',
                   invite_status: 'pending', locations: %w[UP]),
      # 1007 has no location code in the file, so no assignment is created.
      roster_entry(external_id: '1007', first_name: 'Priya', last_name: 'Nair',
                   corporate_email: 'priya.nair@sunsethotels.com', status: 'active',
                   invite_status: 'pending', locations: [])
    ]
  end

  def roster_entry(external_id:, first_name:, last_name:, corporate_email:, status:, # rubocop:disable Metrics/ParameterLists
                   locations:, personal_email: nil, invite_status: 'accepted', role: 'member')
    {
      'external_id' => external_id,
      'user' => personal_email && { 'personal_email' => personal_email },
      'corporate_email' => corporate_email,
      'first_name' => first_name,
      'last_name' => last_name,
      'status' => status,
      'invite_status' => invite_status,
      'assignments' => locations.map { |code| { 'location_code' => code, 'role' => role } }
    }
  end
end

# rubocop:enable RSpec/ExampleLength
