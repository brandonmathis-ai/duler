# frozen_string_literal: true

module Api
  # Serves the current roster: every member the org has, including terminated
  # ones, since departures are kept for history rather than deleted.
  class RosterController < ActionController::API
    def index
      members = Member.includes(:user, :assignments).order(:id)

      render json: RosterSerializer.new(members)
    end
  end
end
