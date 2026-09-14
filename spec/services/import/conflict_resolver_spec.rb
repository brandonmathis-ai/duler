# frozen_string_literal: true

# rubocop:disable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations

require 'rails_helper'

RSpec.describe Import::ConflictResolver do
  describe '#resolve' do
    it 'updates only the selected candidate' do
      organization = create(:organization)
      external_id_candidate = create(:member, organization:, external_id: '1005',
                                              corporate_email: 'srivera@sunsethotels.com',
                                              first_name: 'Sam', last_name: 'Rivera')
      email_candidate = create(:member, organization:, external_id: nil,
                                        corporate_email: 'sam.rivera@sunsethotels.com',
                                        first_name: 'Sam', last_name: 'Rivera')
      plan = plan_for(organization)

      resolved = Import::ConflictResolver.new(organization).resolve(
        plan, { 'external_id:1005' => email_candidate.id }
      )

      entry = resolved.records.find { |record| record.match_key == 'external_id:1005' }
      expect(entry).to have_attributes(
        category: :update,
        matched_member_id: email_candidate.id,
        candidate_member_ids: contain_exactly(external_id_candidate.id, email_candidate.id)
      )
      expect(external_id_candidate.reload.external_id).to eq('1005')
      expect(email_candidate.reload.external_id).to be_nil
    end

    it 'rejects missing selections' do
      organization = create(:organization)
      create(:member, organization:, external_id: '1005', corporate_email: 'srivera@sunsethotels.com')
      create(:member, organization:, external_id: nil, corporate_email: 'sam.rivera@sunsethotels.com')

      expect { Import::ConflictResolver.new(organization).resolve(plan_for(organization), {}) }
        .to raise_error(Import::ConflictResolver::InvalidResolutionError)
    end

    def plan_for(organization)
      rows = Import::Parsers::PayrollCsvParser.new.parse(
        StringIO.new(
          "external_id,location_code,position_status,first_name,last_name,work_email\n" \
          '1005,DT,Active,Sam,Rivera,sam.rivera@sunsethotels.com'
        )
      )
      Import::Planner.new(organization).plan(rows)
    end
  end

  # rubocop:enable RSpec/DescribedClass, RSpec/ExampleLength, RSpec/MultipleExpectations
end
