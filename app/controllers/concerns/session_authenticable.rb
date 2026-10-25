# frozen_string_literal: true

module SessionAuthenticable
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_user_token if respond_to?(:helper_method)
  end

  def authenticate_user!
    user = resolve_user_from_cookie || attempt_cookie_refresh
    if user
      Current.user = user
    else
      render_session_unauthorized
    end
  end

  def current_user
    return Current.user if Current.user.present?

    user = resolve_user_from_cookie || attempt_cookie_refresh
    Current.user = user if user.present?
    Current.user
  end

  def current_user_token
    return nil unless current_user

    token = cookie_jar[:jwt_token] || cookie_jar["jwt_token"]
    if token.blank? && request.respond_to?(:cookies)
      token = request.cookies["jwt_token"] || request.cookies[:jwt_token]
    end
    token
  end

  private

  def cookie_jar
    if respond_to?(:cookies, true)
      cookies
    elsif respond_to?(:request) && request.respond_to?(:cookie_jar)
      request.cookie_jar
    else
      {}
    end
  end

  def resolve_user_from_cookie
    token = cookie_jar[:jwt_token] || cookie_jar["jwt_token"]
    if token.blank? && request.respond_to?(:cookies)
      token = request.cookies["jwt_token"] || request.cookies[:jwt_token]
    end
    return nil if token.blank?

    payload = Authenticable.decode_jwt(token)
    return nil if payload.blank?

    if payload[:user_token_id].present? && defined?(UserToken) && UserToken.respond_to?(:find_by)
      user_token = UserToken.find_by(id: payload[:user_token_id])
      if user_token.nil? || user_token.revoked?
        clear_session_cookies
        return nil
      end
    end

    find_user_from_payload(payload)
  end

  def attempt_cookie_refresh
    jar = cookie_jar
    refresh_token = jar[:refresh_token] || jar["refresh_token"]
    if refresh_token.blank? && request.respond_to?(:cookies)
      refresh_token = request.cookies["refresh_token"] || request.cookies[:refresh_token]
    end
    return nil if refresh_token.blank?

    if defined?(Auth::RefreshTokenService)
      device_info = request.respond_to?(:user_agent) ? request.user_agent : nil
      result = Auth::RefreshTokenService.call(refresh_token: refresh_token, device_info: device_info)

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

    clear_session_cookies
    nil
  end

  def clear_session_cookies
    jar = cookie_jar
    return unless jar.respond_to?(:delete)

    is_secure = (respond_to?(:request) && request.respond_to?(:ssl?) && request.ssl?) || Rails.env.production?

    jar.delete(:jwt_token, path: "/", same_site: :lax, secure: is_secure)
    jar.delete(:refresh_token, path: "/", same_site: :lax, secure: is_secure)
    jar.delete(:jwt_token, path: "/")
    jar.delete(:refresh_token, path: "/")
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

  def render_session_unauthorized(message = nil)
    err = message.presence || I18n.t("errors.unauthorized", default: "Unauthorized")
    if request.respond_to?(:format) && request.format.json?
      render json: { success: false, data: nil, errors: err }, status: :unauthorized
    elsif respond_to?(:login_path)
      redirect_to login_path, alert: I18n.t("auth.sign_in_required", default: "Please sign in to continue.")
    else
      render plain: err, status: :unauthorized
    end
  end
end
