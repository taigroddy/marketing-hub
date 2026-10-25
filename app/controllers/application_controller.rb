# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include SessionAuthenticable

  before_action :set_locale

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: -> { Rails.env.test? }

  private

  def set_locale
    lang = cookies[:locale].to_s.presence || params[:locale].to_s.presence || I18n.default_locale
    lang = lang.to_s.downcase
    lang = "vi" if lang == "vn"
    I18n.locale = I18n.available_locales.map(&:to_s).include?(lang) ? lang.to_sym : I18n.default_locale
  end
end
