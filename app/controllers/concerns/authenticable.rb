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
end
