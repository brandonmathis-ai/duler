# frozen_string_literal: true

module Api
  class HelloController < ActionController::API
    def show
      render json: { hello: 'World' }
    end
  end
end
