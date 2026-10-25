# frozen_string_literal: true

module Auth
  class ConfirmEmailContract < ApplicationContract
    params do
      required(:token).filled(:string)
    end
  end
end
