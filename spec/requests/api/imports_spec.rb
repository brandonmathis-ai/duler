# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations

require 'rails_helper'

RSpec.describe 'Api::Imports', type: :request do
  describe 'POST /api/imports/preview' do
    it 'explains when the organization is missing' do
      post '/api/imports/preview', params: { file: conflict_file }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('no organization is configured; run bin/rails db:seed')
    end

    it 'returns candidates without writing' do
      organization = create(:organization)
      external_candidate = create(:member, organization:, external_id: '1005',
                                           corporate_email: 'srivera@sunsethotels.com')
      email_candidate = create(:member, organization:, external_id: nil,
                                        corporate_email: 'sam.rivera@sunsethotels.com')

      expect do
        post '/api/imports/preview', params: { file: conflict_file }
      end.not_to change(Member, :count)

      conflict = response.parsed_body['records'].sole
      expect(response).to have_http_status(:ok)
      expect(conflict['category']).to eq('conflict')
      expect(conflict['candidates'].pluck('member_id')).to contain_exactly(external_candidate.id, email_candidate.id)
    end

    it 'rejects a missing file' do
      create(:organization)

      post '/api/imports/preview'

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq('file must be an uploaded CSV')
    end

    it 'rejects invalid row data' do
      create(:organization)
      tempfile = Tempfile.new(['invalid', '.csv'])
      tempfile.write(
        "external_id,location_code,position_status,first_name,last_name,work_email\n" \
        "1001,DT,InvalidStatus,Jane,Doe,jane@example.com\n"
      )
      tempfile.rewind
      file = Rack::Test::UploadedFile.new(tempfile.path, 'text/csv', original_filename: 'invalid.csv')

      post '/api/imports/preview', params: { file: file }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to include('invalid position_status')
    ensure
      tempfile.close!
    end
  end

  describe 'POST /api/imports/apply' do
    it 'updates the external id candidate only' do
      organization = create(:organization)
      selected = create(:member, organization:, external_id: '1005',
                                 corporate_email: 'srivera@sunsethotels.com')
      untouched = create(:member, organization:, external_id: nil,
                                  corporate_email: 'sam.rivera@sunsethotels.com')

      post '/api/imports/apply', params: {
        file: conflict_file,
        resolutions: { 'external_id:1005' => selected.id }
      }

      expect(response).to have_http_status(:ok)
      expect(selected.reload.corporate_email).to eq('sam.rivera@sunsethotels.com')
      expect(untouched.reload.external_id).to be_nil
    end

    it 'updates the email candidate only' do
      organization = create(:organization)
      untouched = create(:member, organization:, external_id: '1005',
                                  corporate_email: 'srivera@sunsethotels.com')
      selected = create(:member, organization:, external_id: nil,
                                 corporate_email: 'sam.rivera@sunsethotels.com')

      post '/api/imports/apply', params: {
        file: conflict_file,
        resolutions: { 'external_id:1005' => selected.id }
      }

      expect(response).to have_http_status(:ok)
      expect(selected.reload.external_id).to eq('1005')
      expect(untouched.reload).to have_attributes(
        external_id: nil,
        corporate_email: 'srivera@sunsethotels.com',
        status: 'inactive'
      )
    end
  end

  def conflict_file
    fixture_file_upload('conflict.csv', 'text/csv')
  end
end

# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
