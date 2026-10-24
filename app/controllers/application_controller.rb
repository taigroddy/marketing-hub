# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authenticable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: -> { Rails.env.test? }

  def full_request_params
    params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params
  end
end
