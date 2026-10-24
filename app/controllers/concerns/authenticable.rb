# frozen_string_literal: true

require "jwt"

module Authenticable
  extend ActiveSupport::Concern

  class << self
    def encode_jwt(payload, exp = 24.hours.from_now)
      payload_to_encode = payload.dup.stringify_keys
      payload_to_encode["exp"] = exp.to_i unless payload_to_encode.key?("exp")
      JWT.encode(payload_to_encode, jwt_secret_key, "HS256")
    end

    def decode_jwt(token)
      return nil if token.blank?

      decoded = JWT.decode(token, jwt_secret_key, true, { algorithm: "HS256" })
      ActiveSupport::HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::DecodeError, ArgumentError
      nil
    end

    def jwt_secret_key
      ENV["JWT_SECRET"].presence || Rails.application.secret_key_base
    end
  end

  class_methods do
    def encode_jwt(payload, exp = 24.hours.from_now)
      Authenticable.encode_jwt(payload, exp)
    end

    def decode_jwt(token)
      Authenticable.decode_jwt(token)
    end
  end

  included do
    helper_method :current_user if respond_to?(:helper_method)
  end

  def authenticate_user!
    token = extract_jwt_token
    payload = decode_jwt(token)

    if payload && (user = find_user_from_payload(payload))
      Current.user = user
    else
      render_unauthorized
    end
  end

  def current_user
    Current.user
  end

  def encode_jwt(payload, exp = 24.hours.from_now)
    Authenticable.encode_jwt(payload, exp)
  end

  def decode_jwt(token)
    Authenticable.decode_jwt(token)
  end

  private

  def extract_jwt_token
    auth_header = request.headers["Authorization"].presence || request.headers["HTTP_AUTHORIZATION"].presence
    if auth_header.present?
      match = auth_header.to_s.match(/\ABearer\s+(.+)\z/i)
      return match[1].strip if match
    end

    if respond_to?(:cookies) && (cookies[:jwt_token].present? || cookies["jwt_token"].present?)
      cookies[:jwt_token] || cookies["jwt_token"]
    elsif request.respond_to?(:cookies)
      request.cookies["jwt_token"] || request.cookies[:jwt_token]
    end
  end

  def find_user_from_payload(payload)
    user_id = payload[:user_id] || payload[:sub] || payload[:id]
    return nil if user_id.blank?

    if defined?(User) && User.respond_to?(:find_by)
      User.find_by(id: user_id)
    else
      payload.merge(id: user_id)
    end
  end

  def render_unauthorized(message = "Unauthorized")
    if request.format.json? || request.path.to_s.start_with?("/api/", "/v1/")
      render json: { error: message }, status: :unauthorized
    elsif respond_to?(:respond_to)
      respond_to do |format|
        format.json { render json: { error: message }, status: :unauthorized }
        format.html do
          if respond_to?(:login_path)
            redirect_to login_path, alert: "Please sign in to continue."
          else
            render plain: message, status: :unauthorized
          end
        end
        format.all { render plain: message, status: :unauthorized }
      end
    else
      render json: { error: message }, status: :unauthorized
    end
  end
end
