# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ActionController::Flash
    include TokenAuthenticable

    before_action :set_locale

    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

    def full_request_params
      params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
    end

    def render_success(data = nil, status: :ok)
      render json: {
        success: true,
        data: data,
        errors: nil
      }, status: status
    end

    def render_failure(errors, status: :unprocessable_entity)
      render json: {
        success: false,
        data: nil,
        errors: errors
      }, status: status
    end

    private

    def set_locale
      header = request.headers["Accept-Language"].to_s
      header_lang = if header.present?
                      header.split(",").map { |l| l.split(";").first.strip[0..1].downcase }.find do |l|
                        I18n.available_locales.map(&:to_s).include?(l == "vn" ? "vi" : l)
                      end
      end

      lang = params[:locale].to_s.presence || header_lang.presence || I18n.default_locale
      lang = lang.to_s.downcase
      lang = "vi" if lang == "vn"
      I18n.locale = I18n.available_locales.map(&:to_s).include?(lang) ? lang.to_sym : I18n.default_locale
    end

    def handle_record_not_found(_exception)
      render_failure(I18n.t("errors.not_found", default: "Record not found"), status: :not_found)
    end

    def handle_parameter_missing(exception)
      render_failure(exception.message, status: :bad_request)
    end
  end
end
