# frozen_string_literal: true

require "jwt"

module Authenticable
  extend ActiveSupport::Concern

  class << self
    def encode_jwt(payload, exp = 1.hour.from_now)
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
    def encode_jwt(payload, exp = 1.hour.from_now)
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
    user = resolve_user_from_token || attempt_cookie_refresh
    if user
      Current.user = user
    else
      render_unauthorized
    end
  end

  def current_user
    return Current.user if Current.user.present?

    user = resolve_user_from_token || attempt_cookie_refresh
    Current.user = user if user.present?
    Current.user
  end

  def encode_jwt(payload, exp = 1.hour.from_now)
    Authenticable.encode_jwt(payload, exp)
  end

  def decode_jwt(token)
    Authenticable.decode_jwt(token)
  end

  private

  def cookie_store
    if respond_to?(:cookies, true)
      cookies
    elsif respond_to?(:request) && request.respond_to?(:cookie_jar)
      request.cookie_jar
    end
  end

  def resolve_user_from_token
    token = extract_jwt_token
    return nil if token.blank?

    payload = decode_jwt(token)
    return nil if payload.blank?

    if payload[:user_token_id].present? && defined?(UserToken) && UserToken.respond_to?(:find_by)
      user_token = UserToken.find_by(id: payload[:user_token_id])
      if user_token.nil? || user_token.revoked?
        jar = cookie_store
        if jar.present?
          jar.delete(:jwt_token, secure: Rails.env.production?, same_site: :lax)
          jar.delete(:refresh_token, secure: Rails.env.production?, same_site: :lax)
        end
        return nil
      end
    end

    find_user_from_payload(payload)
  end

  def attempt_cookie_refresh
    return nil if authorization_header_present?

    jar = cookie_store
    return nil if jar.blank?

    refresh_token = jar[:refresh_token] || jar["refresh_token"]
    if refresh_token.blank? && request.respond_to?(:cookies)
      refresh_token = request.cookies["refresh_token"] || request.cookies[:refresh_token]
    end
    return nil if refresh_token.blank?

    if defined?(Auth::RefreshTokenService)
      result = Auth::RefreshTokenService.call(
        refresh_token: refresh_token,
        device_info: request.respond_to?(:user_agent) ? request.user_agent : nil
      )

      if result.success?
        data = result.value!
        jar[:jwt_token] = {
          value: data[:token],
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 1.hour.from_now
        }
        jar[:refresh_token] = {
          value: data[:refresh_token],
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax,
          expires: 30.days.from_now
        }
        return data[:user]
      end
    end

    jar.delete(:jwt_token, secure: Rails.env.production?, same_site: :lax)
    jar.delete(:refresh_token, secure: Rails.env.production?, same_site: :lax)
    nil
  end

  def authorization_header_present?
    return false unless respond_to?(:request) && request.respond_to?(:headers)

    request.headers["Authorization"].present? || request.headers["HTTP_AUTHORIZATION"].present?
  end

  def extract_jwt_token
    auth_header = request.headers["Authorization"].presence || request.headers["HTTP_AUTHORIZATION"].presence
    if auth_header.present?
      match = auth_header.to_s.match(/\ABearer\s+(.+)\z/i)
      return match[1].strip if match
    end

    jar = cookie_store
    if jar.present? && (jar[:jwt_token].present? || jar["jwt_token"].present?)
      jar[:jwt_token] || jar["jwt_token"]
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
