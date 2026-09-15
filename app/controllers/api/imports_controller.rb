# frozen_string_literal: true

module Api
  class ImportsController < ActionController::API
    class InvalidUploadError < StandardError; end
    class MissingOrganizationError < StandardError; end

    rescue_from CSV::MalformedCSVError, with: :render_malformed_csv
    rescue_from CSV::InvalidEncodingError,
                Encoding::InvalidByteSequenceError,
                Encoding::UndefinedConversionError,
                with: :render_invalid_encoding
    rescue_from InvalidUploadError, with: :render_invalid_upload
    rescue_from Import::Parsers::PayrollCsvParser::ParseError, with: :render_invalid_upload
    rescue_from MissingOrganizationError, with: :render_missing_organization
    rescue_from JSON::ParserError, with: :render_invalid_resolutions_json

    def preview
      render json: ImportPlanSerializer.new(plan_for(uploaded_file), current_organization)
    end

    def apply
      plan = plan_for(uploaded_file)
      resolved_plan = Import::ConflictResolver.new(current_organization).resolve(plan, resolutions)
      Import::Applier.new.apply(resolved_plan.approve!)

      render json: ImportPlanSerializer.new(resolved_plan, current_organization), status: :ok
    end

    private

    def uploaded_file
      file = params[:file]
      unless file.respond_to?(:tempfile) && file.respond_to?(:original_filename)
        raise InvalidUploadError, 'file must be an uploaded CSV'
      end

      raise InvalidUploadError, 'file must be a CSV' unless File.extname(file.original_filename).casecmp?('.csv')

      file
    end

    def plan_for(file)
      rows = Import::Parsers::PayrollCsvParser.new.parse(file.tempfile)
      Import::Planner.new(current_organization).plan(rows)
    end

    def resolutions
      raw = params[:resolutions]
      return {} if raw.blank?
      return JSON.parse(raw) if raw.is_a?(String)
      return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)

      raw
    end

    # This exercise has one organization. Authentication supplies this boundary
    # in production instead of selecting the first organization.
    def current_organization
      @current_organization ||= Organization.first || raise(MissingOrganizationError)
    end

    def render_malformed_csv
      render json: { error: 'file contains malformed CSV' }, status: :unprocessable_content
    end

    def render_invalid_encoding
      render json: { error: 'file must contain valid UTF-8 text' }, status: :unprocessable_content
    end

    def render_invalid_upload(error)
      render json: { error: error.message }, status: :unprocessable_content
    end

    def render_missing_organization
      render json: { error: 'no organization is configured; run bin/rails db:seed' },
             status: :unprocessable_content
    end

    def render_invalid_resolutions_json
      render json: { error: 'resolutions must be valid JSON' }, status: :unprocessable_content
    end
  end
end
