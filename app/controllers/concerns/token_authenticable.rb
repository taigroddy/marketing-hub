# frozen_string_literal: true

module TokenAuthenticable
  extend ActiveSupport::Concern

  def authenticate_user!
    user = resolve_user_from_token
    if user
      Current.user = user
    else
      render_token_unauthorized
    end
  end

  def current_user
    return Current.user if Current.user.present?

    user = resolve_user_from_token
    Current.user = user if user.present?
    Current.user
  end

  def current_user_token_payload
    @current_user_token_payload ||= begin
      token = extract_bearer_token
      token.present? ? Authenticable.decode_jwt(token) : nil
    end
  end

  def current_user_token_id
    current_user_token_payload&.dig(:user_token_id)
  end

  private

  def resolve_user_from_token
    payload = current_user_token_payload
    return nil if payload.blank?

    if payload[:user_token_id].present? && defined?(UserToken) && UserToken.respond_to?(:find_by)
      user_token = UserToken.find_by(id: payload[:user_token_id])
      return nil if user_token.nil? || user_token.revoked?
    end

    find_user_from_payload(payload)
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"].presence || request.headers["HTTP_AUTHORIZATION"].presence
    if auth_header.present?
      match = auth_header.to_s.match(/\ABearer\s+(.+)\z/i)
      return match[1].strip if match
    end

    params[:token].presence || params[:state].presence
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

  def render_token_unauthorized(message = nil)
    err = message.presence || I18n.t("errors.unauthorized", default: "Unauthorized")
    render json: { success: false, data: nil, errors: err }, status: :unauthorized
  end
end
