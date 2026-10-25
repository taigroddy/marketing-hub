# frozen_string_literal: true

module Auth
  class LogoutContract < ApplicationContract
    params do
      optional(:refresh_token).maybe(:string)
      optional(:user_token_id).maybe(:integer)
    end

    rule(:refresh_token, :user_token_id) do
      if values[:refresh_token].blank? && values[:user_token_id].blank?
        key(:refresh_token).failure(:required_without_user_token)
      end
    end
  end
end
