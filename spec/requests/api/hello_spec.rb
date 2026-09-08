# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Hello', type: :request do
  describe 'GET /api/hello' do
    before { get '/api/hello' }

    it 'returns ok status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns hello world json' do
      expect(response.parsed_body).to eq({ 'hello' => 'World' })
    end
  end
end
