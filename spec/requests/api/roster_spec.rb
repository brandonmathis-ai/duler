# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength

require 'rails_helper'

RSpec.describe 'Api::Roster', type: :request do
  describe 'GET /api/roster' do
    it 'returns ok status' do
      get '/api/roster'

      expect(response).to have_http_status(:ok)
    end

    it 'returns a members collection' do
      create(:member)

      get '/api/roster'

      expect(response.parsed_body['members'].size).to eq(1)
    end

    context 'when a member has an account and assignments' do
      it 'returns the full member shape' do
        user = create(:user, personal_email: 'd.okafor@gmail.com')
        member = create(:member, external_id: '1002', user: user, first_name: 'David',
                                 last_name: 'Okafor', corporate_email: 'david.okafor@sunsethotels.com',
                                 status: 'active', invite_status: 'accepted')
        create(:assignment, member: member, location_code: 'DT', role: 'member')

        get '/api/roster'

        expect(response.parsed_body['members'].sole).to eq(
          'membership_id' => "mbr_#{member.id}",
          'external_id' => '1002',
          'user' => { 'id' => "usr_#{user.id}", 'personal_email' => 'd.okafor@gmail.com' },
          'corporate_email' => 'david.okafor@sunsethotels.com',
          'first_name' => 'David',
          'last_name' => 'Okafor',
          'status' => 'active',
          'invite_status' => 'accepted',
          'assignments' => [{ 'location_code' => 'DT', 'role' => 'member' }]
        )
      end
    end

    context 'when a member has no account' do
      it 'returns a null user' do
        create(:member, user: nil, invite_status: 'pending')

        get '/api/roster'

        expect(response.parsed_body['members'].sole['user']).to be_nil
      end
    end

    context 'when a member has no personal email' do
      it 'returns an empty personal email' do
        create(:member, user: create(:user, personal_email: nil))

        get '/api/roster'

        expect(response.parsed_body['members'].sole.dig('user', 'personal_email')).to eq('')
      end
    end

    context 'when a member has no assignments' do
      it 'returns an empty assignments list' do
        create(:member)

        get '/api/roster'

        expect(response.parsed_body['members'].sole['assignments']).to eq([])
      end
    end

    context 'when a member is terminated' do
      it 'still returns the member' do
        create(:member, status: 'terminated', first_name: 'David', last_name: 'Okafor')

        get '/api/roster'

        expect(response.parsed_body['members'].sole).to include('status' => 'terminated')
      end
    end

    context 'when several members exist' do
      it 'returns them ordered by id' do
        first = create(:member, first_name: 'Alice')
        second = create(:member, first_name: 'Bob')

        get '/api/roster'

        expect(response.parsed_body['members'].pluck('membership_id'))
          .to eq(["mbr_#{first.id}", "mbr_#{second.id}"])
      end
    end
  end
end

# rubocop:enable RSpec/ExampleLength
